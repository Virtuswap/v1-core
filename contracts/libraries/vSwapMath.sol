pragma solidity ^0.8.0;

import "../types.sol";
import "../ERC20/IERC20.sol";
import "../ERC20/ERC20.sol";
import "./Math.sol";
import "../interfaces/IvPair.sol";

library vSwapMath {
    uint256 constant EPSILON = 1 wei;
    uint256 constant MULTIPLIER = 100000;

    uint256 public constant MAX_INT =
        0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff;

    //find common token and assign to ikToken1 and jkToken1
    function findCommonToken(
        address ikToken0,
        address ikToken1,
        address jkToken0,
        address jkToken1
    )
        public
        pure
        returns (
            address,
            address,
            address,
            address
        )
    {
        return
            (ikToken0 == jkToken0)
                ? (ikToken1, ikToken0, jkToken1, jkToken0)
                : (ikToken0 == jkToken1)
                ? (ikToken1, ikToken0, jkToken0, jkToken1)
                : (ikToken1 == jkToken0)
                ? (ikToken0, ikToken1, jkToken1, jkToken0)
                : (ikToken0, ikToken1, jkToken0, jkToken1); //default
    }

    function calculateWeightedAmount(
        uint256 amount,
        uint256 nominator,
        uint256 denominator
    ) public pure returns (uint256) {
        return
            (amount * (((nominator * MULTIPLIER) / denominator))) / MULTIPLIER;
    }

    // function calculateVirtualPoolBalance(
    //     uint256 belowReserveIK,
    //     uint256 ikPairTokenABalance,
    //     uint256 ikPairTokenBBalance,
    //     uint256 jkPairTokenBBalance
    // ) public pure returns (uint256) {
    //     //  V(i,j,i)=V(i,j,i)+ind_below_reserve_threshold(i,k)*R(i,k,i)*min(R(i,k,k),R(j,k,k))/max(R(i,k,k),epsilon);
    //     return
    //         (belowReserveIK *
    //             ikPairTokenABalance *
    //             Math.min(ikPairTokenBBalance, jkPairTokenBBalance)) /
    //         Math.max(ikPairTokenBBalance, EPSILON);
    // }

    function concatenateArrays(address[] memory arr1, address[] memory arr2)
        public
        pure
        returns (address[] memory)
    {
        address[] memory returnArr = new address[](arr1.length + arr2.length);

        uint256 i = 0;
        for (; i < arr1.length; i++) {
            returnArr[i] = arr1[i];
        }

        uint256 j = 0;
        while (j < arr1.length) {
            returnArr[i++] = arr2[j++];
        }

        return returnArr;
    }

    function quote(
        VirtualPoolModel memory tPool,
        uint256 amount,
        bool calculateFees
    ) public pure returns (uint256) {
        // T(buy_currency,sell_currency,sell_currency)=lag_T(buy_currency,sell_currency,buy_currency)*lag_T(buy_currency,sell_currency,sell_currency)/(lag_T(buy_currency,sell_currency,buy_currency)-Buy); // %calculate amount_out
        uint256 totalOut = ((tPool.tokenABalance * tPool.tokenBBalance) /
            (tPool.tokenABalance - amount)) - tPool.tokenBBalance;

        if (calculateFees)
            totalOut = (totalOut - ((tPool.fee * totalOut) / 1 ether));

        return totalOut;
    }

    function quote(
        uint256 tokenABalance,
        uint256 tokenBBalance,
        uint256 fee,
        uint256 amount,
        bool calculateFees
    ) public pure returns (uint256 totalOut) {
        // T(buy_currency,sell_currency,sell_currency)=lag_T(buy_currency,sell_currency,buy_currency)*lag_T(buy_currency,sell_currency,sell_currency)/(lag_T(buy_currency,sell_currency,buy_currency)-Buy); // %calculate amount_out
        totalOut =
            ((tokenABalance * tokenBBalance) / (tokenABalance - amount)) -
            tokenBBalance;

        if (calculateFees) totalOut = (totalOut - ((fee * totalOut) / 1 ether));
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

        return
            ((token0Amount * totalSupply) / token0Balance) * (1 + reserveRatio);
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

    function calculateVirtualPoolBalance(
        uint256 vPoolTokenBalance,
        uint256 belowReserve,
        uint256 ikF,
        uint256 ikS,
        uint256 jsF
    ) public pure returns (uint256) {
        return
            vPoolTokenBalance +
            (belowReserve * ikF * Math.min(ikS, jsF)) /
            Math.max(ikS, EPSILON);
    }

    function totalPoolFeeAvg(
        uint256 vPairFee,
        uint256 vPairTokenABalance,
        uint256 vPoolFee,
        uint256 vPoolTokenABalance
    ) public pure returns (uint256) {
        return
            (vPairFee * vPairTokenABalance + vPoolFee * vPoolTokenABalance) /
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
