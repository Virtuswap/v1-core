pragma solidity >=0.4.22 <0.9.0;

struct Token {
    address tokenAddress;
    int256 price;
    string name;
}

struct VirtualPool {
    int256 fee;
    uint256 rPoolIndex;
    address tokenA;
    address tokenB;
    int256 tokenABalance;
    int256 tokenBBalance;
    bool balanced;
}

struct VirtualPoolVM {
    string tokenAName;
    string tokenBName;
    int256 fee;
    int256 tokenABalance;
    int256 tokenBBalance;
}

struct Pool {
    uint256 id;
    address tokenA;
    address tokenB;
    address LPToken;
    int256 belowReserve;
    int256 fee;
    int256 tokenABalance;
    int256 tokenBBalance;
    int256 maxReserveRatio;
    uint256 reversePoolIndex;
    address owner;
}

struct PoolWhiteList {
    uint256 id;
}

struct PoolVM {
    address tokenA;
    address tokenB;
    address LPToken;
    int256 fee;
    int256 reserveRatio;
    int256 belowReserve;
    int256 tokenABalance;
    int256 tokenBBalance;
    int256 maxReserveRatio;
    bool valid;
}

struct PoolReserve {
    mapping(address => bool) whitelist;
    uint numberOfActivatedWL;
    mapping(address => int256) reserveBalance;
    address owner;
}
