pragma solidity =0.8.1;

interface IvPairEvents {
    event Mint(address indexed sender, uint256 amount0, uint256 amount1);

    event Burn(
        address indexed sender,
        uint256 amount0,
        uint256 amount1,
        address indexed to
    );

    event WhitelistChanged(address[] tokens);

    event Sync(uint256 balance0, uint256 balance1);

    event ReserveRatioThreshold(uint reserveRatio)
}
