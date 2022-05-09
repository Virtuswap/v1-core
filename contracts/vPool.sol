// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;


import "./types.sol";
import "./ERC20/IERC20.sol";
import "./libraries/SafeERC20.sol";
import "./libraries/vSwapMath.sol";
import "./interfaces/IvPair.sol";
import "./interfaces/IvPairFactory.sol";
import "./interfaces/IvPool.sol";

contract vPool is IvPool {
    address public override factory;
    address public immutable override owner;
    address public immutable override WETH;

    uint256 constant EPSILON = 1 wei;

    modifier onlyOwner() {
        require(msg.sender == owner);
        _;
    }

    modifier ensure(uint256 deadline) {
        require(deadline >= block.timestamp, "VSWAP: EXPIRED");
        _;
    }

    constructor(address _factory, address _WETH) {
        owner = msg.sender;
        factory = _factory;
        WETH = _WETH;
    }

    function _calculateVirtualPool(address[] memory iks, address[] memory jks)
        private
        view
        returns (VirtualPoolModel memory _vPool)
    {
        //no virtual pool;
        if (iks.length == 0) return _vPool;

        require(iks.length == jks.length, "VSWAP: INVALID_VPOOL_REQUEST");

        _vPool.fee = 0.003 ether;

        for (uint256 i = 0; i < iks.length; i++) {
            uint256 belowReserveIK = IvPair(iks[i]).getBelowReserve();
            uint256 belowReserveJK = IvPair(jks[i]).getBelowReserve();

            (address ikToken0, address ikToken1) = IvPair(iks[i]).tokens();
            (address jkToken0, address jkToken1) = IvPair(jks[i]).tokens();

            (ikToken0, ikToken1, jkToken0, jkToken1) = vSwapMath
                .findCommonToken(ikToken0, ikToken1, jkToken0, jkToken1);

            require(ikToken1 == jkToken1, "VSWAP: INVALID_VPOOL_REQUEST");

            //set tokens address in first loop
            if (i == 0) {
                _vPool.token0 = ikToken0;
                _vPool.token1 = jkToken0;
            }

            uint256 ikPairToken0Balance = IERC20(ikToken0).balanceOf(iks[i]);
            uint256 ikPairToken1Balance = IERC20(ikToken1).balanceOf(iks[i]);
            uint256 jkPairToken0Balance = IERC20(jkToken0).balanceOf(jks[i]);
            uint256 jkPairToken1Balance = IERC20(jkToken1).balanceOf(jks[i]);

            _vPool.sumTokenA += ikPairToken0Balance;
            _vPool.sumTokenB += jkPairToken0Balance;

            //  V(i,j,i)=V(i,j,i)+ind_below_reserve_threshold(i,k)*R(i,k,i)*min(R(i,k,k),R(j,k,k))/max(R(i,k,k),epsilon);
            _vPool.tokenABalance =
                _vPool.tokenABalance +
                (belowReserveIK *
                    ikPairToken0Balance *
                    Math.min(ikPairToken1Balance, jkPairToken1Balance)) /
                Math.max(ikPairToken1Balance, EPSILON);

            // // V(i,j,j)=V(i,j,j)+ind_below_reserve_threshold(i,k)*R(j,k,j)*min(R(i,k,k),R(j,k,k))/max(R(j,k,k),epsilon);
            _vPool.tokenBBalance =
                _vPool.tokenBBalance +
                (belowReserveJK *
                    jkPairToken0Balance *
                    Math.min(ikPairToken1Balance, jkPairToken1Balance)) /
                Math.max(jkPairToken1Balance, EPSILON);
        }
    }

    function _calculateTotalPool(VirtualPoolModel memory _vPool)
        private
        view
        returns (VirtualPoolModel memory tPool)
    {
        tPool = _vPool;

        address vPairAddress = IvPairFactory(factory).getPair(
            tPool.token0,
            tPool.token1
        );
        tPool.vPairAddress = vPairAddress;

        uint256 vPairToken0Balance = 0;
        uint256 vPairToken1Balance = 0;
        uint256 vPairFee = 0;

        if (tPool.vPairAddress > address(0)) {
            vPairToken0Balance = IERC20(tPool.token0).balanceOf(vPairAddress);
            vPairToken1Balance = IERC20(tPool.token1).balanceOf(vPairAddress);
            vPairFee = IvPair(vPairAddress).fee();
        }

        tPool.tokenABalance = vPairToken0Balance + tPool.tokenABalance;
        tPool.tokenBBalance = vPairToken1Balance + tPool.tokenBBalance;

        if (tPool.tokenABalance > 0) {
            tPool.fee = vSwapMath.totalPoolFeeAvg(
                vPairFee,
                vPairToken0Balance,
                tPool.fee,
                tPool.tokenABalance
            );
        }
    }

    function _calculateTotalPool(address[] memory iks, address[] memory jks)
        private
        view
        returns (VirtualPoolModel memory)
    {
        return _calculateTotalPool(_calculateVirtualPool(iks, jks));
    }

    function Quote(
        address[] memory iks,
        address[] memory jks,
        uint256 amount
    ) external view returns (uint256) {
        VirtualPoolModel memory tPool = _calculateTotalPool(iks, jks);
        return vSwapMath.quote(tPool, amount, true);
    }

    function Swap(
        address[] memory iks,
        address[] memory jks,
        uint256 amount
    ) external {
        VirtualPoolModel memory _vPool = _calculateVirtualPool(iks, jks);
        VirtualPoolModel memory _tPool = _calculateTotalPool(_vPool);

        uint256 amountOut = vSwapMath.quote(_tPool, amount, true);

        if (_tPool.vPairAddress > address(0)) {
            uint256 vPairTokenInAmount = vSwapMath.calculateWeightedAmount(
                amount,
                IERC20(_tPool.token0).balanceOf(_tPool.vPairAddress),
                _tPool.tokenABalance
            );

            uint256 vPairTokenOutAmount = vSwapMath.calculateWeightedAmount(
                amountOut,
                IERC20(_tPool.token1).balanceOf(_tPool.vPairAddress),
                _tPool.tokenBBalance
            );

            SafeERC20.safeTransferFrom(
                IERC20(_tPool.token0),
                msg.sender,
                _tPool.vPairAddress,
                vPairTokenInAmount
            );

            IvPair(_tPool.vPairAddress).transferToken(
                _tPool.token1,
                msg.sender,
                vPairTokenOutAmount
            );
        }

        uint256 vPoolTokenOutAmount = vSwapMath.calculateWeightedAmount(
            amountOut,
            _vPool.tokenBBalance,
            _tPool.tokenBBalance
        );

        uint256 vPoolTokenInAmount = vSwapMath.calculateWeightedAmount(
            amount,
            _vPool.tokenABalance,
            _tPool.tokenABalance
        );

        for (uint256 i = 0; i < iks.length; i++) {
            //enforce whitelist
            require(
                IvPair(iks[i]).isReserveAllowed(_tPool.token0) == true,
                "VSWAP:RESERVE_NOT_WHITELISTED"
            );

            uint256 ikTokenInAmount = vSwapMath.calculateWeightedAmount(
                vPoolTokenInAmount,
                ERC20(_tPool.token0).balanceOf(iks[i]),
                _vPool.sumTokenA
            );

            uint256 jkTokenOutAmount = vSwapMath.calculateWeightedAmount(
                vPoolTokenOutAmount,
                ERC20(_tPool.token1).balanceOf(jks[i]),
                _vPool.sumTokenB
            );

            SafeERC20.safeTransferFrom(
                IERC20(_tPool.token0),
                msg.sender,
                jks[i],
                ikTokenInAmount
            );

            IvPair(jks[i]).transferToken(
                _tPool.token1,
                msg.sender,
                jkTokenOutAmount
            );
        }
    }

    function ChangeFactory(address _factory) external onlyOwner {
        factory = _factory;
    }
}
