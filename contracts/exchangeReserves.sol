// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./types.sol";
import "./interfaces/IvPair.sol";
import "./interfaces/IvPairFactory.sol";
import "./interfaces/IvFlashSwapCallback.sol";

contract exchangeReserves is IvFlashSwapCallback {
    address factory;

    constructor(address _factory) {
        factory = _factory;
    }

    function vFlashSwapCallback(uint256 requiredBackAmount, bytes memory data)
        external
        override
    {
        ExchangeReserveCallbackParams memory decodedData = abi.decode(
            data,
            (ExchangeReserveCallbackParams)
        );

        IvPair(decodedData.jkPair2).swapNativeToReserve(
            requiredBackAmount,
            decodedData.ikPair2,
            decodedData.jkPair1,
            new bytes(0)
        );
    }

    function exchange(
        address jkPair1,
        address ikPair1,
        address jkPair2,
        uint256 flashAmountOut,
        bytes calldata swapCallbackData
    ) external {
        IvPair(jkPair1).swapNativeToReserve(
            flashAmountOut,
            ikPair1,
            jkPair2,
            swapCallbackData
        );
    }
}
