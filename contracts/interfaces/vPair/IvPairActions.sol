interface IvPairActions {
    function swapNative(
        uint256 amountOut,
        address tokenOut,
        address to,
        bytes calldata data
    ) external;

    function swapReserves(
        uint256 amountOut,
        address ikPairAddress,
        address to,
        bytes calldata data
    ) external;

    function collect(uint256 tokenAAmount, uint256 tokenBAmount) external;

    // function withdrawal() external;

    // function skim(address to) external;

    // function sync() external;
}
