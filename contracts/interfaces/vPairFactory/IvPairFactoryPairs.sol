interface IvPairFactoryPairs {
    function allPairsLength() external view returns (uint256);

    function getPair(address tokenA, address tokenB)
        external
        view
        returns (address);
}
