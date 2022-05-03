interface IvPairState {
    function withdrawal() external;

    function collect(uint256 tokenAAmount, uint256 tokenBAmount) external;

    function transferToken(
        address token,
        address to,
        uint256 amount
    ) external returns (bool);

    function token0() external view returns (address);

    function token1() external view returns (address);
}
