interface IvPairState {
    function withdrawal() external;

    function collect(uint256 tokenAAmount, uint256 tokenBAmount) external;

    function transferToken(
        address token,
        address to,
        uint256 amount
    ) external returns (bool);

    function tokens() external view returns (address, address);

    function token0() external view returns (address);

    function token1() external view returns (address);

    function quote(address tokenIn, uint256 amount)
        external
        view
        returns (uint256);

    function swapNative(
        address tokenIn,
        uint256 amount,
        uint256 minAmountOut,
        address to
    ) external;

    function swapReserves(
        address tokenIn,
        address tokenOut,
        uint256 amount,
        uint256 minAmountOut,
        address to
    ) external;
}
