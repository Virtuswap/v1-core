pragma solidity ^0.8.0;

struct VirtualPoolModel {
    uint24 fee;
    address token0;
    address token1;
    uint256 reserve0;
    uint256 reserve1;
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
    address jkPair2;
    address ikPair2;
}

struct SwapCallbackData {
    address payer;
    address tokenIn;
    address token0;
    address token1;
    uint256 tokenInMax;
}

struct PairCreationParams {
    address factory;
    address token0;
    address token1;
    uint24 fee;
    uint24 vFee;
    uint24 max_whitelist_count;
    uint256 max_reserve_ratio;
}
