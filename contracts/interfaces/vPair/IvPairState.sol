interface IvPairState {
    function tokens() external view returns (address, address);

    function token0() external view returns (address);

    function token1() external view returns (address);

    function reserve0() external view returns (uint256);

    function reserve1() external view returns (uint256);

    function reserveRatio() external view returns (uint256);

    // function quoteInput(
    //     address tokenIn,
    //     uint256 amount,
    //     bool calculateFees
    // ) external view returns (uint256);

    // function getNativeReserves() external view returns (uint256, uint256);
}
