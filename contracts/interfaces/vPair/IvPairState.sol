pragma solidity ^0.8.15;

interface IvPairState {
    // function tokens() external view returns (address, address);

    function token0() external view returns (address);

    function token1() external view returns (address);

    function reserve0() external view returns (uint256);

    function reserve1() external view returns (uint256);
}
