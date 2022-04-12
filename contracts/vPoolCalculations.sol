import "./Types256.sol";
import "./ERC20/IERC20.sol";
import "./ERC20/ERC20.sol";
import "./new/vPair.sol";

library vPoolCalculations {
    function max(int256 a, int256 b) internal pure returns (int256) {
        return a >= b ? a : b;
    }

    function min(int256 a, int256 b) internal pure returns (int256) {
        return a < b ? a : b;
    }

    function sumVirtualPoolsArray(VirtualPool[] memory vPools)
        public
        view
        returns (int256)
    {
        int256 sum = 0;
        for (uint256 i = 0; i < vPools.length; i++) {
            sum += vPools[i].tokenABalance;
        }

        return sum;
    }

    function _calculateVirtualPool(address[] memory ks, address[] memory js)
        public
        view
        returns (VirtualPool memory)
    {
        int256 epsilon = 1 wei;

        VirtualPool memory vPool;
        vPool.fee = 0.003 ether;
        
        vPool.tokenA = vPair(ks[0]).getTokenA();
        vPool.tokenB = vPair(js[0]).getTokenA();

        for (uint256 i = 0; i < ks.length; i++) {
            address ikIndex = ks[i];
            address jkIndex = js[i];

            int256 belowReserveIK = vPair(ikIndex).getBelowReserve();
            int256 belowReserveJK = vPair(jkIndex).getBelowReserve();

            //  V(i,j,i)=V(i,j,i)+ind_below_reserve_threshold(i,k)*R(i,k,i)*min(R(i,k,k),R(j,k,k))/max(R(i,k,k),epsilon);
            vPool.tokenABalance =
                vPool.tokenABalance +
                (belowReserveIK *
                    vPair(ikIndex).tokenABalance() *
                    min(
                        vPair(ikIndex).tokenBBalance(),
                        vPair(jkIndex).tokenBBalance()
                    )) /
                max(vPair(ikIndex).tokenBBalance(), epsilon);

            //  V(i,j,j)=V(i,j,j)+ind_below_reserve_threshold(i,k)*R(j,k,j)*min(R(i,k,k),R(j,k,k))/max(R(j,k,k),epsilon);
            vPool.tokenBBalance =
                vPool.tokenBBalance +
                (belowReserveJK *
                    vPair(jkIndex).tokenABalance() *
                    min(
                        vPair(ikIndex).tokenBBalance(),
                        vPair(jkIndex).tokenBBalance()
                    )) /
                max(vPair(jkIndex).tokenBBalance(), epsilon);
        }

        return vPool;
    }

    function getTotalPool(Pool[] storage rPools, VirtualPool memory vPool)
        public
        view
        returns (VirtualPool memory)
    {
        VirtualPool memory tPool = vPool;

        int256 rPoolTokenABalance = 0;
        int256 rPoolTokenBBalance = 0;
        int256 rPoolFee = 0;

        if (vPool.rPoolIndex > 0) {
            rPoolTokenABalance = rPools[vPool.rPoolIndex].tokenABalance;
            rPoolTokenBBalance = rPools[vPool.rPoolIndex].tokenBBalance;
            rPoolFee = rPools[vPool.rPoolIndex].fee;
        }

        tPool.tokenABalance = rPoolTokenABalance + vPool.tokenABalance;

        tPool.tokenBBalance = rPoolTokenBBalance + vPool.tokenBBalance;

        if (vPool.tokenABalance > 0) {
            tPool.fee =
                (rPoolFee *
                    rPoolTokenABalance +
                    vPool.fee *
                    vPool.tokenABalance) /
                vPool.tokenABalance;
        }

        return tPool;
    }

    // function _calculateReserveRatio(
    //     Pool[] storage rPools,
    //     uint32 rPoolIndex,
    //     uint32[] memory ks,
    //     uint32[] memory js
    // ) internal view returns (int256[] memory) {
    //     int256 reserveRatio = 0;
    //     int256 epsilon = 1 wei;

    //     for (uint256 k = 0; k < ks.length; k++) {
    //         if (rPoolIndex == ks[k] || rPoolIndex == js[k]) continue;

    //         reserveRatio =
    //             reserveRatio +
    //             (rPools[rPoolIndex]
    //                 .reserves[ks[k].tokenAddress]
    //                 .reserveBalance *
    //                 max(
    //                     rPools[ks[k]].tokenABalance /
    //                         max(rPools[ks[k]].tokenBBalance, epsilon),
    //                     ((rPools[js[k]].tokenABalance /
    //                         max(rPools[js[k]].tokenBBalance, epsilon)) *
    //                         rPools[rPoolIndex].tokenABalance) /
    //                         max(rPools[rPoolIndex].tokenBBalance, epsilon)
    //                 )) /
    //             (2 * max(rPools[rPoolIndex].tokenABalance, epsilon));
    //     }

    //     return reserveRatio;
    // }

    // function _calculateBelowThreshold(
    //     Pool[] storage rPools,
    //     address[] memory tokens
    // ) internal view returns (int256[] memory) {
    //     int256[] memory reserveRatio = _calculateReserveRatio(rPools, tokens);

    //     int256[] memory belowThreshold = new int256[](rPools.length);

    //     for (uint256 i = 0; i < rPools.length; i++) {
    //         if (
    //             reserveRatio[i] >= rPools[i].maxReserveRatio &&
    //             belowThreshold[i] == 1
    //         ) {
    //             belowThreshold[i] = 0;
    //         } else if (reserveRatio[i] == 0) {
    //             belowThreshold[i] = 1;
    //         }
    //     }

    //     return belowThreshold;
    // }

    function tokenExist(address[] memory tokens, address token)
        internal
        pure
        returns (bool)
    {
        for (uint256 i = 0; i < tokens.length; i++) {
            if (tokens[i] == token) {
                return true;
            }
        }

        return false;
    }

    function costVirtuswap(
        Pool[] storage rPools,
        VirtualPool memory tPool,
        int256 amount
    ) public view returns (int256) {
        int256 lagTTokenABalance = tPool.tokenABalance;
        int256 lagTTokenBBalance = tPool.tokenBBalance;

        /*
        T_virtuswap(buy_currency,sell_currency,buy_currency,time)=lag_T(buy_currency,sell_currency,buy_currency)-Buy*(1-lag_fee_T(buy_currency,sell_currency));
        */
        tPool.tokenABalance =
            lagTTokenABalance -
            (amount - ((tPool.fee * amount) / 1 ether));

        // T(buy_currency,sell_currency,sell_currency)=lag_T(buy_currency,sell_currency,buy_currency)*lag_T(buy_currency,sell_currency,sell_currency)/(lag_T(buy_currency,sell_currency,buy_currency)-Buy); // %calculate amount_out
        tPool.tokenBBalance =
            (lagTTokenABalance * lagTTokenBBalance) /
            (lagTTokenABalance - amount);

        int256 calcA = tPool.tokenBBalance - lagTTokenBBalance;
        int256 calcB = (amount * lagTTokenBBalance) / lagTTokenABalance;
        int256 calcD = (calcA - calcB);

        calcD = calcD * 10000;
        int256 cost = calcD / calcB;

        return cost;
    }

    // function costUniswapDirect(
    //     Pool[] storage rPools,
    //     address buy_currency,
    //     address sell_currency,
    //     int256 amount
    // ) public view returns (int256) {
    //     uint256 tradePoolIndex = getPoolIndex(
    //         rPools,
    //         buy_currency,
    //         sell_currency
    //     );

    //     int256 lagRTokenABalance = rPools[tradePoolIndex].tokenABalance;
    //     int256 lagRTokenBBalance = rPools[tradePoolIndex].tokenBBalance;

    //     // T(buy_currency,sell_currency,sell_currency)=lag_T(buy_currency,sell_currency,buy_currency)*lag_T(buy_currency,sell_currency,sell_currency)/(lag_T(buy_currency,sell_currency,buy_currency)-Buy); // %calculate amount_out
    //     int256 tradePoolTokenBBalance = (lagRTokenABalance *
    //         lagRTokenBBalance) / (lagRTokenABalance - amount);

    //     int256 calcA = tradePoolTokenBBalance - lagRTokenBBalance;
    //     int256 calcB = (amount * lagRTokenBBalance) / lagRTokenABalance;
    //     int256 calcD = (calcA - calcB);

    //     calcD = calcD * 10000;
    //     int256 cost = calcD / calcB;
    //     return cost;
    // }

    function calculateVswapCost(VirtualPool memory tPool, int256 amount)
        public
        view
        returns (int256)
    {
        int256 lagTTokenABalance = tPool.tokenABalance;
        int256 lagTTokenBBalance = tPool.tokenBBalance;

        /*
        T_virtuswap(buy_currency,sell_currency,buy_currency,time)=lag_T(buy_currency,sell_currency,buy_currency)-Buy*(1-lag_fee_T(buy_currency,sell_currency));
        */
        tPool.tokenABalance =
            lagTTokenABalance -
            (amount - ((tPool.fee * amount) / 1 ether));

        // T(buy_currency,sell_currency,sell_currency)=lag_T(buy_currency,sell_currency,buy_currency)*lag_T(buy_currency,sell_currency,sell_currency)/(lag_T(buy_currency,sell_currency,buy_currency)-Buy); // %calculate amount_out
        tPool.tokenBBalance =
            (lagTTokenABalance * lagTTokenBBalance) /
            (lagTTokenABalance - amount);

        int256 calcA = tPool.tokenBBalance - lagTTokenBBalance;
        int256 calcB = (amount * lagTTokenBBalance) / lagTTokenABalance;
        int256 calcD = (calcA - calcB);

        calcD = calcD * 1000000;
        int256 cost = calcD / calcB;

        return cost;
    }

    function appendAddresses(address a, address b)
        internal
        pure
        returns (string memory)
    {
        return string(abi.encodePacked(a, b));
    }

    // function quote(
    //     Pool[] storage rPools,
    //     uint32 rPoolIndex,
    //     uint32[] memory ks,
    //     uint32[] memory js,
    //     int256 amount
    // ) public view returns (int256) {
    //     VirtualPool memory tPool = getTotalPool(rPools, rPoolIndex, ks, js);

    //     /*
    //     T_virtuswap(buy_currency,sell_currency,buy_currency,time)=lag_T(buy_currency,sell_currency,buy_currency)-Buy*(1-lag_fee_T(buy_currency,sell_currency));
    //     */
    //     // int256 tokenABalance = tPool.tokenABalance -
    //     //     (amount - ((tPool.fee * amount) / 1 ether));

    //     // T(buy_currency,sell_currency,sell_currency)=lag_T(buy_currency,sell_currency,buy_currency)*lag_T(buy_currency,sell_currency,sell_currency)/(lag_T(buy_currency,sell_currency,buy_currency)-Buy); // %calculate amount_out
    //     int256 tokenBBalance = (tPool.tokenABalance * tPool.tokenBBalance) /
    //         (tPool.tokenABalance - amount);

    //     return tokenBBalance - tPool.tokenBBalance;
    // }

    function quote(
        Pool[] storage rPools,
        VirtualPool memory tPool,
        int256 amount
    ) public view returns (int256) {
        int256 lagTTokenABalance = tPool.tokenABalance;
        int256 lagTTokenBBalance = tPool.tokenBBalance;

        /*
        T_virtuswap(buy_currency,sell_currency,buy_currency,time)=lag_T(buy_currency,sell_currency,buy_currency)-Buy*(1-lag_fee_T(buy_currency,sell_currency));
        */
        tPool.tokenABalance =
            lagTTokenABalance -
            (amount - ((tPool.fee * amount) / 1 ether));

        // T(buy_currency,sell_currency,sell_currency)=lag_T(buy_currency,sell_currency,buy_currency)*lag_T(buy_currency,sell_currency,sell_currency)/(lag_T(buy_currency,sell_currency,buy_currency)-Buy); // %calculate amount_out
        tPool.tokenBBalance =
            (lagTTokenABalance * lagTTokenBBalance) /
            (lagTTokenABalance - amount);

        int256 finalQuote = tPool.tokenBBalance - lagTTokenBBalance;

        return finalQuote;
    }

    function calculateUniswapIndirect(
        Pool[] storage rPools,
        uint256[] memory ks,
        uint256[] memory js,
        int256 amount
    ) public view returns (int256) {
        int256[] memory res = new int256[](ks.length);

        for (uint256 i = 0; i < ks.length; i++) {
            if (amount > rPools[js[i]].tokenABalance) continue;

            /*
            R_uni_indirect(buy_currency,k,buy_currency,time)=lag_R(buy_currency,k,buy_currency)-Buy*(1-fee_R(buy_currency,k));
            R_uni_indirect(buy_currency,k,k,time)=lag_R(buy_currency,k,buy_currency)*lag_R(buy_currency,k,k)/(lag_R(buy_currency,k,buy_currency)-Buy);
            */

            // int256 indirectTokenA = rPools[buy_k_poolIndex].tokenABalance -
            //     (amount - (rPools[buy_k_poolIndex].fee * amount) / 1 ether);

            int256 indirectTokenB = (rPools[ks[i]].tokenABalance *
                rPools[ks[i]].tokenBBalance) /
                (rPools[ks[i]].tokenABalance - amount);

            // emit Debug("indirectTokenA", indirectTokenA);
            // emit Debug("indirectTokenB", indirectTokenB);

            /*Sell=R_uni_indirect(buy_currency,k,k,time)-lag_R(buy_currency,k,k);*/

            int256 sell = indirectTokenB - rPools[ks[i]].tokenBBalance;

            /*
            /*R_uni_indirect(k,sell_currency,k,time)=lag_R(k,sell_currency,k)-Sell*(1- fee_R(k,sell_currency));
            */
            // int256 kSellTokenABalance = rPools[k_sell_poolIndex].tokenABalance -
            //     sell * (rPools[buy_k_poolIndex].fee * amount / 1 ether);

            // emit Debug("kSellTokenABalance", kSellTokenABalance);

            /*
            R_uni_indirect(k,sell_currency,sell_currency,time)=lag_R(k,sell_currency,k)*lag_R(k,sell_currency,sell_currency)/(lag_R(k,sell_currency,k)-Sell*(1+fee_R(k,sell_currency)));
            */
            int256 kSellTokenBBalance = (rPools[js[i]].tokenABalance *
                rPools[js[i]].tokenBBalance) /
                (rPools[js[i]].tokenABalance - sell);

            // emit Debug("kSellTokenBBalance", kSellTokenBBalance);

            /*
            Cost_uni_indirect_leg1(buy_currency,k,time)= ((R_uni_indirect(buy_currency,k,k,time)- lag_R(buy_currency,k,k))-

            Buy* lag_R(buy_currency,k,k)/ lag_R(buy_currency,k,buy_currency))/

            (Buy* lag_R(buy_currency,k,k)/ lag_R(buy_currency,k,buy_currency))+ lag_fee_R(buy_currency,k)
            */

            int256 leg1 = (((indirectTokenB - rPools[ks[i]].tokenBBalance) -
                (amount * rPools[ks[i]].tokenBBalance) /
                rPools[ks[i]].tokenABalance) * 1 ether) /
                ((amount * rPools[ks[i]].tokenBBalance) /
                    rPools[ks[i]].tokenABalance) +
                rPools[ks[i]].fee;

            // emit Debug("leg1", leg1);
            /*
            Cost_uni_indirect_leg2(k,sell_currency,time)= ((R_virtuswap(k,sell_currency,sell_currency,time)- lag_R(k,sell_currency,sell_currency))-

            Sell* lag_R(k,sell_currency,sell_currency)/ lag_R(k,sell_currency,k))/

            (Sell* lag_R(k,sell_currency,sell_currency)/ lag_R(k,sell_currency,k))+ lag_fee_R(k,sell_currency)
            */
            // emit Debug("amount", amount);
            // emit Debug("kSellTokenBBalance", kSellTokenBBalance);
            // emit Debug(
            //     "rPools[k_sell_poolIndex].tokenBBalance",
            //     rPools[k_sell_poolIndex].tokenBBalance
            // );
            // emit Debug(
            //     "rPools[k_sell_poolIndex].tokenABalance",
            //     rPools[k_sell_poolIndex].tokenABalance
            // );
            // emit Debug(
            //     "rPools[k_sell_poolIndex].fee",
            //     rPools[k_sell_poolIndex].fee
            // );

            // emit Debug("sell", sell);

            int256 leg2 = (((kSellTokenBBalance - rPools[js[i]].tokenBBalance) -
                (sell * rPools[js[i]].tokenBBalance) /
                rPools[js[i]].tokenABalance) * 1 ether) /
                ((sell * rPools[js[i]].tokenBBalance) /
                    rPools[js[i]].tokenABalance) +
                rPools[js[i]].fee;

            // emit Debug("leg2", leg2);

            // Cost_uni_indirect(buy_currency,sell_currency,time)= Cost_uni_indirect_leg1(buy_currency,k,time)+ Cost_uni_indirect_leg2(k,sell_currency,time)

            res[i] = leg1 + leg2;
            // emit Debug("res[i]", res[i]);
            i++;
        }

        //take min
        int256 minValue = res[0];
        for (uint256 j = 0; j < res.length; j++) {
            if (res[j] < minValue) {
                minValue = res[j];
            }
        }

        return minValue;
    }

    // function exchageReserves(Pool[] storage rPools, address[] memory tokens)
    //     public
    // {
    //     for (uint256 i = 0; i < rPools.length; i++) {
    //         for (uint256 k = 0; k < tokens.length; k++) {
    //             if (
    //                 rPools[i].tokenA == tokens[k] ||
    //                 rPools[i].tokenB == tokens[k]
    //             ) continue;

    //             //ij - rPools[i]

    //             //ik
    //             uint256 ikIndex = getPoolIndex(
    //                 rPools,
    //                 rPools[i].tokenA,
    //                 tokens[k]
    //             );

    //             //if (k~=i & k~=j & R(i,j,k)>0 & R(i,k,j)>0)
    //             if (
    //                 rPools[i].reserves[tokens[k]].reserveBalance > 0 &&
    //                 rPools[ikIndex].reserves[rPools[i].tokenB].reserveBalance >
    //                 0
    //             ) {
    //                 //lag_R(i,j,k)=R(i,j,k);
    //                 int256 lagRIJK = rPools[i]
    //                     .reserves[tokens[k]]
    //                     .reserveBalance;

    //                 //lag_R(i,k,j)=R(i,k,j);
    //                 int256 lagRIKJ = rPools[ikIndex]
    //                     .reserves[rPools[i].tokenB]
    //                     .reserveBalance;

    //                 //lag_R(i,j,j)=R(i,j,j);
    //                 int256 lagRIJI = rPools[i].tokenABalance;

    //                 //lag_R(i,j,j)=R(i,j,j);
    //                 int256 lagRIJJ = rPools[i].tokenBBalance;

    //                 //lag_R(i,k,k)=R(i,k,k);
    //                 int256 lagRIKK = rPools[ikIndex].tokenBBalance;

    //                 //lag_R(i,k,I)=R(i,k,k);
    //                 int256 lagRIKI = rPools[ikIndex].tokenABalance;

    //                 //R(i,j,k)=lag_R(i,j,k)-min(lag_R(i,j,k),lag_R(i,k,j)*lag_R(i,k,k)/lag_R(i,k,i)*lag_R(i,j,i)/lag_R(i,j,j));
    //                 rPools[i].reserves[tokens[k]].reserveBalance =
    //                     lagRIJK -
    //                     min(
    //                         lagRIJK,
    //                         ((((lagRIKJ * lagRIKK) / lagRIKI) * lagRIJI) /
    //                             lagRIJJ)
    //                     );

    //                 //R(i,k,j)=lag_R(i,k,j)-min(lag_R(i,k,j),lag_R(i,j,k)*lag_R(i,j,j)/lag_R(i,j,i)*lag_R(i,k,i)/lag_R(i,k,k));
    //                 rPools[ikIndex].reserves[rPools[i].tokenB].reserveBalance =
    //                     lagRIKJ -
    //                     min(
    //                         lagRIKJ,
    //                         ((((lagRIJK * lagRIJJ) / lagRIJI) * lagRIKI) /
    //                             lagRIKK)
    //                     );

    //                 //R(i,j,j)=lag_R(i,j,j)+lag_R(i,k,j)-R(i,k,j);
    //                 rPools[i].tokenBBalance =
    //                     lagRIJJ +
    //                     lagRIKJ -
    //                     rPools[ikIndex]
    //                         .reserves[rPools[i].tokenB]
    //                         .reserveBalance;

    //                 //R(i,k,k)=lag_R(i,k,k)+lag_R(i,j,k)-R(i,j,k);
    //                 rPools[ikIndex].tokenBBalance =
    //                     lagRIKK +
    //                     lagRIJK -
    //                     rPools[i].reserves[tokens[k]].reserveBalance;

    //                 uint256 jiIndex = getPoolIndex(
    //                     rPools,
    //                     rPools[i].tokenB,
    //                     rPools[i].tokenA
    //                 );
    //                 //R(j,i,k)=R(i,j,k);
    //                 rPools[jiIndex].reserves[tokens[k]].reserveBalance = rPools[
    //                     i
    //                 ].reserves[tokens[k]].reserveBalance;

    //                 uint256 kiIndex = getPoolIndex(
    //                     rPools,
    //                     tokens[k],
    //                     rPools[i].tokenA
    //                 );

    //                 //R(k,i,j)=R(i,k,j);
    //                 rPools[kiIndex]
    //                     .reserves[rPools[i].tokenB]
    //                     .reserveBalance = rPools[ikIndex]
    //                     .reserves[rPools[i].tokenB]
    //                     .reserveBalance;

    //                 //R(j,i,j)=R(i,j,j);
    //                 rPools[jiIndex].tokenABalance = rPools[i].tokenBBalance;

    //                 //R(k,i,k)=R(i,k,k);
    //                 rPools[kiIndex].tokenABalance = rPools[kiIndex]
    //                     .tokenBBalance;
    //             }
    //         }
    //     }
    // }

    //
}
