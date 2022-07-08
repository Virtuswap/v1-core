pragma solidity ^0.8.15;

interface IvPairFactoryEvents {
    event PairCreated(
        address poolAddress,
        address factory,
        address token0,
        address token1
    );
}
