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

    function mint(address to) external returns (uint256 liquidity);

    // function withdrawal() external;

    // function skim(address to) external;

    // function sync() external;
}
