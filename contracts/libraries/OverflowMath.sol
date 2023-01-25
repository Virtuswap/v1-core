// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import '@openzeppelin/contracts/utils/math/Math.sol';

library OverflowMath {
    struct OverflowedValue {
        int256 value;
        uint256 power;
    }

    function mul(
        int256 a,
        int256 b
    ) internal pure returns (OverflowedValue memory product) {
        if (b > a) {
            // swap
            b ^= a;
            a ^= b;
            b ^= a;
        }
        bool negative;
        if (a < 0) {
            a = -a;
            negative = !negative;
        }
        if (b < 0) {
            b = -b;
            negative = !negative;
        }
        uint256 productPower = (a <= 1 ? 0 : Math.log2(uint256(a)) + 1) +
            (b <= 1 ? 0 : Math.log2(uint256(b)) + 1);
        if ((a == 0 || (a & (a - 1)) == 0) && (b == 0 || (b & (b - 1)) == 0))
            --productPower;

        if (productPower > 255) {
            product.power = productPower - 255;
        }
        product.value =
            (negative ? -1 : int8(1)) *
            (a >> ((product.power >> 1) + (product.power & 1))) *
            (b >> (product.power >> 1));
    }

    function sub(
        int256 a,
        int256 b
    ) internal pure returns (OverflowedValue memory difference) {
        if ((a > 0 && b < 0) || (a < 0 && b > 0)) difference = add(a, -b);
        else difference.value = a - b;
    }

    function add(
        int256 a,
        int256 b
    ) internal pure returns (OverflowedValue memory sum) {
        if ((a > 0 && b < 0) || (a < 0 && b > 0)) sum.value = a + b;
        bool negative = (a < 0);
        if (a < 0) a = -a;
        if (b < 0) b = -b;
        if (uint256(a) + uint256(b) > (1 << 255) - 1) {
            sum = OverflowedValue(
                (negative ? -1 : int8(1)) *
                    int256((uint256(a) + uint256(b)) >> 1),
                1
            );
        } else {
            sum.value = (negative ? -1 : int8(1)) * (a + b);
        }
    }
}
