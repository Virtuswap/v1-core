// SPDX-License-Identifier: ISC

pragma solidity ^0.8.18;

import "../libraries/Utils.sol";

interface IBuyAdapter {
    /**
     * @dev Certain adapters needs to be initialized.
     * This method will be called from Augustus
     */
    function initialize(bytes calldata data) external;

    /**
     * @dev The function which performs the swap on an exchange.
     * @param index Index of the router in the adapter
     * @param fromToken Address of the source token
     * @param toToken Address of the destination token
     * @param maxFromAmount Max amount of source tokens to be swapped
     * @param toAmount Amount of destination tokens to be received
     * @param targetExchange Target exchange address to be called
     * @param payload extra data which needs to be passed to this router
     */
    function buy(
        uint256 index,
        IERC20 fromToken,
        IERC20 toToken,
        uint256 maxFromAmount,
        uint256 toAmount,
        address targetExchange,
        bytes calldata payload
    ) external payable;
}
