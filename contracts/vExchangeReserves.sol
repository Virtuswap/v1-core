// SPDX-License-Identifier: Apache-2.0
pragma solidity 0.8.2;

import "./types.sol";
import "./interfaces/IvPair.sol";
import "./interfaces/IvFlashSwapCallback.sol";

contract vExchangeReserves is IvFlashSwapCallback {
    address immutable factory;

    constructor(address _factory) {
        factory = _factory;
    }

    function vFlashSwapCallback(
        address tokenIn,
        address tokenOut,
        uint256 requiredBackAmount,
        bytes calldata data
    ) external override {
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
        address ikPair2,
        uint256 flashAmountOut
    ) external {
        IvPair(jkPair1).swapNativeToReserve(
            flashAmountOut,
            ikPair1,
            jkPair2,
            abi.encode(
                ExchangeReserveCallbackParams({
                    jkPair1: jkPair1,
                    jkPair2: jkPair2,
                    ikPair2: ikPair2
                })
            )
        );
    }
}
