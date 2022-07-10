pragma solidity =0.8.1;

import "@openzeppelin/contracts/utils/math/Math.sol";
import "../types.sol";

library vSwapMath {
    uint256 constant EPSILON = 1 wei;
    uint256 private constant RESERVE_RATIO_FACTOR = 1000;

    //find common token and assign to ikToken1 and jkToken1
    function findCommonToken(
        address ikToken0,
        address ikToken1,
        address jkToken0,
        address jkToken1
    ) public pure returns (VirtualPoolTokens memory vPoolTokens) {
        (
            address _ikToken0,
            address _ikToken1,
            address _jkToken0,
            address _jkToken1
        ) = (ikToken0 == jkToken0)
                ? (ikToken1, ikToken0, jkToken1, jkToken0)
                : (ikToken0 == jkToken1)
                ? (ikToken1, ikToken0, jkToken0, jkToken1)
                : (ikToken1 == jkToken0)
                ? (ikToken0, ikToken1, jkToken1, jkToken0)
                : (ikToken0, ikToken1, jkToken0, jkToken1); //default

        vPoolTokens.ik0 = _ikToken0;
        vPoolTokens.ik1 = _ikToken1;
        vPoolTokens.jk0 = _jkToken0;
        vPoolTokens.jk1 = _jkToken1;
    }

    function calculateReserveRatio(
        uint256 rRatio,
        uint256 _rReserve,
        uint256 _baseReserve
    ) public pure returns (uint256) {
        return
            rRatio +
            (_rReserve * 100 * RESERVE_RATIO_FACTOR) /
            (_baseReserve * 2);
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
        uint256 fee
    ) public pure returns (uint256 amountIn) {
        uint256 numerator = (reserveIn * amountOut) * 1000;
        uint256 denominator = (reserveOut - amountOut) * fee;
        amountIn = (numerator / denominator) + 1;
    }

    function getAmountOut(
        uint256 amountIn,
        uint256 reserveIn,
        uint256 reserveOut,
        uint256 fee
    ) public pure returns (uint256 amountOut) {
        uint256 amountInWithFee = amountIn * fee;
        uint256 numerator = amountInWithFee * reserveOut;
        uint256 denominator = (reserveIn * 1000) + amountInWithFee;
        amountOut = numerator / denominator;
    }

    function quote(
        uint256 amountA,
        uint256 reserveA,
        uint256 reserveB
    ) internal pure returns (uint256 amountB) {
        require(amountA > 0, "VSWAP: INSUFFICIENT_AMOUNT");
        require(reserveA > 0 && reserveB > 0, "VSWAP: INSUFFICIENT_LIQUIDITY");
        amountB = (amountA * reserveB) / reserveA;
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

    function deductReserveRatioFromLP(uint256 _liquidity, uint256 _reserveRatio)
        public
        pure
        returns (uint256 lpAmount)
    {
        uint256 multiplier = (RESERVE_RATIO_FACTOR -
            (_reserveRatio / RESERVE_RATIO_FACTOR));
        lpAmount = (_liquidity * multiplier) / RESERVE_RATIO_FACTOR;
    }
}
