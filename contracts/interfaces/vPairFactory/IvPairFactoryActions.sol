interface IvPairFactoryActions {
    function createPair(
        address tokenA,
        address tokenB,
        address owner
    ) external returns (address);
}
