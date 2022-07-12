pragma solidity =0.8.1;

interface IvPairState {
    function token0() external view returns (address);

    function token1() external view returns (address);

    function reserve0() external view returns (uint256);

    function reserve1() external view returns (uint256);

    function getReserves()
        external
        view
        returns (uint256 _reserve0, uint256 _reserve1);

    function getTokens()
        external
        view
        returns (address _token0, address _token1);
}
