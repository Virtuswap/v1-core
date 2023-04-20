// SPDX-License-Identifier: Apache-2.0

pragma solidity 0.8.18;

import '@openzeppelin/contracts/utils/math/Math.sol';
import '../types.sol';
import '../interfaces/IvPair.sol';

library vSwapLibrary {
    uint24 internal constant PRICE_FEE_FACTOR = 10 ** 3;

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

    function calculateVPool(
        uint256 ikTokenABalance,
        uint256 ikTokenBBalance,
        uint256 jkTokenABalance,
        uint256 jkTokenBBalance
    ) internal pure returns (VirtualPoolModel memory vPool) {
        vPool.balance0 =
            (ikTokenABalance * Math.min(ikTokenBBalance, jkTokenBBalance)) /
            Math.max(ikTokenBBalance, 1);

        vPool.balance1 =
            (jkTokenABalance * Math.min(ikTokenBBalance, jkTokenBBalance)) /
            Math.max(jkTokenBBalance, 1);
    }

    function getAmountIn(
        uint256 amountOut,
        uint256 pairBalanceIn,
        uint256 pairBalanceOut,
        uint256 fee
    ) internal pure returns (uint256 amountIn) {
        uint256 numerator = (pairBalanceIn * amountOut) * PRICE_FEE_FACTOR;
        uint256 denominator = (pairBalanceOut - amountOut) * fee;
        amountIn = (numerator / denominator) + 1;
    }

    function getAmountOut(
        uint256 amountIn,
        uint256 pairBalanceIn,
        uint256 pairBalanceOut,
        uint256 fee
    ) internal pure returns (uint256 amountOut) {
        uint256 amountInWithFee = amountIn * fee;
        uint256 numerator = amountInWithFee * pairBalanceOut;
        uint256 denominator = (pairBalanceIn * PRICE_FEE_FACTOR) +
            amountInWithFee;
        amountOut = numerator / denominator;
    }

    function quote(
        uint256 amountA,
        uint256 balanceA,
        uint256 balanceB
    ) internal pure returns (uint256 amountB) {
        require(amountA > 0, 'VSWAP: INSUFFICIENT_AMOUNT');
        require(balanceA > 0 && balanceB > 0, 'VSWAP: INSUFFICIENT_LIQUIDITY');
        amountB = (amountA * balanceB) / balanceA;
    }

    function sortBalances(
        address tokenIn,
        address baseToken,
        uint256 pairBalance0,
        uint256 pairBalance1
    ) internal pure returns (uint256 _balance0, uint256 _balance1) {
        (_balance0, _balance1) = baseToken == tokenIn
            ? (pairBalance0, pairBalance1)
            : (pairBalance1, pairBalance0);
    }

    function getVirtualPool(
        address jkPair,
        address ikPair
    ) internal view returns (VirtualPoolModel memory vPool) {
        (address jk0, address jk1) = IvPair(jkPair).getTokens();
        (address ik0, address ik1) = IvPair(ikPair).getTokens();

        VirtualPoolTokens memory vPoolTokens = findCommonToken(
            ik0,
            ik1,
            jk0,
            jk1
        );

        require(
            (vPoolTokens.ik0 != vPoolTokens.jk0) &&
                (vPoolTokens.ik1 == vPoolTokens.jk1),
            'VSWAP: INVALID_VPOOL'
        );

        (uint256 ikBalance0, uint256 ikBalance1, ) = IvPair(ikPair)
            .getLastBalances();

        (uint256 jkBalance0, uint256 jkBalance1) = IvPair(jkPair).getBalances();

        vPool = calculateVPool(
            vPoolTokens.ik0 == ik0 ? ikBalance0 : ikBalance1,
            vPoolTokens.ik0 == ik0 ? ikBalance1 : ikBalance0,
            vPoolTokens.jk0 == jk0 ? jkBalance0 : jkBalance1,
            vPoolTokens.jk0 == jk0 ? jkBalance1 : jkBalance0
        );

        vPool.token0 = vPoolTokens.ik0;
        vPool.token1 = vPoolTokens.jk0;
        vPool.commonToken = vPoolTokens.ik1;

        require(IvPair(jkPair).allowListMap(vPool.token0), 'NA');

        vPool.fee = IvPair(jkPair).vFee();

        vPool.jkPair = jkPair;
        vPool.ikPair = ikPair;
    }

    /** @dev The function is used to calculate maximum virtual trade amount for
     * swapReserveToNative. The maximum amount that can be traded is such that
     * after the swap reserveRatio will be equal to maxReserveRatio:
     *
     * (reserveBaseValueSum + newReserveBaseValue(vPool.token0)) * reserveRatioFactor / (2 * balance0) = maxReserveRatio,
     * where balance0 is the balance of token0 after the swap (i.e. oldBalance0 + amountOut),
     *       reserveBaseValueSum is SUM(reserveBaseValue[i]) without reserveBaseValue(vPool.token0)
     *       newReserveBaseValue(vPool.token0) is reserveBaseValue(vPool.token0) after the swap
     *
     * amountOut can be expressed through amountIn:
     * amountOut = (amountIn * fee * vBalance1) / (amountIn * fee + vBalance0 * priceFeeFactor)
     *
     * reserveBaseValue(vPool.token0) can be expessed as:
     * if vPool.token1 == token0:
     *     reserveBaseValue(vPool.token0) = reserves[vPool.token0] * vBalance1 / vBalance0
     * else:
     *     reserveBaseValue(vPool.token0) = (reserves[vPool.token0] * vBalance1 * balance0) / (vBalance0 * balance1)
     *
     * Given all that we have two equations for finding maxAmountIn:
     * if vPool.token1 == token0:
     *     Ax^2 + Bx + C = 0,
     *     where A = fee * reserveRatioFactor * vBalance1,
     *           B = vBalance0 * (-2 * balance0 * fee * maxReserveRatio + vBalance1 *
     *              (2 * fee * maxReserveRatio + priceFeeFactor * reserveRatioFactor) +
     *              fee * reserveRatioFactor * reservesBaseValueSum) +
     *              fee * reserves * reserveRatioFactor * vBalance1,
     *           C = -priceFeeFactor * balance0 * (2 * balance0 * maxReserveRatio * vBalance0 -
     *              reserveRatioFactor * (reserves * vBalance1 + reservesBaseValueSum * vBalance0));
     * if vPool.token1 == token1:
     *     x = balance1 * vBalance0 * (2 * balance0 * maxReserveRatio - reserveRatioFactor * reservesBaseValueSum) /
     *          (balance0 * reserveRatioFactor * vBalance1)
     *
     * In the first case, we solve quadratic equation using Newton method.
     */
    function getMaxVirtualTradeAmountRtoN(
        VirtualPoolModel memory vPool
    ) internal view returns (uint256 maxAmountIn) {
        // never reverts if vPool is valid and balances <= 10^32
        MaxTradeAmountParams memory params;

        params.fee = uint256(vPool.fee);
        params.balance0 = IvPair(vPool.jkPair).pairBalance0();
        params.balance1 = IvPair(vPool.jkPair).pairBalance1();
        params.vBalance0 = vPool.balance0;
        params.vBalance1 = vPool.balance1;
        params.reserveRatioFactor = IvPair(vPool.jkPair).reserveRatioFactor();
        params.priceFeeFactor = uint256(PRICE_FEE_FACTOR);
        params.maxReserveRatio = IvPair(vPool.jkPair).maxReserveRatio();
        params.reserves = IvPair(vPool.jkPair).reserves(vPool.token0);
        params.reservesBaseValueSum =
            IvPair(vPool.jkPair).reservesBaseSum() -
            IvPair(vPool.jkPair).reservesBaseValue(vPool.token0);

        if (IvPair(vPool.jkPair).token0() == vPool.token1) {
            // all calculations fit in uint256
            unchecked {
                uint256 a = params.vBalance1 *
                    params.reserveRatioFactor *
                    params.fee;
                int256 b = int256(params.vBalance0) *
                    (-2 *
                        int256(
                            params.balance0 *
                                params.fee *
                                params.maxReserveRatio
                        ) +
                        int256(
                            params.vBalance1 *
                                (2 *
                                    params.fee *
                                    params.maxReserveRatio +
                                    params.priceFeeFactor *
                                    params.reserveRatioFactor) +
                                params.fee *
                                params.reserveRatioFactor *
                                params.reservesBaseValueSum
                        )) +
                    int256(
                        params.fee *
                            params.reserves *
                            params.reserveRatioFactor *
                            params.vBalance1
                    );
                // we split C into c1 * c2 to fit in uint256
                uint256 c1 = params.priceFeeFactor * params.vBalance0;
                int256 c2 = 2 *
                    int256(
                        params.balance0 *
                            params.maxReserveRatio *
                            params.vBalance0
                    ) -
                    int256(
                        params.reserveRatioFactor *
                            (params.reserves *
                                params.vBalance1 +
                                params.reservesBaseValueSum *
                                params.vBalance0)
                    );

                (bool negativeB, uint256 ub) = (
                    b < 0 ? (true, uint256(-b)) : (false, uint256(b))
                );

                (bool negativeC, uint256 uc2) = (
                    c2 < 0 ? (false, uint256(-c2)) : (true, uint256(c2))
                );

                // initial approximation: maxAmountIn always <= vb0
                maxAmountIn = params.vBalance0;
                // 2 * a * x + b <= 5 * 10^75 < 2^256
                uint256 temp = (
                    negativeB ? (a * maxAmountIn - ub) : (a * maxAmountIn + ub)
                );
                uint256 derivative = temp + a * maxAmountIn;
                if (negativeC) {
                    maxAmountIn =
                        maxAmountIn +
                        Math.mulDiv(c1, uc2, derivative) -
                        Math.mulDiv(maxAmountIn, temp, derivative);
                } else {
                    maxAmountIn -=
                        Math.mulDiv(c1, uc2, derivative) +
                        Math.mulDiv(maxAmountIn, temp, derivative);
                }

                temp = (
                    negativeB ? (a * maxAmountIn - ub) : (a * maxAmountIn + ub)
                );
                derivative = temp + a * maxAmountIn;
                if (negativeC) {
                    maxAmountIn =
                        maxAmountIn +
                        Math.mulDiv(c1, uc2, derivative) -
                        Math.mulDiv(maxAmountIn, temp, derivative);
                } else {
                    maxAmountIn -=
                        Math.mulDiv(c1, uc2, derivative) +
                        Math.mulDiv(maxAmountIn, temp, derivative);
                }

                temp = (
                    negativeB ? (a * maxAmountIn - ub) : (a * maxAmountIn + ub)
                );
                derivative = temp + a * maxAmountIn;
                if (negativeC) {
                    maxAmountIn =
                        maxAmountIn +
                        Math.mulDiv(c1, uc2, derivative) -
                        Math.mulDiv(maxAmountIn, temp, derivative);
                } else {
                    maxAmountIn -=
                        Math.mulDiv(c1, uc2, derivative) +
                        Math.mulDiv(maxAmountIn, temp, derivative);
                }

                temp = (
                    negativeB ? (a * maxAmountIn - ub) : (a * maxAmountIn + ub)
                );
                derivative = temp + a * maxAmountIn;
                if (negativeC) {
                    maxAmountIn =
                        maxAmountIn +
                        Math.mulDiv(c1, uc2, derivative) -
                        Math.mulDiv(maxAmountIn, temp, derivative);
                } else {
                    maxAmountIn -=
                        Math.mulDiv(c1, uc2, derivative) +
                        Math.mulDiv(maxAmountIn, temp, derivative);
                }

                temp = (
                    negativeB ? (a * maxAmountIn - ub) : (a * maxAmountIn + ub)
                );
                derivative = temp + a * maxAmountIn;
                if (negativeC) {
                    maxAmountIn =
                        maxAmountIn +
                        Math.mulDiv(c1, uc2, derivative) -
                        Math.mulDiv(maxAmountIn, temp, derivative);
                } else {
                    maxAmountIn -=
                        Math.mulDiv(c1, uc2, derivative) +
                        Math.mulDiv(maxAmountIn, temp, derivative);
                }

                temp = (
                    negativeB ? (a * maxAmountIn - ub) : (a * maxAmountIn + ub)
                );
                derivative = temp + a * maxAmountIn;
                if (negativeC) {
                    maxAmountIn =
                        maxAmountIn +
                        Math.mulDiv(c1, uc2, derivative) -
                        Math.mulDiv(maxAmountIn, temp, derivative);
                } else {
                    maxAmountIn -=
                        Math.mulDiv(c1, uc2, derivative) +
                        Math.mulDiv(maxAmountIn, temp, derivative);
                }

                temp = (
                    negativeB ? (a * maxAmountIn - ub) : (a * maxAmountIn + ub)
                );
                derivative = temp + a * maxAmountIn;
                if (negativeC) {
                    maxAmountIn =
                        maxAmountIn +
                        Math.mulDiv(c1, uc2, derivative) -
                        Math.mulDiv(maxAmountIn, temp, derivative);
                } else {
                    maxAmountIn -=
                        Math.mulDiv(c1, uc2, derivative) +
                        Math.mulDiv(maxAmountIn, temp, derivative);
                }
            }
        } else {
            unchecked {
                maxAmountIn =
                    Math.mulDiv(
                        params.balance1 * params.vBalance0,
                        2 *
                            params.balance0 *
                            params.maxReserveRatio -
                            params.reserveRatioFactor *
                            params.reservesBaseValueSum,
                        params.balance0 *
                            params.reserveRatioFactor *
                            params.vBalance1
                    ) -
                    params.reserves;
            }
        }
    }
}
