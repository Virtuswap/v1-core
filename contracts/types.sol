// SPDX-License-Identifier: Apache-2.0

pragma solidity 0.8.2;

struct MaxTradeAmountParams {
    uint256 f;
    uint256 b0;
    uint256 b1;
    uint256 vb0;
    uint256 vb1;
    uint256 R;
    uint256 F;
    uint256 T;
    uint256 r;
    uint256 s;
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
    uint24 fee;
    uint24 vFee;
    uint24 maxAllowListCount;
    uint256 maxReserveRatio;
}
