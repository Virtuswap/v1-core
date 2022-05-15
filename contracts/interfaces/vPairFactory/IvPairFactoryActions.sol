interface IvPairFactoryActions {
    function createPair(
        address tokenA,
        address tokenB,
        address[] memory whitelist
    ) external;
}
