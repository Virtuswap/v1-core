// SPDX-License-Identifier: Apache-2.0

pragma solidity 0.8.18;

import './IvFlashSwapCallback.sol';

interface IvExchangeReserves is IvFlashSwapCallback {
    event ReservesExchanged(
        address jkPair1,
        address ikPair1,
        address jkPair2,
        address ikPair2,
        uint256 requiredBackAmount,
        uint256 flashAmountOut,
        address leftOverToken,
        uint leftOverAmount
    );

    event NewIncentivesLimit(uint256 newLimit);

    function factory() external view returns (address);

    function exchange(
        address jkPair1,
        address ikPair1,
        address jkPair2,
        address ikPair2,
        uint256 flashAmountOut
    ) external;

    function changeIncentivesLimitPct(uint256 newLimit) external;
}
