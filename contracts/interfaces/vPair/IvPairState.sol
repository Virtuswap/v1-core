interface IvPairState {
    function tokens() external view returns (address, address);

    function token0() external view returns (address);

    function token1() external view returns (address);

    function price0CumulativeLast() external view returns (uint256);

    function price1CumulativeLast() external view returns (uint256);

    function quote(address tokenIn, uint256 amount)
        external
        view
        returns (uint256);

    function getNativeReserves()
        external
        view
        returns (
            uint256,
            uint256,
            uint256
        );
}
