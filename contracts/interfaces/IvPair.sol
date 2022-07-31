pragma solidity ^0.8.0;

interface IvPair {
    event Mint(address indexed sender, uint256 amount0, uint256 amount1);

    event Burn(
        address indexed sender,
        uint256 amount0,
        uint256 amount1,
        address indexed to
    );

    event WhitelistChanged(address[] tokens);

    event Sync(uint256 balance0, uint256 balance1);

    function fee() external view returns (uint24);

    function vFee() external view returns (uint24);

    function setFee(uint24 _fee, uint24 _vFee) external;

    function swapNative(
        uint256 amountOut,
        address tokenOut,
        address to,
        bytes calldata data
    ) external returns (uint256 _amountIn);

    function swapReserveToNative(
        uint256 amountOut,
        address ikPair,
        address to,
        bytes calldata data
    ) external returns (uint256 _amountIn);

    function swapNativeToReserve(
        uint256 amountOut,
        address ikPair,
        address to,
        bool isER,
        bytes calldata data
    ) external returns (uint256 _amountIn);

    function mint(address to) external returns (uint256 liquidity);

    function burn(address to)
        external
        returns (uint256 amount0, uint256 amount1);

    function setWhitelist(address[] memory _whitelist) external;

    function setMaxWhitelistCount(uint24 maxWhitelist) external;

    function calculateReserveRatio() external view returns (uint256 rRatio);

    function setMaxReserveThreshold(uint256 threshold) external;

    function token0() external view returns (address);

    function token1() external view returns (address);

    function reserve0() external view returns (uint256);

    function reserve1() external view returns (uint256);

    function max_whitelist_count() external view returns (uint24);

    function getReserves() external view returns (uint256, uint256);

    function getTokens() external view returns (address, address);

    function reservesBaseValue(address reserveAddress)
        external
        view
        returns (uint256);

    function reserves(address reserveAddress) external view returns (uint256);
}
