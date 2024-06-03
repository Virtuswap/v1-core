// SPDX-License-Identifier: GPL-2.0-or-later

pragma solidity 0.8.18;

// copied from @uniswap/v3-periphery/contracts/interfaces/IMulticall.sol, only updated Solidity version

/// @title Multicall interface
/// @author Uniswap Labs
/// @notice Enables calling multiple methods in a single call to the contract
interface IMulticall {
    /// @notice Call multiple functions in the current contract and return the data from all of them if they all succeed
    /// @dev The `msg.value` should not be trusted for any method callable from multicall.
    /// @param data The encoded function data for each of the calls to make to this contract
    /// @return results The results from each of the calls passed in via data
    function multicall(bytes[] calldata data) external payable returns (bytes[] memory results);
}
