// SPDX-License-Identifier: Apache-2.0

pragma solidity 0.8.2;

interface IvFlashSwapCallback {
    function vFlashSwapCallback(
        address tokenIn,
        address tokenOut,
        uint256 requiredBackAmount,
        bytes calldata data
    ) external;
}
