// SPDX-License-Identifier: Apache-2.0

pragma solidity 0.8.18;

import '../types.sol';

interface IvPoolManager {
    function getVirtualPool(
        address jkPair,
        address ikPair
    ) external view returns (VirtualPoolModel memory vPool);

    function getVirtualPools(
        address token0,
        address token1
    ) external view returns (VirtualPoolModel[] memory vPools);

    function updateVirtualPoolBalances(
        address jkPair,
        address ikPair,
        uint256 balance0,
        uint256 balance1
    ) external;
}
