struct VirtualPoolModel {
    uint256 fee;
    address token0;
    address token1;
    uint256 tokenABalance;
    uint256 tokenBBalance;
    bool balanced;
    address vPairAddress;
    uint256 sumTokenA;
    uint256 sumTokenB;
}

struct PoolReserve {
    uint256 reserve0;
    uint256 reserve1;
}
