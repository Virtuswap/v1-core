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
        //1. Deduct fee amount from out token and not from in token
        virtualPoolModel memory tPool = this.CalculateTotalPool(iks, jks);

        address tokenIn;
        address tokenOut;

        //find trade direction
        emit DebugS("tPoolToken0", ERC20(tPool.token0).name());
        emit DebugS("tPoolToken1", ERC20(tPool.token1).name());

        (tokenIn, tokenOut) = (tPool.token0, tPool.token1);

        //%substract amount and add fees to amount_in
        //T(buy_currency,sell_currency,buy_currency)=lag_T(buy_currency,sell_currency,buy_currency)-Buy*(1-fee_T(buy_currency,sell_currency)); ****

        uint256 amountOut = vSwapMath.quote(tPool, amount, false);

        emit Debug("amountOut", amountOut);

        //calculate amount to take from tokenOut from real pool
        uint256 vPairTokenOutAmount = 0;
        uint256 vPairTokenInBalance = 0;
        uint256 vPairTokenInAmount = 0;

        if (tPool.vPairAddress > address(0)) {
            vPairTokenInBalance = IERC20(tokenIn).balanceOf(tPool.vPairAddress);

            vPairTokenOutAmount = IERC20(tokenOut).balanceOf(
                tPool.vPairAddress
            );

            uint256 realOutWeight = (
                ((vPairTokenOutAmount * 10000) / tPool.tokenBBalance)
            );

            vPairTokenOutAmount = amountOut * realOutWeight;
            vPairTokenOutAmount = vPairTokenOutAmount / 10000;

            emit Debug("realOutWeight", realOutWeight);

            emit Debug(
                "Real pool token out Balance delta",
                vPairTokenOutAmount
            );

            uint256 realInWeight = ((vPairTokenInBalance * 10000) /
                tPool.tokenABalance);

            emit Debug("realOutWeight", realOutWeight);
            emit Debug("realInWeight", realInWeight);

            vPairTokenInAmount = amount * realInWeight;

            vPairTokenInAmount = vPairTokenInAmount / 10000;

            emit Debug("Real pool token in Balance delta", vPairTokenInAmount);

            // //collect from user to real pool
            require(
                ERC20(tokenIn).transferFrom(
                    msg.sender,
                    tPool.vPairAddress,
                    vPairTokenInAmount
                ),
                "Failed to collect from user"
            );

            // //from real pool to to user
            require(
                IvPair(tPool.vPairAddress).transferToken(
                    tokenOut,
                    msg.sender,
                    vPairTokenOutAmount
                ),
                "Hello"
            );
        }

        //take more tokenOut from Virtual pool
        virtualPoolModel memory vPool = this.CalculateVirtualPool(iks, jks);

        uint256 virtualOutWeight = (
            ((vPool.tokenBBalance * 10000) / tPool.tokenBBalance)
        );

        uint256 vPoolTokenOutBalance = amountOut * virtualOutWeight;
        vPoolTokenOutBalance = vPoolTokenOutBalance / 10000;

        // uint256 virtualInWeight = ((vPool.tokenABalance * 10000) /
        //     tPool.tokenABalance);

        uint256 vPoolTokenInAmount = amount *
            ((vPool.tokenABalance * 10000) / tPool.tokenABalance);

        vPoolTokenInAmount = vPoolTokenInAmount / 10000;

        require(
            ERC20(tokenIn).transferFrom(msg.sender, jks[0], vPoolTokenInAmount),
            "Failed to collect from user"
        );

        require(
            IvPair(jks[0]).transferToken(
                tokenOut,
                msg.sender,
                vPoolTokenOutBalance
            ),
            "Hello 1"
        );
    }

    function changeFactory(address factory) public onlyOwner {
        _factory = factory;
    }
}
