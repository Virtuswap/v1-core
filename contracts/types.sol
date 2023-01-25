// SPDX-License-Identifier: Apache-2.0

pragma solidity 0.8.2;

struct MaxTradeAmountParams {
    int256 f;
    int256 b0;
    int256 b1;
    int256 vb0;
    int256 vb1;
    int256 R;
    int256 F;
    int256 T;
    int256 r;
    int256 s;
}

struct VirtualPoolModel {
    uint24 fee;
    address token0;
    address token1;
    uint256 balance0;
    uint256 balance1;
    address commonToken;
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
    uint24 fee;
    uint24 vFee;
    uint24 maxAllowListCount;
    uint256 maxReserveRatio;
}
