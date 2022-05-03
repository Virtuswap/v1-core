interface IvPairEvents {
    event LiquidityChange(
        address poolAddress,
        uint256 tokenABalance,
        uint256 tokenBBalance
    );

    event Mint(address indexed sender, uint256 amount0, uint256 amount1);

    event Burn(
        address indexed sender,
        uint256 amount0,
        uint256 amount1,
        address indexed to
    );

    event WhitelistChanged(
        address token,
        bool allowed
    );
}
