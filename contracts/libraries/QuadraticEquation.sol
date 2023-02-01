// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import '@openzeppelin/contracts/utils/math/Math.sol';
import './OverflowMath.sol';

library QuadraticEquation {
    using OverflowMath for int256;

    function solve(
        OverflowMath.OverflowedValue memory a,
        OverflowMath.OverflowedValue memory b,
        OverflowMath.OverflowedValue memory c
    ) internal pure returns (int256 root0, int256 root1) {
        OverflowMath.OverflowedValue memory product1 = b.value.mul(b.value);
        product1.power += 2 * b.power;
        OverflowMath.OverflowedValue memory product2 = c.value.mul(4 * a.value);
        product2.power += c.power + a.power;
        uint256 maxPower = Math.max(product1.power, product2.power);
        OverflowMath.OverflowedValue memory d = (product1.value >>
            (maxPower - product1.power)).sub(
                product2.value >> (maxPower - product2.power)
            );
        maxPower += d.power;
        if ((maxPower & 1) != 0) {
            ++maxPower;
            d.value >>= 1;
            ++d.power;
        }
        require(d.value >= 0, 'Negative discriminant');
        OverflowMath.OverflowedValue memory d_sqrt = int256(
            Math.sqrt(uint256(d.value))
        ).mul(int256(1 << (maxPower >> 1)));
        assert(d_sqrt.power == 0);
        return (
            (-b.value - d_sqrt.value) / (2 * a.value),
            (-b.value + d_sqrt.value) / (2 * a.value)
        );
    }
}
