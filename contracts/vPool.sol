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
    event DebugA(string message, address add, uint256 value);

    modifier onlyOwner() {
        require(msg.sender == owner);
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
                vPool.tokenA = ikToken0;
                vPool.tokenB = jkToken0;
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

    function CalculateTotalPool(
        address[] memory iks,
        address[] memory jks,
        address vPairAddress
    ) external view returns (virtualPoolModel memory tPool) {
        virtualPoolModel memory vPool = this.CalculateVirtualPool(iks, jks);

        tPool = vPool;

        uint256 vPairTokenABalance = 0;
        uint256 vPairTokenBBalance = 0;
        uint256 vPairFee = 0;

        if (vPairAddress > address(0)) {
            vPairTokenABalance = IERC20(IvPair(vPairAddress).token0())
                .balanceOf(vPairAddress);

            vPairTokenBBalance = IERC20(IvPair(vPairAddress).token1())
                .balanceOf(vPairAddress);

            vPairFee = IvPair(vPairAddress).fee();
        }

        tPool.tokenABalance = vPairTokenABalance + vPool.tokenABalance;
        tPool.tokenBBalance = vPairTokenBBalance + vPool.tokenBBalance;

        if (vPool.tokenABalance > 0) {
            tPool.fee = vSwapMath.totalPoolFeeAvg(
                vPairFee,
                vPairTokenABalance,
                vPool.fee,
                vPool.tokenABalance
            );
        }

        return tPool;
    }

    function Quote(
        address[] memory iks,
        address[] memory jks,
        address vPairAddress,
        uint256 amount
    ) external view returns (uint256) {
        virtualPoolModel memory tPool = this.CalculateTotalPool(
            iks,
            jks,
            vPairAddress
        );

        return vSwapMath.quote(tPool, amount);
    }

    //     function swap(
    //         uint256[] memory ks,
    //         uint256[] memory js,
    //         address vPairAddress,
    //         int256 amount
    //     ) public {
    //         // buy_currency=2;
    //         // sell_currency=3;
    //         // Buy=30;

    //         VirtualPool memory tPool = this.calculateTotalPool(
    //             ks,
    //             js,
    //             vPairAddress
    //         );

    //         VirtualPoolVM[] memory lagR = new VirtualPoolVM[](rPools.length);

    //         //lag_T(buy_currency,sell_currency,buy_currency)=T(buy_currency,sell_currency,buy_currency);
    //         int256 lagTTokenABalance = tPool.tokenABalance;

    //         //lag_T(buy_currency,sell_currency,sell_currency)=T(buy_currency,sell_currency,sell_currency);
    //         int256 lagTTokenBBalance = tPool.tokenBBalance;

    //         //%substract amount and add fees to amount_in
    //         //T(buy_currency,sell_currency,buy_currency)=lag_T(buy_currency,sell_currency,buy_currency)-Buy*(1-fee_T(buy_currency,sell_currency)); ****
    //         tPool.tokenABalance =
    //             lagTTokenABalance -
    //             (amount - ((tPools[tradePoolIndex].fee * amount) / 1 ether));

    //         // T(buy_currency,sell_currency,sell_currency)=lag_T(buy_currency,sell_currency,buy_currency)*lag_T(buy_currency,sell_currency,sell_currency)/(lag_T(buy_currency,sell_currency,buy_currency)-Buy); // %calculate amount_out
    //         tPool.tokenBBalance = tPools[tradePoolIndex].tokenBBalance =
    //             (lagTTokenABalance * lagTTokenBBalance) /
    //             (lagTTokenABalance - amount);

    //         // for k=1:number_currencies
    //         for (uint256 k = 0; k < _tokens.length; k++) {
    //             if (buy_currency == _tokens[k].tokenAddress) continue;

    //             //lag_R(buy_currency,k,buy_currency)=R(buy_currency,k,buy_currency);
    //             lagR[buy_k_poolIndex].tokenABalance = rPools[buy_k_poolIndex]
    //                 .tokenABalance;

    //             //lag_R(buy_currency,k,sell_currency)=R(buy_currency,k,sell_currency);
    //             lagR[buy_k_poolIndex].tokenBBalance = rPools[buy_k_poolIndex]
    //                 .tokenBBalance;
    //         }

    //         // %take buy_currency proportional from real and virtual pool
    //         /*  R(buy_currency,sell_currency,buy_currency)=
    //                    lag_R(buy_currency,sell_currency,buy_currency) *
    //                    T(buy_currency,sell_currency,buy_currency)/
    //                    lag_T(buy_currency,sell_currency,buy_currency); */

    //         rPools[tradePoolIndex].tokenABalance =
    //             (lagR[tradePoolIndex].tokenABalance *
    //                 tPools[tradePoolIndex].tokenABalance) /
    //             lagTTokenABalance;

    //         if (rPools[tradePoolIndex].tokenABalance < 0) {}
    //         // %take sell_currency proportional from real and virtual pool
    //         /* R(buy_currency,sell_currency,sell_currency)=
    //         lag_R(buy_currency,sell_currency,sell_currency)*
    //         T(buy_currency,sell_currency,sell_currency)/
    //         lag_T(buy_currency,sell_currency,sell_currency);*/

    //         rPools[tradePoolIndex].tokenBBalance =
    //             (lagR[tradePoolIndex].tokenBBalance *
    //                 tPools[tradePoolIndex].tokenBBalance) /
    //             lagTTokenBBalance;

    //         //% Updating of non-native pools that contribute to BC virtual pool;
    //         for (uint256 k = 0; k < _tokens.length; k++) {
    //             if (
    //                 buy_currency == _tokens[k].tokenAddress ||
    //                 sell_currency == _tokens[k].tokenAddress
    //             ) continue;

    //             uint256 buy_k_poolIndex = getPoolIndex(
    //                 buy_currency,
    //                 _tokens[k].tokenAddress
    //             );

    //             uint256 k_buy_poolIndex = getPoolIndex(
    //                 _tokens[k].tokenAddress,
    //                 buy_currency
    //             );

    //             //sum lagR tokenA balance
    //             int256 summ = 0;
    //             for (uint256 z = 0; z < lagR.length; z++) {
    //                 if (lagR[z].tokenABalance > 0) {
    //                     summ += lagR[z].tokenABalance;
    //                 }
    //             }

    //             /*R(buy_currency,k,buy_currency)=
    //             //R(buy_currency,k,buy_currency)+
    //             ((T(buy_currency,sell_currency,buy_currency)-lag_T(buy_currency,sell_currency,buy_currency))-
    //             (R(buy_currency,sell_currency,buy_currency)-lag_R(buy_currency,sell_currency,buy_currency)))*
    //             lag_R(buy_currency,k,buy_currency)/
    //             (sum(lag_R(buy_currency,1:number_currencies,buy_currency))
    //             -lag_R(buy_currency,sell_currency,buy_currency));
    // */
    //             rPools[buy_k_poolIndex].tokenABalance =
    //                 rPools[buy_k_poolIndex].tokenABalance +
    //                 (((tPools[tradePoolIndex].tokenABalance - lagTTokenABalance) -
    //                     (rPools[tradePoolIndex].tokenABalance -
    //                         lagR[tradePoolIndex].tokenABalance)) *
    //                     lagR[buy_k_poolIndex].tokenABalance) /
    //                 (summ - lagR[tradePoolIndex].tokenABalance);

    //             //fill reverse pool
    //             //R(k,buy_currency,buy_currency)=R(buy_currency,k,buy_currency);
    //             rPools[k_buy_poolIndex].tokenBBalance = rPools[buy_k_poolIndex]
    //                 .tokenABalance;
    //         }

    //         // % Updating reserves of real pools and all the subsequent calculations;
    //         // i=buy_currency;
    //         // for k=1:number_currencies
    //         //     if (k~=buy_currency & k~=sell_currency)
    //         //         R(buy_currency,k,sell_currency)=R(buy_currency,k,sell_currency)+((T(buy_currency,sell_currency,sell_currency)-lag_T(buy_currency,sell_currency,sell_currency))-(R(buy_currency,sell_currency,sell_currency)-lag_R(buy_currency,sell_currency,sell_currency)))*lag_R(buy_currency,k,buy_currency)/(sum(lag_R(buy_currency,1:number_currencies,buy_currency))-lag_R(buy_currency,sell_currency,buy_currency));
    //         //         R(k,buy_currency,sell_currency)=R(buy_currency,k,sell_currency);
    //         //     end;
    //         // end;
    //         for (uint256 k = 0; k < _tokens.length; k++) {
    //             if (
    //                 buy_currency == _tokens[k].tokenAddress ||
    //                 sell_currency == _tokens[k].tokenAddress
    //             ) continue;

    //             uint256 buy_k_poolIndex = getPoolIndex(
    //                 buy_currency,
    //                 _tokens[k].tokenAddress
    //             );

    //             uint256 k_buy_poolIndex = getPoolIndex(
    //                 _tokens[k].tokenAddress,
    //                 buy_currency
    //             );

    //             //sum lagR tokenA balance
    //             int256 summ = 0;
    //             for (uint256 z = 0; z < lagR.length; z++) {
    //                 if (lagR[z].tokenABalance > 0) {
    //                     summ += lagR[z].tokenABalance;
    //                 }
    //             }

    //             /*R(buy_currency,k,sell_currency)=
    //             R(buy_currency,k,sell_currency)+
    //             ((T(buy_currency,sell_currency,sell_currency)-lag_T(buy_currency,sell_currency,sell_currency))-
    //             (R(buy_currency,sell_currency,sell_currency)-lag_R(buy_currency,sell_currency,sell_currency)))*
    //             lag_R(buy_currency,k,buy_currency)/(sum(lag_R(buy_currency,1:number_currencies,buy_currency))-
    //             lag_R(buy_currency,sell_currency,buy_currency));*/

    //             rPools[buy_k_poolIndex].reserves[sell_currency].reserveBalance =
    //                 rPools[buy_k_poolIndex].reserves[sell_currency].reserveBalance +
    //                 (((tPools[tradePoolIndex].tokenBBalance - lagTTokenBBalance) -
    //                     (rPools[tradePoolIndex].tokenBBalance -
    //                         lagR[tradePoolIndex].tokenBBalance)) *
    //                     lagR[buy_k_poolIndex].tokenABalance) /
    //                 (summ - lagR[tradePoolIndex].tokenABalance);

    //             //fill reverse pool
    //             rPools[k_buy_poolIndex]
    //                 .reserves[sell_currency]
    //                 .reserveBalance = rPools[buy_k_poolIndex]
    //                 .reserves[sell_currency]
    //                 .reserveBalance;
    //         }
    //     }

    // function swap(
    //     uint256[] memory ks,
    //     uint256[] memory js,
    //     address vPairAddress,
    //     int256 amount
    // ) public {
    //     VirtualPool memory tPool = this.calculateTotalPool(
    //         ks,
    //         js,
    //         vPairAddress
    //     );

    //     require(
    //         IERC20(tPool.tokenA).transferFrom(
    //             msg.sender,
    //             address(this),
    //             uint256(amount)
    //         ),
    //         "Failed to transfer token A to contract"
    //     );

    //     int256 outBalance = vSwapMath.quote(tPool, amount);

    //     VirtualPool[] memory lagR = new VirtualPool[](rPools.length);

    //     // %save current values

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
    //     for (uint256 i = 0; i < ks.length; i++) {
    //         //lag_R(buy_currency,k,buy_currency)=R(buy_currency,k,buy_currency);
    //         lagR[ks[i]].tokenABalance = rPools[ks[i]].tokenABalance;

    //         //lag_R(buy_currency,k,sell_currency)=R(buy_currency,k,sell_currency);
    //         lagR[ks[i]].tokenBBalance = rPools[ks[i]].tokenBBalance;
    //     }

    //     // %take buy_currency proportional from real and virtual pool
    //     /*  R(buy_currency,sell_currency,buy_currency)=
    //                    lag_R(buy_currency,sell_currency,buy_currency) *
    //                    T(buy_currency,sell_currency,buy_currency)/
    //                    lag_T(buy_currency,sell_currency,buy_currency); */

    //     //lag_R(buy_currency,k,buy_currency)=R(buy_currency,k,buy_currency);
    //     lagR[tPool.rPoolIndex].tokenABalance = rPools[tPool.rPoolIndex]
    //         .tokenABalance;

    //     //lag_R(buy_currency,k,sell_currency)=R(buy_currency,k,sell_currency);
    //     lagR[tPool.rPoolIndex].tokenBBalance = rPools[tPool.rPoolIndex]
    //         .tokenBBalance;

    //     // %take sell_currency proportional from real and virtual pool

    //     if (tPool.rPoolIndex > 0) {
    //         /* R(buy_currency,sell_currency,sell_currency)=
    //         lag_R(buy_currency,sell_currency,sell_currency)*
    //         T(buy_currency,sell_currency,sell_currency)/
    //         lag_T(buy_currency,sell_currency,sell_currency);*/
    //         rPools[tPool.rPoolIndex].tokenABalance =
    //             (lagR[tPool.rPoolIndex].tokenABalance * tPool.tokenABalance) /
    //             lagTTokenABalance;

    //         rPools[tPool.rPoolIndex].tokenBBalance =
    //             (lagR[tPool.rPoolIndex].tokenBBalance * tPool.tokenBBalance) /
    //             lagTTokenBBalance;

    //         // %fill reverse
    //         // R(sell_currency,buy_currency,buy_currency)=R(buy_currency,sell_currency,buy_currency);
    //         rPools[rPools[tPool.rPoolIndex].reversePoolIndex]
    //             .tokenBBalance = rPools[tPool.rPoolIndex].tokenABalance;

    //         // R(sell_currency,buy_currency,sell_currency)=R(buy_currency,sell_currency,sell_currency);
    //         rPools[rPools[tPool.rPoolIndex].reversePoolIndex]
    //             .tokenABalance = rPools[tPool.rPoolIndex].tokenBBalance;
    //     }

    //     //% Updating of non-native pools that contribute to BC virtual pool;
    //     for (uint256 i = 0; i < ks.length; i++) {
    //         //sum lagR tokenA balance

    //         /*R(buy_currency,k,buy_currency)=
    //             //R(buy_currency,k,buy_currency)+
    //             ((T(buy_currency,sell_currency,buy_currency)-lag_T(buy_currency,sell_currency,buy_currency))-
    //             (R(buy_currency,sell_currency,buy_currency)-lag_R(buy_currency,sell_currency,buy_currency)))*
    //             lag_R(buy_currency,k,buy_currency)/
    //             (sum(lag_R(buy_currency,1:number_currencies,buy_currency))
    //             -lag_R(buy_currency,sell_currency,buy_currency));

    // */
    //         rPools[ks[i]].tokenABalance =
    //             rPools[ks[i]].tokenABalance +
    //             (((tPool.tokenABalance - lagTTokenABalance) -
    //                 (rPools[tPool.rPoolIndex].tokenABalance -
    //                     lagR[tPool.rPoolIndex].tokenABalance)) *
    //                 lagR[ks[i]].tokenABalance) /
    //             (vPoolCalculations.sumVirtualPoolsArray(lagR) -
    //                 lagR[tPool.rPoolIndex].tokenABalance);

    //         //fill reverse pool
    //         //R(k,buy_currency,buy_currency)=R(buy_currency,k,buy_currency);
    //         rPools[rPools[ks[i]].reversePoolIndex].tokenBBalance = rPools[ks[i]]
    //             .tokenABalance;
    //     }

    //     for (uint256 i = 0; i < js.length; i++) {
    //         //sum lagR tokenA balance

    //         /*R(buy_currency,k,buy_currency)=
    //             //R(buy_currency,k,buy_currency)+
    //             ((T(buy_currency,sell_currency,buy_currency)-lag_T(buy_currency,sell_currency,buy_currency))-
    //             (R(buy_currency,sell_currency,buy_currency)-lag_R(buy_currency,sell_currency,buy_currency)))*
    //             lag_R(buy_currency,k,buy_currency)/
    //             (sum(lag_R(buy_currency,1:number_currencies,buy_currency))
    //             -lag_R(buy_currency,sell_currency,buy_currency));

    // */
    //         rPools[js[i]].tokenABalance =
    //             rPools[js[i]].tokenABalance +
    //             (((tPool.tokenABalance - lagTTokenABalance) -
    //                 (rPools[tPool.rPoolIndex].tokenABalance -
    //                     lagR[tPool.rPoolIndex].tokenABalance)) *
    //                 lagR[js[i]].tokenABalance) /
    //             (vPoolCalculations.sumVirtualPoolsArray(lagR) -
    //                 lagR[tPool.rPoolIndex].tokenABalance);

    //         //fill reverse pool
    //         //R(k,buy_currency,buy_currency)=R(buy_currency,k,buy_currency);
    //         rPools[rPools[js[i]].reversePoolIndex].tokenBBalance = rPools[js[i]]
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
    //     int256 reserveBalanceTokenB = 0;

    //     for (uint256 i = 0; i < ks.length; i++) {
    //         //sum lagR tokenA balance

    //         /*R(buy_currency,k,sell_currency)=
    //             R(buy_currency,k,sell_currency)+
    //             ((T(buy_currency,sell_currency,sell_currency)-lag_T(buy_currency,sell_currency,sell_currency))-
    //             (R(buy_currency,sell_currency,sell_currency)-lag_R(buy_currency,sell_currency,sell_currency)))*
    //             lag_R(buy_currency,k,buy_currency)/(sum(lag_R(buy_currency,1:number_currencies,buy_currency))-
    //             lag_R(buy_currency,sell_currency,buy_currency));*/

    //         // rPools[ks[i]].reserveBalance[rPools[ks[i]].tokenB] =
    //         //     rPools[ks[i]].reserveBalance[rPools[ks[i]].tokenB] +
    //         //     (((tPool.tokenBBalance - lagTTokenBBalance) -
    //         //         (rPools[tPool.rPoolIndex].tokenBBalance -
    //         //             lagR[tPool.rPoolIndex].tokenBBalance)) *
    //         //         lagR[ks[i]].tokenABalance) /
    //         //     (vPoolCalculations.sumVirtualPoolsArray(lagR) -
    //         //         lagR[tPool.rPoolIndex].tokenABalance);

    //         reserveBalanceTokenB =
    //             reserveBalanceTokenB +
    //             (((tPool.tokenBBalance - lagTTokenBBalance) -
    //                 (rPools[tPool.rPoolIndex].tokenBBalance -
    //                     lagR[tPool.rPoolIndex].tokenBBalance)) *
    //                 lagR[ks[i]].tokenABalance) /
    //             (vPoolCalculations.sumVirtualPoolsArray(lagR) -
    //                 lagR[tPool.rPoolIndex].tokenABalance);
    //     }

    //     reserveManager.updateReserveBalance(
    //         tPool.rPoolIndex,
    //         rPools[ks[0]].tokenB,
    //         reserveBalanceTokenB
    //     );

    //     reserveManager.updateReserveBalance(
    //         rPools[tPool.rPoolIndex].reversePoolIndex,
    //         rPools[ks[0]].tokenB,
    //         reserveBalanceTokenB
    //     );

    //     //fill reverse pool
    //     // rPools[rPools[ks[i]].reversePoolIndex].reserveBalance[
    //     //     rPools[ks[i]].tokenB
    //     // ] = rPools[ks[i]].reserveBalance[rPools[ks[i]].tokenB];

    //     // emit ADebug("2 msg.sender", msg.sender);
    //     // emit ADebug("2 address(this)", address(this));
    //     // emit UDebug("2 amount", uint256(outBalance));

    //     require(
    //         IERC20(tPool.tokenB).transfer(msg.sender, uint256(outBalance)),
    //         "Failed to transfer out amount to user"
    //     );

    //     //calculate below threshold for rPool
    // }

    function changeFactory(address factory) public onlyOwner {
        _factory = factory;
    }
}
