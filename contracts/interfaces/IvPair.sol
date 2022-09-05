// SPDX-License-Identifier: Apache-2.0

pragma solidity 0.8.2;

import "../types.sol";

interface IvPair {
    event Mint(address indexed sender, uint256 amount0, uint256 amount1);

    event Burn(
        address indexed sender,
        uint256 amount0,
        uint256 amount1,
        address indexed to
    );

    event Swap(
        address indexed sender,
        address tokenIn,
        address tokenOut,
        uint256 amountIn,
        uint256 amountOut,
        address indexed to
    );

    event SwapReserve(
        address indexed sender,
        address tokenIn,
        address tokenOut,
        uint256 amountIn,
        uint256 amountOut,
        address ikPool,
        address indexed to
    );

    event WhitelistChanged(address[] tokens);

    event Sync(uint256 balance0, uint256 balance1);

    event FactoryChanged(address newFactory);

    event FeeChanged(uint24 fee, uint24 vFee);

    event ReserveThresholdChanged(uint256 newThreshold);

    event WhitelistCountChanged(uint24 newCount);

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

    function getLastReserves()
        external
        view
        returns (
            uint256 _reserve0,
            uint256 _reserve1,
            uint256 _blockNumber
        );

    function getTokens() external view returns (address, address);

    function reservesBaseValue(address reserveAddress)
        external
        view
        returns (uint256);

    function reserves(address reserveAddress) external view returns (uint256);
}
