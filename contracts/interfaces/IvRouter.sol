// SPDX-License-Identifier: Apache-2.0

pragma solidity 0.8.28;
import '../types.sol';

interface IvRouter {
    event RouterFactoryChanged(address newFactoryAddress);

    function changeFactory(address _factory) external;

    function factory() external view returns (address);

    function WETH9() external view returns (address);

    function multiSwapExactTokensForTokens(
        uint256 deadline,
        RouteData[] calldata routeData,
        address[] calldata transitTokens,
        address tokenIn,
        address tokenOut,
        address to,
        uint256 minAmountOut
    ) external;

    function multiSwapExactETHForTokens(
        uint256 deadline,
        RouteData[] calldata routeData,
        address[] calldata transitTokens,
        address tokenOut,
        address to,
        uint256 minAmountOut
    ) external payable;

    function multiSwapExactTokensForETH(
        uint256 deadline,
        RouteData[] calldata routeData,
        address[] calldata transitTokens,
        address tokenIn,
        address to,
        uint256 minAmountOut
    ) external;

    function multiSwapTokensForExactTokens(
        uint256 deadline,
        RouteData[] calldata routeData,
        address[] calldata transitTokens,
        address tokenIn,
        address tokenOut,
        address to,
        uint256 maxAmountIn
    ) external;

    function multiSwapETHForExactTokens(
        uint256 deadline,
        RouteData[] calldata routeData,
        address[] calldata transitTokens,
        address tokenOut,
        address to,
        uint256 maxAmountIn
    ) external payable;

    function multiSwapTokensForExactETH(
        uint256 deadline,
        RouteData[] calldata routeData,
        address[] calldata transitTokens,
        address tokenIn,
        address to,
        uint256 maxAmountIn
    ) external;

    function addLiquidity(
        address tokenA,
        address tokenB,
        uint256 amountADesired,
        uint256 amountBDesired,
        uint256 amountAMin,
        uint256 amountBMin,
        address to,
        uint256 deadline
    )
        external
        returns (
            uint256 amountA,
            uint256 amountB,
            address pairAddress,
            uint256 liquidity
        );

    function removeLiquidity(
        address tokenA,
        address tokenB,
        uint256 liquidity,
        uint256 amountAMin,
        uint256 amountBMin,
        address to,
        uint256 deadline
    ) external returns (uint256 amountA, uint256 amountB);

    function getAmountOut(
        address tokenA,
        address tokenB,
        uint256 amountIn
    ) external view returns (uint256 amountOut);

    function getAmountIn(
        address tokenA,
        address tokenB,
        uint256 amountOut
    ) external view returns (uint256 amountIn);

    function quote(
        address inputToken,
        address outputToken,
        uint256 amountIn
    ) external view returns (uint256 amountOut);

    function getVirtualAmountIn(
        address jkPair,
        address ikPair,
        uint256 amountOut
    ) external view returns (uint256 amountIn);

    function getVirtualAmountOut(
        address jkPair,
        address ikPair,
        uint256 amountIn
    ) external view returns (uint256 amountOut);

    function getVirtualPool(
        address jkPair,
        address ikPair
    ) external view returns (VirtualPoolModel memory vPool);

    function getVirtualPools(
        address token0,
        address token1
    ) external view returns (VirtualPoolModel[] memory vPools);

    function getMaxVirtualTradeAmountRtoN(
        address jkPair,
        address ikPair
    ) external view returns (uint256 maxAmountIn);
}
