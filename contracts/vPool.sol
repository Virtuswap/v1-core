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

            //collect from user to real pool
            require(
                ERC20(tokenIn).transferFrom(
                    msg.sender,
                    tPool.vPairAddress,
                    vPairTokenInAmount
                )
            );

            //from real pool to to user
            require(
                ERC20(tokenOut).transferFrom(
                    tPool.vPairAddress,
                    msg.sender,
                    vPairTokenOutAmount
                )
            );
        }

        //take more tokenOut from Virtual pool
        virtualPoolModel memory vPool = this.CalculateVirtualPool(iks, jks);

        uint256 virtualOutWeight = (
            ((vPool.tokenBBalance * 10000) / tPool.tokenBBalance)
        );

        emit Debug("virtualOutWeight", virtualOutWeight);

        uint256 vPoolTokenOutBalance = amountOut * virtualOutWeight;
        vPoolTokenOutBalance = vPoolTokenOutBalance / 10000;

        emit Debug("virtual pool tokenout Balance delta", vPoolTokenOutBalance);

        uint256 virtualInWeight = ((vPool.tokenABalance * 10000) /
            tPool.tokenABalance);

        uint256 vPoolTokenInAmount = amount * virtualInWeight;

        vPoolTokenInAmount = vPoolTokenInAmount / 10000;

        emit Debug("Virtual pool tokenin Balance delta", vPoolTokenInAmount);

        //calculate reserve getting from pool jk
        


        // emit Debug("vPairTokenInBalance", vPairTokenInBalance);
        // emit Debug("vPairTokenOutAmount", vPairTokenOutAmount);
    }

    // function swap(
    //     uint256[] memory iks,
    //     uint256[] memory jks,
    //     address vPairAddress,
    //     int256 amount
    // ) public {
    //     // buy_currency=2;
    //     // sell_currency=3;
    //     // Buy=30;

    //     virtualPoolModel memory tPool = this.calculateTotalPool(
    //         iks,
    //         jks,
    //         vPairAddress
    //     );

    //     virtualPoolModel[] memory lagR = new virtualPoolModel[](iks.length);

    //     //lag_T(buy_currency,sell_currency,buy_currency)=T(buy_currency,sell_currency,buy_currency);
    //     int256 lagTTokenABalance = tPool.tokenABalance;

    //     //lag_T(buy_currency,sell_currency,sell_currency)=T(buy_currency,sell_currency,sell_currency);
    //     int256 lagTTokenBBalance = tPool.tokenBBalance;

    //     //%substract amount and add fees to amount_in
    //     //T(buy_currency,sell_currency,buy_currency)=lag_T(buy_currency,sell_currency,buy_currency)-Buy*(1-fee_T(buy_currency,sell_currency)); ****
    //     tPool.tokenABalance =
    //         lagTTokenABalance -
    //         (amount - ((tPool.fee * amount) / 1 ether));

    //     // T(buy_currency,sell_currency,sell_currency)=lag_T(buy_currency,sell_currency,buy_currency)*lag_T(buy_currency,sell_currency,sell_currency)/(lag_T(buy_currency,sell_currency,buy_currency)-Buy); // %calculate amount_out
    //     tPool.tokenBBalance = tPool.tokenBBalance =
    //         (lagTTokenABalance * lagTTokenBBalance) /
    //         (lagTTokenABalance - amount);

    //     // for k=1:number_currencies
    //     for (uint256 k = 0; k < iks.length; k++) {
    //         if (tPool.tokenA == iks[k].tokenAddress) continue;

    //         //lag_R(buy_currency,k,buy_currency)=R(buy_currency,k,buy_currency);
    //         lagR[k].tokenABalance = IERC20(IvPair(iks[k]).token0())
    //             .tokenABalance;

    //         //lag_R(buy_currency,k,sell_currency)=R(buy_currency,k,sell_currency);
    //         lagR[k].tokenABalance = IERC20(IvPair(iks[k]).token0())
    //             .tokenBBalance;
    //     }

    //     // %take buy_currency proportional from real and virtual pool
    //     /*  R(buy_currency,sell_currency,buy_currency)=
    //                    lag_R(buy_currency,sell_currency,buy_currency) *
    //                    T(buy_currency,sell_currency,buy_currency)/
    //                    lag_T(buy_currency,sell_currency,buy_currency); */

    //     if (vPairAddress > address(0)) {
    //         rPools[tradePoolIndex].tokenABalance =
    //             (lagR[tradePoolIndex].tokenABalance * tPool.tokenABalance) /
    //             lagTTokenABalance;

    //         // %take sell_currency proportional from real and virtual pool
    //         /* R(buy_currency,sell_currency,sell_currency)=
    //         lag_R(buy_currency,sell_currency,sell_currency)*
    //         T(buy_currency,sell_currency,sell_currency)/
    //         lag_T(buy_currency,sell_currency,sell_currency);*/

    //         rPools[tradePoolIndex].tokenBBalance =
    //             (lagR[tradePoolIndex].tokenBBalance *
    //                 tPools[tradePoolIndex].tokenBBalance) /
    //             lagTTokenBBalance;
    //     }
    //     //% Updating of non-native pools that contribute to BC virtual pool;
    //     for (uint256 k = 0; k < _tokens.length; k++) {
    //         if (
    //             buy_currency == _tokens[k].tokenAddress ||
    //             sell_currency == _tokens[k].tokenAddress
    //         ) continue;

    //         uint256 buy_k_poolIndex = getPoolIndex(
    //             buy_currency,
    //             _tokens[k].tokenAddress
    //         );

    //         uint256 k_buy_poolIndex = getPoolIndex(
    //             _tokens[k].tokenAddress,
    //             buy_currency
    //         );

    //         //sum lagR tokenA balance
    //         int256 summ = 0;
    //         for (uint256 z = 0; z < lagR.length; z++) {
    //             if (lagR[z].tokenABalance > 0) {
    //                 summ += lagR[z].tokenABalance;
    //             }
    //         }

    //         /*R(buy_currency,k,buy_currency)=
    //             //R(buy_currency,k,buy_currency)+
    //             ((T(buy_currency,sell_currency,buy_currency)-lag_T(buy_currency,sell_currency,buy_currency))-
    //             (R(buy_currency,sell_currency,buy_currency)-lag_R(buy_currency,sell_currency,buy_currency)))*
    //             lag_R(buy_currency,k,buy_currency)/
    //             (sum(lag_R(buy_currency,1:number_currencies,buy_currency))
    //             -lag_R(buy_currency,sell_currency,buy_currency));
    // */
    //         rPools[buy_k_poolIndex].tokenABalance =
    //             rPools[buy_k_poolIndex].tokenABalance +
    //             (((tPools[tradePoolIndex].tokenABalance - lagTTokenABalance) -
    //                 (rPools[tradePoolIndex].tokenABalance -
    //                     lagR[tradePoolIndex].tokenABalance)) *
    //                 lagR[buy_k_poolIndex].tokenABalance) /
    //             (summ - lagR[tradePoolIndex].tokenABalance);

    //         //fill reverse pool
    //         //R(k,buy_currency,buy_currency)=R(buy_currency,k,buy_currency);
    //         rPools[k_buy_poolIndex].tokenBBalance = rPools[buy_k_poolIndex]
    //             .tokenABalance;
    //     }

    //     // % Updating reserves of real pools and all the subsequent calculations;
    //     // i=buy_currency;
    //     // for k=1:number_currencies
    //     //     if (k~=buy_currency & k~=sell_currency)
    //     //         R(buy_currency,k,sell_currency)=R(buy_currency,k,sell_currency)+((T(buy_currency,sell_currency,sell_currency)-lag_T(buy_currency,sell_currency,sell_currency))-(R(buy_currency,sell_currency,sell_currency)-lag_R(buy_currency,sell_currency,sell_currency)))*lag_R(buy_currency,k,buy_currency)/(sum(lag_R(buy_currency,1:number_currencies,buy_currency))-lag_R(buy_currency,sell_currency,buy_currency));
    //     //         R(k,buy_currency,sell_currency)=R(buy_currency,k,sell_currency);
    //     //     end;
    //     // end;
    //     for (uint256 k = 0; k < _tokens.length; k++) {
    //         if (
    //             buy_currency == _tokens[k].tokenAddress ||
    //             sell_currency == _tokens[k].tokenAddress
    //         ) continue;

    //         uint256 buy_k_poolIndex = getPoolIndex(
    //             buy_currency,
    //             _tokens[k].tokenAddress
    //         );

    //         uint256 k_buy_poolIndex = getPoolIndex(
    //             _tokens[k].tokenAddress,
    //             buy_currency
    //         );

    //         //sum lagR tokenA balance
    //         int256 summ = 0;
    //         for (uint256 z = 0; z < lagR.length; z++) {
    //             if (lagR[z].tokenABalance > 0) {
    //                 summ += lagR[z].tokenABalance;
    //             }
    //         }

    //         /*R(buy_currency,k,sell_currency)=
    //             R(buy_currency,k,sell_currency)+
    //             ((T(buy_currency,sell_currency,sell_currency)-lag_T(buy_currency,sell_currency,sell_currency))-
    //             (R(buy_currency,sell_currency,sell_currency)-lag_R(buy_currency,sell_currency,sell_currency)))*
    //             lag_R(buy_currency,k,buy_currency)/(sum(lag_R(buy_currency,1:number_currencies,buy_currency))-
    //             lag_R(buy_currency,sell_currency,buy_currency));*/

    //         rPools[buy_k_poolIndex].reserves[sell_currency].reserveBalance =
    //             rPools[buy_k_poolIndex].reserves[sell_currency].reserveBalance +
    //             (((tPools[tradePoolIndex].tokenBBalance - lagTTokenBBalance) -
    //                 (rPools[tradePoolIndex].tokenBBalance -
    //                     lagR[tradePoolIndex].tokenBBalance)) *
    //                 lagR[buy_k_poolIndex].tokenABalance) /
    //             (summ - lagR[tradePoolIndex].tokenABalance);

    //         //fill reverse pool
    //         rPools[k_buy_poolIndex]
    //             .reserves[sell_currency]
    //             .reserveBalance = rPools[buy_k_poolIndex]
    //             .reserves[sell_currency]
    //             .reserveBalance;
    //     }
    // }

    function changeFactory(address factory) public onlyOwner {
        _factory = factory;
    }
}
