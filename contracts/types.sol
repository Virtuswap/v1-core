// SPDX-License-Identifier: Apache-2.0

pragma solidity ^0.8.18;

struct MaxTradeAmountParams {
    uint256 fee;
    uint256 balance0;
    uint256 balance1;
    uint256 vBalance0;
    uint256 vBalance1;
    uint256 reserveRatioFactor;
    uint256 priceFeeFactor;
    uint256 maxReserveRatio;
    uint256 reserves;
    uint256 reservesBaseValueSum;
}

struct VirtualPoolModel {
    uint24 fee;
    address token0;
    address token1;
    uint256 balance0;
    uint256 balance1;
    address commonToken;
    address jkPair;
    address ikPair;
}

struct VirtualPoolTokens {
    address jk0;
    address jk1;
    address ik0;
    address ik1;
}

struct ExchangeReserveCallbackParams {
    address jkPair1;
    address ikPair1;
    address jkPair2;
    address ikPair2;
    address caller;
    uint256 flashAmountOut;
}

struct SwapCallbackData {
    address caller;
    uint256 tokenInMax;
    uint ETHValue;
    address jkPool;
}

struct PoolCreationDefaults {
    address factory;
    address token0;
    address token1;
    uint16 fee;
    uint16 vFee;
    uint256 maxReserveRatio;
}
