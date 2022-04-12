pragma solidity >=0.4.22 <0.9.0;

struct Token128 {
    address tokenAddress;
    int128 price;
    string name;
}

struct VirtualPool128 {
    string tokenAName;
    string tokenBName;
    int128 fee;
    int128 tokenABalance;
    int128 tokenBBalance;
}

struct VirtualPoolVM128 {
    string tokenAName;
    string tokenBName;
    int128 fee;
    int128 tokenABalance;
    int128 tokenBBalance;
}

struct Pool128 {
    Token128 tokenA;
    Token128 tokenB;
    int128 fee;
    int128 reserveRatio;
    int128 belowReserve;
    int128 tokenABalance;
    int128 tokenBBalance;
    int128 maxReserveRatio;
    mapping(address => ReserveBalance128) reserves;
}

struct PoolVM128 {
    Token128 tokenA;
    Token128 tokenB;
    int128 fee;
    int128 reserveRatio;
    int128 belowReserve;
    int128 tokenABalance;
    int128 tokenBBalance;
    int128 maxReserveRatio;
    bool valid;
}

struct ReserveBalance128 {
    address tokenAddress;
    string tokenName;
    int128 reserveBalance;
}
