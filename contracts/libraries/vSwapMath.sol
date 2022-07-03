pragma solidity ^0.8.0;

import "../types.sol";
import "../ERC20/IERC20.sol";
import "../ERC20/ERC20.sol";
import "./Math.sol";
import "../interfaces/IvPair.sol";

library vSwapMath {
    uint256 constant EPSILON = 1 wei;

    //find common token and assign to ikToken1 and jkToken1
    function orderTokens(
        address tokenInput,
        address jkToken0,
        address jkToken1
    ) public pure returns (address, address) {
        return
            tokenInput == jkToken0
                ? (jkToken0, jkToken1)
                : (jkToken1, jkToken0);
    }

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

    function calculateVPool(
        uint256 ikTokenABalance,
        uint256 ikTokenBBalance,
        uint256 jkTokenABalance,
        uint256 jkTokenBBalance
    ) public pure returns (VirtualPoolModel memory vPool) {
        vPool.tokenABalance =
            (ikTokenABalance * Math.min(ikTokenBBalance, jkTokenBBalance)) /
            Math.max(ikTokenBBalance, EPSILON);

        vPool.tokenBBalance =
            (jkTokenABalance * Math.min(ikTokenBBalance, jkTokenBBalance)) /
            Math.max(jkTokenBBalance, EPSILON);
    }

    function getAmountIn(
        uint256 amountOut,
        uint256 reserveIn,
        uint256 reserveOut,
        uint256 fee,
        bool deductFees
    ) public pure returns (uint256 amountIn) {
        uint256 numerator = (reserveIn * amountOut) * 1000;
        uint256 denominator = (reserveOut - amountOut) *
            (deductFees ? fee : 1000);
        amountIn = (numerator / denominator) + 1;
    }

    function getAmountOut(
        uint256 amountIn,
        uint256 reserveIn,
        uint256 reserveOut,
        uint256 fee,
        bool deductFees
    ) public pure returns (uint256 amountOut) {
        uint256 amountInWithFee = amountIn * (deductFees ? fee : 1000);
        uint256 numerator = amountInWithFee * reserveOut;
        uint256 denominator = (reserveIn * 1000) + amountInWithFee;
        amountOut = numerator / denominator;
    }

    function SortedReservesBalances(
        address tokenIn,
        address baseToken,
        uint256 reserve0,
        uint256 reserve1
    ) public pure returns (PoolReserve memory reserves) {
        (uint256 _reserve0, uint256 _reserve1) = baseToken == tokenIn
            ? (reserve0, reserve1)
            : (reserve1, reserve0);
        reserves.reserve0 = _reserve0;
        reserves.reserve1 = _reserve1;
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
            ((token0Amount * totalSupply) / token0Balance) / (1 + reserveRatio);
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
}
