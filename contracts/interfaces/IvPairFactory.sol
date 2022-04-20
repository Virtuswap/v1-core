pragma solidity >=0.4.22 <0.9.0;

interface IvPairFactory {
    event PairCreated(
        address poolAddress,
        address owner,
        address factory,
        address tokenA,
        address tokenB,
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
