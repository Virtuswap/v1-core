pragma solidity >=0.4.22 <0.9.0;

import "../types.sol";
import "../ERC20/IERC20.sol";
import "../ERC20/ERC20.sol";
import "./Math.sol";
import "../interfaces/IvPair.sol";

library vSwapMath {
    uint256 constant EPSILON = 1 wei;

    function calculateVirtualPoolBalance(
        uint256 belowReserveIK,
        uint256 ikPairTokenABalance,
        uint256 ikPairTokenBBalance,
        uint256 jkPairTokenBBalance
    ) public pure returns (uint256) {

        //  V(i,j,i)=V(i,j,i)+ind_below_reserve_threshold(i,k)*R(i,k,i)*min(R(i,k,k),R(j,k,k))/max(R(i,k,k),epsilon);
        return
            (belowReserveIK *
                ikPairTokenABalance *
                Math.min(ikPairTokenBBalance, jkPairTokenBBalance)) /
            Math.max(ikPairTokenBBalance, EPSILON);
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

    function totalPoolFeeAvg(
        uint256 rPoolFee,
        uint256 rPoolTokenABalance,
        uint256 vPoolFee,
        uint256 vPoolTokenABalance
    ) public pure returns (uint256) {
        return
            (rPoolFee * rPoolTokenABalance + vPoolFee * vPoolTokenABalance) /
            vPoolTokenABalance;
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
