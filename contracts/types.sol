pragma solidity ^0.8.0;

struct VirtualPoolModel {
    uint256 fee;
    address token0;
    address token1;
    uint256 reserve0;
    uint256 reserve1;
    bool balanced;
    address vPairAddress;
    uint256 sumTokenA;
    uint256 sumTokenB;
    address commonToken;
}

struct VirtualPoolTokens {
    address jk0;
    address jk1;
    address ik0;
    address ik1;
}

struct SwapCallbackData {
    address payer;
    address tokenIn;
    address tokenOut;
    uint256 tokenInMax;
}
