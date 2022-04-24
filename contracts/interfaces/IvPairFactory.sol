pragma solidity >=0.4.22 <0.9.0;

interface IvPairFactory {
    event PairCreated(
        address poolAddress,
        address owner,
        address factory,
        address token0,
        address token1,
        address[] whitelist
    );

    function allPairsLength() external view returns (uint256);

    function getPairAddress(address tokenA, address tokenB)
        external
        view
        returns (address);

    function createPair(
        address tokenA,
        address tokenB,
        address[] memory whitelist
    ) external;
}
