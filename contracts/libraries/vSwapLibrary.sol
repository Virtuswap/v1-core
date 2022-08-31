pragma solidity 0.8.2;

import "@openzeppelin/contracts/utils/math/Math.sol";
import "../types.sol";
import "../interfaces/IvPair.sol";

library vSwapLibrary {
    uint24 internal constant PRICE_FEE_FACTOR = 10**3;

    //find common token and assign to ikToken1 and jkToken1
    function findCommonToken(
        address ikToken0,
        address ikToken1,
        address jkToken0,
        address jkToken1
    ) internal pure returns (VirtualPoolTokens memory vPoolTokens) {
        (
            vPoolTokens.ik0,
            vPoolTokens.ik1,
            vPoolTokens.jk0,
            vPoolTokens.jk1
        ) = (ikToken0 == jkToken0)
            ? (ikToken1, ikToken0, jkToken1, jkToken0)
            : (ikToken0 == jkToken1)
            ? (ikToken1, ikToken0, jkToken0, jkToken1)
            : (ikToken1 == jkToken0)
            ? (ikToken0, ikToken1, jkToken1, jkToken0)
            : (ikToken0, ikToken1, jkToken0, jkToken1); //default
    }

    function percent(uint256 numerator, uint256 denominator)
        internal
        pure
        returns (uint256 quotient)
    {
        // caution, check safe-to-multiply here
        uint256 _numerator = numerator * 10**(18 + 1);
        // with rounding of last digit
        uint256 _quotient = ((_numerator / denominator) + 5) / 10;
        return (_quotient);
    }

    function calculateVPool(
        uint256 ikTokenABalance,
        uint256 ikTokenBBalance,
        uint256 jkTokenABalance,
        uint256 jkTokenBBalance
    ) internal pure returns (VirtualPoolModel memory vPool) {
        vPool.reserve0 =
            (ikTokenABalance * Math.min(ikTokenBBalance, jkTokenBBalance)) /
            Math.max(ikTokenBBalance, 1);

        vPool.reserve1 =
            (jkTokenABalance * Math.min(ikTokenBBalance, jkTokenBBalance)) /
            Math.max(jkTokenBBalance, 1);
    }

    function getAmountIn(
        uint256 amountOut,
        uint256 reserveIn,
        uint256 reserveOut,
        uint256 fee
    ) internal pure returns (uint256 amountIn) {
        uint256 numerator = (reserveIn * amountOut) * PRICE_FEE_FACTOR;
        uint256 denominator = (reserveOut - amountOut) * fee;
        amountIn = (numerator / denominator) + 1;
    }

    function getAmountOut(
        uint256 amountIn,
        uint256 reserveIn,
        uint256 reserveOut,
        uint256 fee
    ) internal pure returns (uint256 amountOut) {
        uint256 amountInWithFee = amountIn * fee;
        uint256 numerator = amountInWithFee * reserveOut;
        uint256 denominator = (reserveIn * PRICE_FEE_FACTOR) + amountInWithFee;
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

    function sortReserves(
        address tokenIn,
        address baseToken,
        uint256 reserve0,
        uint256 reserve1
    ) internal pure returns (uint256 _reserve0, uint256 _reserve1) {
        (_reserve0, _reserve1) = baseToken == tokenIn
            ? (reserve0, reserve1)
            : (reserve1, reserve0);
    }

    function getVirtualPoolBase(
        address jkToken0,
        address jkToken1,
        uint256 jkReserve0,
        uint256 jkReserve1,
        uint24 jkvFee,
        address ikPair
    ) internal view returns (VirtualPoolModel memory vPool) {
        (address ik0, address ik1) = IvPair(ikPair).getTokens();
        (address jk0, address jk1) = (jkToken0, jkToken1); //gas saving

        VirtualPoolTokens memory vPoolTokens = findCommonToken(
            ik0,
            ik1,
            jk0,
            jk1
        );

        require(vPoolTokens.ik1 == vPoolTokens.jk1, "IOP");

        (uint256 ikReserve0, uint256 ikReserve1, ) = IvPair(ikPair)
            .getLastReserves();

        (uint256 _reserve0, uint256 _reserve1) = (jkReserve0, jkReserve1); //gas saving

        vPool = calculateVPool(
            vPoolTokens.ik0 == ik0 ? ikReserve0 : ikReserve1,
            vPoolTokens.ik0 == ik0 ? ikReserve1 : ikReserve0,
            vPoolTokens.jk0 == jk0 ? _reserve0 : _reserve1,
            vPoolTokens.jk0 == jk0 ? _reserve1 : _reserve0
        );

        vPool.token0 = vPoolTokens.ik0;
        vPool.token1 = vPoolTokens.jk0;
        vPool.commonToken = vPoolTokens.ik1;

        vPool.fee = jkvFee;
    }

    function getVirtualPool(address jkPair, address ikPair)
        internal
        view
        returns (VirtualPoolModel memory vPool)
    {
        (address jk0, address jk1) = IvPair(jkPair).getTokens();
        (uint256 _reserve0, uint256 _reserve1) = IvPair(jkPair).getReserves();
        uint24 vFee = IvPair(jkPair).vFee();

        vPool = getVirtualPoolBase(
            jk0,
            jk1,
            _reserve0,
            _reserve1,
            vFee,
            ikPair
        );
    }
}
