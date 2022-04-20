import "./Types256.sol";
import "./ERC20/IERC20.sol";
import "./ERC20/ERC20.sol";
import "./vPair.sol";

library vPoolCalculations {
    function sumVirtualPoolsArray(VirtualPool[] memory vPools)
        public
        view
        returns (uint256)
    {
        uint256 sum = 0;
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
        uint256 epsilon = 1 wei;

        VirtualPool memory vPool;
        vPool.fee = 0.003 ether;

        vPool.tokenA = vPair(ks[0]).tokenA();
        vPool.tokenB = vPair(js[0]).tokenB();

        for (uint256 i = 0; i < ks.length; i++) {
            address ikIndex = ks[i];
            address jkIndex = js[i];

            uint256 belowReserveIK = vPair(ikIndex).getBelowReserve();
            uint256 belowReserveJK = vPair(jkIndex).getBelowReserve();

            uint256 ikIndexTokenABalance = IERC20(vPair(ikIndex).tokenA())
                .balanceOf(ikIndex);

            uint256 ikIndexTokenBBalance = IERC20(vPair(ikIndex).tokenB())
                .balanceOf(ikIndex);

            uint256 jkIndexTokenABalance = IERC20(vPair(jkIndex).tokenA())
                .balanceOf(ikIndex);

            uint256 jkIndexTokenBBalance = IERC20(vPair(jkIndex).tokenB())
                .balanceOf(ikIndex);

            //  V(i,j,i)=V(i,j,i)+ind_below_reserve_threshold(i,k)*R(i,k,i)*min(R(i,k,k),R(j,k,k))/max(R(i,k,k),epsilon);
            vPool.tokenABalance =
                vPool.tokenABalance +
                (belowReserveIK *
                    ikIndexTokenABalance *
                    Math.min(ikIndexTokenBBalance, jkIndexTokenBBalance)) /
                Math.min(ikIndexTokenBBalance, epsilon);

            //  V(i,j,j)=V(i,j,j)+ind_below_reserve_threshold(i,k)*R(j,k,j)*min(R(i,k,k),R(j,k,k))/max(R(j,k,k),epsilon);
            vPool.tokenBBalance =
                vPool.tokenBBalance +
                (belowReserveJK *
                    jkIndexTokenABalance *
                    Math.min(ikIndexTokenBBalance, jkIndexTokenBBalance)) /
                Math.min(jkIndexTokenBBalance, epsilon);
        }

        return vPool;
    }

    function getTotalPool(Pool[] storage rPools, VirtualPool memory vPool)
        public
        view
        returns (VirtualPool memory)
    {
        VirtualPool memory tPool = vPool;

        uint256 rPoolTokenABalance = 0;
        uint256 rPoolTokenBBalance = 0;
        uint256 rPoolFee = 0;

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
        uint256 amount
    ) public view returns (uint256) {
        uint256 lagTTokenABalance = tPool.tokenABalance;
        uint256 lagTTokenBBalance = tPool.tokenBBalance;

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

        uint256 finalQuote = tPool.tokenBBalance - lagTTokenBBalance;

        return finalQuote;
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
