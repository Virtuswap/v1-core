pragma solidity ^0.8.15;

interface IvPairFactoryActions {
    function createPair(
        address tokenA,
        address tokenB
    ) external returns (address);
}
