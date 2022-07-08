pragma solidity ^0.8.15;

interface IvPairFactoryPairs {
    function allPairsLength() external view returns (uint256);

    function getPair(address tokenA, address tokenB)
        external
        view
        returns (address);

    function admin() external view returns (address);
}
