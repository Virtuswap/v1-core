// SPDX-License-Identifier: Apache-2.0

pragma solidity 0.8.18;

import '@openzeppelin/contracts/utils/math/Math.sol';
import '@openzeppelin/contracts/utils/math/SafeCast.sol';
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
    ) internal view returns (uint256) {
        // The function works if and only if the following constraints are
        // satisfied:
        //      1. all balances are positive and less than or equal to 10^32
        //      2. reserves are non-negative and less than or equal to 10^32
        //      3. 0 < vBalance1 <= balance0 (or balance1 depending on trade)
        //      4. priceFeeFactor == 10^3
        //      5. reserveRatioFactor == 10^5
        //      6. 0 < fee <= priceFeeFactor
        //      7. 0 < maxReserveRatio <= reserveRatioFactor
        //      8. reserveBaseValueSum <= 2 * balance0 * maxReserveRatio (see
        //          reserve ratio formula in vPair.calculateReserveRatio())
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
            IvPair(vPool.jkPair).reservesBaseValueSum() -
            IvPair(vPool.jkPair).reservesBaseValue(vPool.token0);

        require(
            params.balance0 > 0 && params.balance0 <= 10 ** 32,
            'invalid balance0'
        );
        require(
            params.balance1 > 0 && params.balance1 <= 10 ** 32,
            'invalid balance1'
        );
        require(
            params.vBalance0 > 0 && params.vBalance0 <= 10 ** 32,
            'invalid vBalance0'
        );
        require(
            params.vBalance1 > 0 && params.vBalance1 <= 10 ** 32,
            'invalid vBalance1'
        );
        require(params.priceFeeFactor == 10 ** 3, 'invalid priceFeeFactor');
        require(
            params.reserveRatioFactor == 10 ** 5,
            'invalid reserveRatioFactor'
        );
        require(
            params.fee > 0 && params.fee <= params.priceFeeFactor,
            'invalid fee'
        );
        require(
            params.maxReserveRatio > 0 &&
                params.maxReserveRatio <= params.reserveRatioFactor,
            'invalid maxReserveRatio'
        );

        // reserves are full, the answer is 0
        if (
            params.reservesBaseValueSum >
            2 * params.balance0 * params.maxReserveRatio
        ) return 0;

        int256 maxAmountIn;
        if (IvPair(vPool.jkPair).token0() == vPool.token1) {
            require(params.vBalance1 <= params.balance0, 'invalid vBalance1');
            unchecked {
                // a = R * v1 <= 10^5 * v1 = 10^5 * v1 <= 10^37
                uint256 a = params.vBalance1 * params.reserveRatioFactor;
                // b = v0 * (-2 * b0 * M + v1 * (2 * M + R * F / f) + R * s) + r * R * v1 <=
                //  <= v0 * (-2 * b0 * M + b0 * (2 * M + 10^8) + 10^5 * s) + 10^5 * r * v1 =
                //   = v0 * (10^8 * b0 + 10^5 * s) + 10^5 * r * v1 =
                //   = 10^5 * (v0 * (10^3 * b0 + s) + r * v1) <=
                //  <= 10^5 * (v0 * (10^3 * b0 + 2 * b0 * M) + r * v1) <=
                //  <= 10^5 * (v0 * (10^3 * b0 + 2 * 10^5 * b0) + r * v1) =
                //   = 10^5 * (v0 * b0 * (2 * 10^5 + 10^3) + r * v1) <=
                //  <= 10^5 * (10^64 * 2 * 10^5 + 10^64) <= 2 * 10^74
                int256 b = int256(params.vBalance0) *
                    (-2 *
                        int256(params.balance0 * params.maxReserveRatio) +
                        int256(
                            params.vBalance1 *
                                (2 *
                                    params.maxReserveRatio +
                                    (params.priceFeeFactor *
                                        params.reserveRatioFactor) /
                                    params.fee) +
                                params.reserveRatioFactor *
                                params.reservesBaseValueSum
                        )) +
                    int256(
                        params.reserves *
                            params.reserveRatioFactor *
                            params.vBalance1
                    );
                // we split C into c1 * c2 to fit in uint256
                // c1 = F * v0 / f <= 10^3 * v0 <= 10^35
                uint256 c1 = (params.priceFeeFactor * params.vBalance0) /
                    params.fee;
                // c2 = 2 * b0 * M * v0 - R * (r * v1 + s * v0) <=
                //   <= [r and s can be zero] <=
                //   <= 2 * 10^5 * b0 * v0 - 0 <= 2 * 10^69
                //
                // -c2 = R * (r * v1 + s * v0) - 2 * b0 * M * v0 <=
                //    <= 10^5 * (r * v1 + 2 * b0 * M * v0) - 2 * b0 * M * v0 =
                //     = 10^5 * r * v1 + 2 * b0 * M * v0 * (10^5 - 1) <=
                //    <= 10^5 * 10^32 * 10^32 + 2 * 10^32 * 10^5 * 10^32 * 10^5 <=
                //    <= 10^69 + 2 * 10^74 <= 2 * 10^74
                //
                // |c2| <= 2 * 10^74
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

                (bool negativeC, uint256 uc2) = (
                    c2 < 0 ? (false, uint256(-c2)) : (true, uint256(c2))
                );

                // according to Newton's method:
                // x_{n+1} = x_n - f(x_n) / f'(x_n) =
                //         = x_n - (Ax_n^2 + Bx_n + c1 * c2) / (2Ax_n + B) =
                //         = (2Ax_n^2 + Bx_n - Ax_n^2 - Bx_n - c1 * c2) / (2Ax_n + B) =
                //         = (Ax_n^2 - c1 * c2) / (2Ax_n + B) =
                //         = Ax_n^2 / (2Ax_n + B) - c1 * c2 / (2Ax_n + B)
                // initial approximation: maxAmountIn always <= vb0
                maxAmountIn = int256(params.vBalance0);
                // derivative = 2 * a * x + b =
                //    = 2 * R * f * v1 * x + v0 * (-2 * b0 * f * M + v1 * (2 * f * M + R * F) + f * R * s) + f * r * R * v1 <=
                //   <= 2 * 10^40 * 10^32 + 2 * 10^76 <= 2 * 10^76
                int256 derivative = int256(2 * a) * maxAmountIn + b;

                (bool negativeDerivative, uint256 uDerivative) = (
                    derivative < 0
                        ? (true, uint256(-derivative))
                        : (false, uint256(derivative))
                );

                // maxAmountIn * maxAmountIn <= vb0 * vb0 <= 10^64
                maxAmountIn = (
                    negativeC
                        ? SafeCast.toInt256(
                            Math.mulDiv(
                                a,
                                uint256(maxAmountIn * maxAmountIn),
                                uDerivative
                            )
                        ) + SafeCast.toInt256(Math.mulDiv(c1, uc2, uDerivative))
                        : SafeCast.toInt256(
                            Math.mulDiv(
                                a,
                                uint256(maxAmountIn * maxAmountIn),
                                uDerivative
                            )
                        ) - SafeCast.toInt256(Math.mulDiv(c1, uc2, uDerivative))
                );

                if (negativeDerivative) maxAmountIn = -maxAmountIn;

                derivative = int256(2 * a) * maxAmountIn + b;

                (negativeDerivative, uDerivative) = (
                    derivative < 0
                        ? (true, uint256(-derivative))
                        : (false, uint256(derivative))
                );

                maxAmountIn = (
                    negativeC
                        ? SafeCast.toInt256(
                            Math.mulDiv(
                                a,
                                uint256(maxAmountIn * maxAmountIn),
                                uDerivative
                            )
                        ) + SafeCast.toInt256(Math.mulDiv(c1, uc2, uDerivative))
                        : SafeCast.toInt256(
                            Math.mulDiv(
                                a,
                                uint256(maxAmountIn * maxAmountIn),
                                uDerivative
                            )
                        ) - SafeCast.toInt256(Math.mulDiv(c1, uc2, uDerivative))
                );

                if (negativeDerivative) maxAmountIn = -maxAmountIn;

                derivative = int256(2 * a) * maxAmountIn + b;

                (negativeDerivative, uDerivative) = (
                    derivative < 0
                        ? (true, uint256(-derivative))
                        : (false, uint256(derivative))
                );

                maxAmountIn = (
                    negativeC
                        ? SafeCast.toInt256(
                            Math.mulDiv(
                                a,
                                uint256(maxAmountIn * maxAmountIn),
                                uDerivative
                            )
                        ) + SafeCast.toInt256(Math.mulDiv(c1, uc2, uDerivative))
                        : SafeCast.toInt256(
                            Math.mulDiv(
                                a,
                                uint256(maxAmountIn * maxAmountIn),
                                uDerivative
                            )
                        ) - SafeCast.toInt256(Math.mulDiv(c1, uc2, uDerivative))
                );

                if (negativeDerivative) maxAmountIn = -maxAmountIn;

                derivative = int256(2 * a) * maxAmountIn + b;

                (negativeDerivative, uDerivative) = (
                    derivative < 0
                        ? (true, uint256(-derivative))
                        : (false, uint256(derivative))
                );

                maxAmountIn = (
                    negativeC
                        ? SafeCast.toInt256(
                            Math.mulDiv(
                                a,
                                uint256(maxAmountIn * maxAmountIn),
                                uDerivative
                            )
                        ) + SafeCast.toInt256(Math.mulDiv(c1, uc2, uDerivative))
                        : SafeCast.toInt256(
                            Math.mulDiv(
                                a,
                                uint256(maxAmountIn * maxAmountIn),
                                uDerivative
                            )
                        ) - SafeCast.toInt256(Math.mulDiv(c1, uc2, uDerivative))
                );

                if (negativeDerivative) maxAmountIn = -maxAmountIn;

                derivative = int256(2 * a) * maxAmountIn + b;

                (negativeDerivative, uDerivative) = (
                    derivative < 0
                        ? (true, uint256(-derivative))
                        : (false, uint256(derivative))
                );

                maxAmountIn = (
                    negativeC
                        ? SafeCast.toInt256(
                            Math.mulDiv(
                                a,
                                uint256(maxAmountIn * maxAmountIn),
                                uDerivative
                            )
                        ) + SafeCast.toInt256(Math.mulDiv(c1, uc2, uDerivative))
                        : SafeCast.toInt256(
                            Math.mulDiv(
                                a,
                                uint256(maxAmountIn * maxAmountIn),
                                uDerivative
                            )
                        ) - SafeCast.toInt256(Math.mulDiv(c1, uc2, uDerivative))
                );

                if (negativeDerivative) maxAmountIn = -maxAmountIn;

                derivative = int256(2 * a) * maxAmountIn + b;

                (negativeDerivative, uDerivative) = (
                    derivative < 0
                        ? (true, uint256(-derivative))
                        : (false, uint256(derivative))
                );

                maxAmountIn = (
                    negativeC
                        ? SafeCast.toInt256(
                            Math.mulDiv(
                                a,
                                uint256(maxAmountIn * maxAmountIn),
                                uDerivative
                            )
                        ) + SafeCast.toInt256(Math.mulDiv(c1, uc2, uDerivative))
                        : SafeCast.toInt256(
                            Math.mulDiv(
                                a,
                                uint256(maxAmountIn * maxAmountIn),
                                uDerivative
                            )
                        ) - SafeCast.toInt256(Math.mulDiv(c1, uc2, uDerivative))
                );

                if (negativeDerivative) maxAmountIn = -maxAmountIn;

                derivative = int256(2 * a) * maxAmountIn + b;

                (negativeDerivative, uDerivative) = (
                    derivative < 0
                        ? (true, uint256(-derivative))
                        : (false, uint256(derivative))
                );

                maxAmountIn = (
                    negativeC
                        ? SafeCast.toInt256(
                            Math.mulDiv(
                                a,
                                uint256(maxAmountIn * maxAmountIn),
                                uDerivative
                            )
                        ) + SafeCast.toInt256(Math.mulDiv(c1, uc2, uDerivative))
                        : SafeCast.toInt256(
                            Math.mulDiv(
                                a,
                                uint256(maxAmountIn * maxAmountIn),
                                uDerivative
                            )
                        ) - SafeCast.toInt256(Math.mulDiv(c1, uc2, uDerivative))
                );

                if (negativeDerivative) maxAmountIn = -maxAmountIn;
            }
        } else {
            unchecked {
                require(
                    params.vBalance1 <= params.balance1,
                    'invalid vBalance1'
                );
                maxAmountIn =
                    SafeCast.toInt256(
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
                        )
                    ) -
                    SafeCast.toInt256(params.reserves);
            }
        }
        assert(maxAmountIn >= 0);
        return uint256(maxAmountIn);
    }
}
