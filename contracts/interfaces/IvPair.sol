// SPDX-License-Identifier: Apache-2.0

pragma solidity 0.8.18;

import '../types.sol';

interface IvPair {
    event Mint(
        address indexed sender,
        uint256 amount0,
        uint256 amount1,
        uint lpTokens,
        uint poolLPTokens
    );

    event Burn(
        address indexed sender,
        uint256 amount0,
        uint256 amount1,
        address indexed to,
        uint256 totalSupply
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

    event AllowListChanged(address[] tokens);

    event Sync(uint112 balance0, uint112 balance1);

    event ReserveSync(address asset, uint256 balance, uint256 rRatio);

    event FeeChanged(uint24 fee, uint24 vFee);

    event ReserveThresholdChanged(uint256 newThreshold);

    event AllowListCountChanged(uint24 _maxAllowListCount);

    event EmergencyDiscountChanged(uint256 _newEmergencyDiscount);

    event ReserveRatioWarningThresholdChanged(
        uint256 _newReserveRatioWarningThreshold
    );

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
        uint256 incentivesLimitPct,
        bytes calldata data
    ) external returns (address _token, uint256 _leftovers);

    function mint(address to) external returns (uint256 liquidity);

    function burn(
        address to
    ) external returns (uint256 amount0, uint256 amount1);

    function setAllowList(address[] memory _allowList) external;

    function setMaxAllowListCount(uint24 _maxAllowListCount) external;

    function allowListMap(address _token) external view returns (bool allowed);

    function calculateReserveRatio() external view returns (uint256 rRatio);

    function setMaxReserveThreshold(uint256 threshold) external;

    function setReserveRatioWarningThreshold(uint256 threshold) external;

    function setEmergencyDiscount(uint256 discount) external;

    function token0() external view returns (address);

    function token1() external view returns (address);

    function pairBalance0() external view returns (uint112);

    function pairBalance1() external view returns (uint112);

    function maxAllowListCount() external view returns (uint24);

    function maxReserveRatio() external view returns (uint256);

    function getBalances() external view returns (uint112, uint112);

    function getLastBalances()
        external
        view
        returns (
            uint112 _lastBalance0,
            uint112 _lastBalance1,
            uint32 _blockNumber
        );

    function getTokens() external view returns (address, address);

    function reservesBaseValue(
        address reserveAddress
    ) external view returns (uint256);

    function reserves(address reserveAddress) external view returns (uint256);

    function reservesBaseSum() external view returns (uint256);

    function reserveRatioFactor() external pure returns (uint256);
}
