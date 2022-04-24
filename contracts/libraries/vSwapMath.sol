pragma solidity >=0.4.22 <0.9.0;

import "../types.sol";
import "../ERC20/IERC20.sol";
import "../ERC20/ERC20.sol";
import "./Math.sol";
import "../interfaces/IvPair.sol";

library vSwapMath {
    uint256 constant EPSILON = 1 wei;

    function calculateVirtualPool(address[] memory ks, address[] memory js)
        public
        view
        returns (VirtualPool memory vPool)
    {
       vPool.fee = 0.003 ether;

        for (uint256 i = 0; i < ks.length; i++) {
            uint256 belowReserveIK = IvPair(ks[i]).getBelowReserve();
            uint256 belowReserveJK = IvPair(js[i]).getBelowReserve();

            uint256 ikPairTokenABalance = IERC20(IvPair(ks[i]).token0())
                .balanceOf(ks[i]);

            // emit DebugA("ks[i]", ks[i], 0);
            // emit DebugA("js[i]", js[i], 0);

            // emit Debug("ikPairTokenABalance", ikPairTokenABalance);

            uint256 ikPairTokenBBalance = IERC20(IvPair(ks[i]).token1())
                .balanceOf(ks[i]);

            // emit Debug("ikPairTokenBBalance", ikPairTokenBBalance);

            uint256 jkPairTokenABalance = IERC20(IvPair(js[i]).token0())
                .balanceOf(js[i]);

            // emit Debug("jkPairTokenABalance", jkPairTokenABalance);

            uint256 jkPairTokenBBalance = IERC20(IvPair(js[i]).token1())
                .balanceOf(js[i]);

            // emit Debug("jkPairTokenBBalance", jkPairTokenBBalance);

            //  V(i,j,i)=V(i,j,i)+ind_below_reserve_threshold(i,k)*R(i,k,i)*min(R(i,k,k),R(j,k,k))/max(R(i,k,k),epsilon);
            vPool.tokenABalance =
                vPool.tokenABalance +
                (belowReserveIK *
                    ikPairTokenABalance *
                    Math.min(ikPairTokenBBalance, jkPairTokenBBalance)) /
                Math.max(ikPairTokenBBalance, EPSILON);

            //  V(i,j,j)=V(i,j,j)+ind_below_reserve_threshold(i,k)*R(j,k,j)*min(R(i,k,k),R(j,k,k))/max(R(j,k,k),epsilon);
            vPool.tokenBBalance =
                vPool.tokenBBalance +
                (belowReserveJK *
                    jkPairTokenABalance *
                    Math.min(ikPairTokenBBalance, jkPairTokenBBalance)) /
                Math.max(jkPairTokenBBalance, EPSILON);
        }

        return vPool;
    }

    function quote(VirtualPool memory tPool, uint256 amount)
        public
        pure
        returns (uint256)
    {
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

    function calculateLPTokensAmount(
        uint256 token0Amount,
        uint256 totalSupply,
        uint256 token0Balance,
        uint256 reserveRatio
    ) public pure returns (uint256) {
        /* t(add_currency_base,add_currency_quote,LP)=
                lag_t(add_currency_base,add_currency_quote,LP)+Add*
                sum(lag_t(add_currency_base,add_currency_quote,:))/
                (lag_R(add_currency_base,add_currency_quote,add_currency_base)*
                (1+reserve_ratio(add_currency_base,add_currency_quote)));*/

        uint256 lpAmount = ((token0Amount * totalSupply) / token0Balance) *
            (1 + reserveRatio);

        return lpAmount;
    }

    function calculateReserveRatio(
        uint256 reserveBalance,
        uint256 ikTokenABalance,
        uint256 ikTokenBBalance,
        uint256 jkTokenABalance,
        uint256 jkTokenBBalance,
        uint256 ijtokenABalance,
        uint256 ijtokenBBalance
    ) public pure returns (uint256) {
        return
            (reserveBalance *
                Math.max(
                    (ikTokenABalance / Math.max(ikTokenBBalance, EPSILON)),
                    (((jkTokenABalance / Math.max(jkTokenBBalance, EPSILON)) *
                        ijtokenABalance) / Math.max(ijtokenBBalance, EPSILON))
                )) / (2 * Math.max(ijtokenABalance, EPSILON));
    }

    function getTotalPool(VirtualPool memory vPool, address vPairAddress)
        public
        view
        returns (VirtualPool memory)
    {
        VirtualPool memory tPool = vPool;

        uint256 rPoolTokenABalance = 0;
        uint256 rPoolTokenBBalance = 0;
        uint256 rPoolFee = 0;

        if (vPairAddress != address(0)) {
            rPoolTokenABalance = IERC20(IvPair(vPairAddress).token0())
                .balanceOf(vPairAddress);

            rPoolTokenBBalance = IERC20(IvPair(vPairAddress).token1())
                .balanceOf(vPairAddress);

            rPoolFee = IvPair(vPairAddress).fee();
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
}
