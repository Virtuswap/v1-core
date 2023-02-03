// SPDX-License-Identifier: Apache-2.0

pragma solidity 0.8.2;

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

    function getVirtualPoolBase(
        address jkToken0,
        address jkToken1,
        uint256 jkBalance0,
        uint256 jkBalance1,
        uint24 jkvFee,
        address ikPair
    ) internal view returns (VirtualPoolModel memory vPool) {}

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

        (uint256 jkBalance0, uint256 jkBalance1, ) = IvPair(jkPair)
            .getLastBalances();

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

    function getMaxVirtualTradeAmountRtoN(
        VirtualPoolModel memory vPool
    ) internal view returns (uint256 maxAmountIn) {
        // never reverts if vPool is valid and balances <= 10^32
        MaxTradeAmountParams memory params;

        params.f = uint256(vPool.fee);
        params.b0 = IvPair(vPool.jkPair).pairBalance0();
        params.b1 = IvPair(vPool.jkPair).pairBalance1();
        params.vb0 = vPool.balance0;
        params.vb1 = vPool.balance1;
        params.R = IvPair(vPool.jkPair).reserveRatioFactor();
        params.F = uint256(PRICE_FEE_FACTOR);
        params.T = IvPair(vPool.jkPair).maxReserveRatio();
        params.r = IvPair(vPool.jkPair).reserves(vPool.token0);
        params.s =
            IvPair(vPool.jkPair).reservesBaseSum() -
            IvPair(vPool.jkPair).reservesBaseValue(vPool.token0);

        if (IvPair(vPool.jkPair).token0() == vPool.token1) {
            // all calculations fit in uint256
            unchecked {
                uint256 a = params.vb1 * params.R * params.f;
                int256 b = int256(params.vb0) *
                    (-2 *
                        int256(params.b0 * params.f * params.T) +
                        int256(
                            params.vb1 *
                                (2 *
                                    params.f *
                                    params.T +
                                    params.F *
                                    params.R) +
                                params.f *
                                params.R *
                                params.s
                        )) +
                    int256(params.f * params.r * params.R * params.vb1);
                uint256 c1 = params.F * params.vb0;
                uint256 c2 = 2 *
                    params.b0 *
                    params.T *
                    params.vb0 -
                    params.R *
                    (params.r * params.vb1 + params.s * params.vb0);

                (bool negative, uint256 ub) = (
                    b < 0 ? (true, uint256(-b)) : (false, uint256(b))
                );

                // initial approximation: maxAmountIn always <= vb0
                maxAmountIn = params.vb0;
                // 2 * a * x + b <= 5 * 10^75 < 2^256
                uint256 temp = (
                    negative ? (a * maxAmountIn - ub) : (a * maxAmountIn + ub)
                );
                uint256 derivative = temp + a * maxAmountIn;
                maxAmountIn +=
                    Math.mulDiv(c1, c2, derivative) -
                    Math.mulDiv(maxAmountIn, temp, derivative);

                temp = (
                    negative ? (a * maxAmountIn - ub) : (a * maxAmountIn + ub)
                );
                derivative = temp + a * maxAmountIn;
                maxAmountIn +=
                    Math.mulDiv(c1, c2, derivative) -
                    Math.mulDiv(maxAmountIn, temp, derivative);

                temp = (
                    negative ? (a * maxAmountIn - ub) : (a * maxAmountIn + ub)
                );
                derivative = temp + a * maxAmountIn;
                maxAmountIn +=
                    Math.mulDiv(c1, c2, derivative) -
                    Math.mulDiv(maxAmountIn, temp, derivative);

                temp = (
                    negative ? (a * maxAmountIn - ub) : (a * maxAmountIn + ub)
                );
                derivative = temp + a * maxAmountIn;
                maxAmountIn +=
                    Math.mulDiv(c1, c2, derivative) -
                    Math.mulDiv(maxAmountIn, temp, derivative);

                temp = (
                    negative ? (a * maxAmountIn - ub) : (a * maxAmountIn + ub)
                );
                derivative = temp + a * maxAmountIn;
                maxAmountIn +=
                    Math.mulDiv(c1, c2, derivative) -
                    Math.mulDiv(maxAmountIn, temp, derivative);

                temp = (
                    negative ? (a * maxAmountIn - ub) : (a * maxAmountIn + ub)
                );
                derivative = temp + a * maxAmountIn;
                maxAmountIn +=
                    Math.mulDiv(c1, c2, derivative) -
                    Math.mulDiv(maxAmountIn, temp, derivative);

                temp = (
                    negative ? (a * maxAmountIn - ub) : (a * maxAmountIn + ub)
                );
                derivative = temp + a * maxAmountIn;
                maxAmountIn +=
                    Math.mulDiv(c1, c2, derivative) -
                    Math.mulDiv(maxAmountIn, temp, derivative);
            }
        } else {
            unchecked {
                maxAmountIn =
                    Math.mulDiv(
                        params.b1 * params.vb0,
                        2 * params.b0 * params.T - params.R * params.s,
                        params.b0 * params.R * params.vb1
                    ) -
                    params.r;
            }
        }
    }
}
