// SPDX-License-Identifier: Apache-2.0
pragma solidity 0.8.2;

import "./types.sol";
import "./interfaces/IvPair.sol";
import "./interfaces/IvExchangeReserves.sol";
import "./base/multicall.sol";

contract vExchangeReserves is IvExchangeReserves, Multicall {
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

        emit ReservesExchanged(
            decodedData.jkPair1,
            decodedData.ikPair1,
            decodedData.jkPair2,
            decodedData.ikPair2,
            requiredBackAmount,
            decodedData.flashAmountOut
        );
    }

    function exchange(
        address jkPair1,
        address ikPair1,
        address jkPair2,
        address ikPair2,
        uint256 flashAmountOut
    ) external override {
        IvPair(jkPair1).swapNativeToReserve(
            flashAmountOut,
            ikPair1,
            jkPair2,
            abi.encode(
                ExchangeReserveCallbackParams({
                    jkPair1: jkPair1,
                    ikPair1: ikPair1,
                    jkPair2: jkPair2,
                    ikPair2: ikPair2,
                    flashAmountOut: flashAmountOut
                })
            )
        );
    }
}
