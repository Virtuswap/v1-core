interface IvPairActions {
    function swapNative(uint256 amountOut, address to) external;

    function swapReserves(
        address tokenIn,
        address tokenOut,
        uint256 minAmountOut,
        address ikPairAddress,
        address to
    ) external;

    function withdrawal() external;

    function collect(uint256 tokenAAmount, uint256 tokenBAmount) external;

    function skim(address to) external;

    function sync() external;
}
