// SPDX-License-Identifier: MIT
pragma solidity >=0.4.22 <0.9.0;

import "./types.sol";
import "./ERC20/IERC20.sol";
import "./ERC20/ERC20.sol";
import "./libraries/vSwapMath.sol";
import "./interfaces/IvPair.sol";
import "./interfaces/IvPairFactory.sol";

contract VirtualPool {
    address owner;
    address _factory;

    uint256 constant EPSILON = 1 wei;

    event Debug(string message, uint256 value);
    event DebugS(string message, string value);
    event DebugA(string message, address add, uint256 value);

    modifier onlyOwner() {
        require(msg.sender == owner);
        _;
    }

    modifier ensure(uint256 deadline) {
        require(deadline >= block.timestamp, "VSWAP: EXPIRED");
        _;
    }

    constructor(address factory) {
        owner = msg.sender;
        _factory = factory;
    }

    function CalculateVirtualPool(address[] memory iks, address[] memory jks)
        external
        view
        returns (virtualPoolModel memory vPool)
    {
        //no virtual pool;
        if (iks.length == 0) return vPool;

        require(iks.length == jks.length, "VSWAP: INVALID_VPOOL_REQUEST");

        vPool.fee = 0.003 ether;

        for (uint256 i = 0; i < iks.length; i++) {
            uint256 belowReserveIK = IvPair(iks[i]).getBelowReserve();
            uint256 belowReserveJK = IvPair(jks[i]).getBelowReserve();

            address ikToken0 = IvPair(iks[i]).token0();
            address ikToken1 = IvPair(iks[i]).token1();
            address jkToken0 = IvPair(jks[i]).token0();
            address jkToken1 = IvPair(jks[i]).token1();

            (ikToken0, ikToken1, jkToken0, jkToken1) = vSwapMath
                .findCommonToken(ikToken0, ikToken1, jkToken0, jkToken1);

            require(ikToken1 == jkToken1, "VSWAP: INVALID_VPOOL_REQUEST");

            //set tokens address in first loop
            if (i == 0) {
                vPool.token0 = ikToken0;
                vPool.token1 = jkToken0;
            }

            uint256 ikPairToken0Balance = IERC20(ikToken0).balanceOf(iks[i]);
            uint256 ikPairToken1Balance = IERC20(ikToken1).balanceOf(iks[i]);
            uint256 jkPairToken0Balance = IERC20(jkToken0).balanceOf(jks[i]);
            uint256 jkPairToken1Balance = IERC20(jkToken1).balanceOf(jks[i]);

            vPool.sumTokenA = vPool.sumTokenA + ikPairToken0Balance;
            vPool.sumTokenB = vPool.sumTokenB + jkPairToken0Balance;

            //  V(i,j,i)=V(i,j,i)+ind_below_reserve_threshold(i,k)*R(i,k,i)*min(R(i,k,k),R(j,k,k))/max(R(i,k,k),epsilon);
            vPool.tokenABalance =
                vPool.tokenABalance +
                (belowReserveIK *
                    ikPairToken0Balance *
                    Math.min(ikPairToken1Balance, jkPairToken1Balance)) /
                Math.max(ikPairToken1Balance, EPSILON);

            // // V(i,j,j)=V(i,j,j)+ind_below_reserve_threshold(i,k)*R(j,k,j)*min(R(i,k,k),R(j,k,k))/max(R(j,k,k),epsilon);
            vPool.tokenBBalance =
                vPool.tokenBBalance +
                (belowReserveJK *
                    jkPairToken0Balance *
                    Math.min(ikPairToken1Balance, jkPairToken1Balance)) /
                Math.max(jkPairToken1Balance, EPSILON);
        }

        return vPool;
    }

    function CalculateTotalPool(address[] memory iks, address[] memory jks)
        external
        view
        returns (virtualPoolModel memory tPool)
    {
        tPool = this.CalculateVirtualPool(iks, jks);
        address vPairAddress = IvPairFactory(_factory).getPairAddress(
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

        return tPool;
    }

    function Quote(
        address[] memory iks,
        address[] memory jks,
        uint256 amount
    ) external view returns (uint256) {
        virtualPoolModel memory tPool = this.CalculateTotalPool(iks, jks);
        return vSwapMath.quote(tPool, amount, true);
    }

    function swap(
        address[] memory iks,
        address[] memory jks,
        uint256 amount
    ) public {
        virtualPoolModel memory tPool = this.CalculateTotalPool(iks, jks);
        uint256 amountOut = vSwapMath.quote(tPool, amount, true);

        if (tPool.vPairAddress > address(0)) {
            uint256 vPairTokenOutAmount = vSwapMath.calculateWeightedAmount(
                amountOut,
                IERC20(tPool.token1).balanceOf(tPool.vPairAddress),
                tPool.tokenBBalance
            );

            uint256 vPairTokenInAmount = vSwapMath.calculateWeightedAmount(
                amount,
                IERC20(tPool.token0).balanceOf(tPool.vPairAddress),
                tPool.tokenABalance
            );

            // //collect from user to real pool
            require(
                ERC20(tPool.token0).transferFrom(
                    msg.sender,
                    tPool.vPairAddress,
                    vPairTokenInAmount
                ),
                "VPOOL:COLLECT_ERROR_TOKENIN"
            );

            emit DebugA("tPool.vPairAddress", tPool.vPairAddress, 0);
            emit DebugA("tPool.token1", tPool.token1, 0);
            emit DebugA("msg.sender", msg.sender, 0);
            emit Debug("vPairTokenOutAmount", vPairTokenOutAmount);
            //from real pool to to user
            // require(
            //     IvPair(tPool.vPairAddress).transferToken(
            //         tPool.token1,
            //         msg.sender,
            //         vPairTokenOutAmount
            //     ),
            //     "VPOOL:SENT_ERROR_TOKENOUT"
            // );
        }

        virtualPoolModel memory vPool = this.CalculateVirtualPool(iks, jks);

        uint256 vPoolTokenOutBalance = vSwapMath.calculateWeightedAmount(
            amountOut,
            vPool.tokenBBalance,
            tPool.tokenBBalance
        );

        uint256 vPoolTokenInBalance = vSwapMath.calculateWeightedAmount(
            amount,
            vPool.tokenABalance,
            tPool.tokenABalance
        );

        //take more tokenOut from Virtual pool
        for (uint256 i = 0; i < jks.length; i++) {
            //find jk size relative to virtual pool

            uint256 ikTokenInBalance = vSwapMath.calculateWeightedAmount(
                vPoolTokenInBalance,
                ERC20(tPool.token0).balanceOf(iks[i]),
                vPool.sumTokenA
            );

            uint256 jkTokenOutBalance = vSwapMath.calculateWeightedAmount(
                vPoolTokenOutBalance,
                ERC20(tPool.token1).balanceOf(jks[i]),
                vPool.sumTokenB
            );

            require(
                ERC20(tPool.token0).transferFrom(
                    msg.sender,
                    jks[i],
                    ikTokenInBalance
                ),
                "VPOOL:COLLECT_ERROR_TOKENIN"
            );

            require(
                IvPair(jks[i]).transferToken(
                    tPool.token1,
                    msg.sender,
                    jkTokenOutBalance
                ),
                "VPOOL:SENT_ERROR_TOKENOUT"
            );
        }
    }

    function changeFactory(address factory) public onlyOwner {
        _factory = factory;
    }
}
