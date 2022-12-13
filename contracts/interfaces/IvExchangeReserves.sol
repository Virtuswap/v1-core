// SPDX-License-Identifier: Apache-2.0

pragma solidity 0.8.2;

import './IvFlashSwapCallback.sol';

interface IvExchangeReserves is IvFlashSwapCallback {
    event ReservesExchanged(
        address jkPair1,
        address ikPair1,
        address jkPair2,
        address ikPair2,
        uint256 requiredBackAmount,
        uint256 flashAmountOut
    );

    function exchange(
        address jkPair1,
        address ikPair1,
        address jkPair2,
        address ikPair2,
        uint256 flashAmountOut
    ) external;
}
