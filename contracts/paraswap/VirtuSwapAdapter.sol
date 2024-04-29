// SPDX-License-Identifier: ISC

pragma solidity 0.8.25;
pragma abicoder v2;

import "./interfaces/IAdapter.sol";
import "./interfaces/IBuyAdapter.sol";
import "../interfaces/IvRouter.sol";
import '../libraries/PoolAddress.sol';

/*
 * @dev This contract will route calls to dexes according to the following indexing:
 * 1- VirtuSwap
 */
contract VirtuSwapAdapter is IAdapter, IBuyAdapter {
    using SafeMath for uint256;

    struct VirtuSwapRealPoolData {
        bytes4 functionSelector;
        address path0;
        address path1;
        uint256 deadline;
    }

    struct VirtuSwapVirtualPoolData {
        bytes4 functionSelector;
        address tokenOut;
        address commonToken;
        address ikPair;
        uint256 deadline;
    }

    function initialize(bytes calldata) external virtual override(IAdapter, IBuyAdapter) {
        revert("METHOD NOT IMPLEMENTED");
    }

    function swap(
        IERC20 fromToken,
        IERC20 toToken,
        uint256 fromAmount,
        uint256,
        Utils.Route[] calldata route
    ) external payable virtual override {
        for (uint256 i = 0; i < route.length; i++) {
            if (route[i].index != 1) revert("Index not supported");

            swapOnVirtuSwap(fromToken, toToken, fromAmount.mul(route[i].percent).div(10000), route[i].targetExchange, route[i].payload);
        }
    }

    function buy(
        uint256 index,
        IERC20 fromToken,
        IERC20 toToken,
        uint256 maxFromAmount,
        uint256 toAmount,
        address targetExchange,
        bytes calldata payload
    ) external payable virtual override {
        if (index != 1) revert("Index not supported");

        buyOnVirtuSwap(fromToken, toToken, maxFromAmount, toAmount, targetExchange, payload);
    }

    function isSwapFunctionSelector(bytes4 functionSelector) internal pure returns (bool) {
        return functionSelector == IvRouter.swapExactETHForTokens.selector
            || functionSelector == IvRouter.swapExactTokensForETH.selector
            || functionSelector == IvRouter.swapETHForExactTokens.selector
            || functionSelector == IvRouter.swapTokensForExactETH.selector
            || functionSelector == IvRouter.swapTokensForExactTokens.selector
            || functionSelector == IvRouter.swapExactTokensForTokens.selector;
    }

    function isSwapReserveFunctionSelector(bytes4 functionSelector) internal pure returns (bool) {
        return functionSelector == IvRouter.swapReserveETHForExactTokens.selector
            || functionSelector == IvRouter.swapReserveTokensForExactETH.selector
            || functionSelector == IvRouter.swapReserveExactTokensForETH.selector
            || functionSelector == IvRouter.swapReserveExactETHForTokens.selector
            || functionSelector == IvRouter.swapReserveTokensForExactTokens.selector
            || functionSelector == IvRouter.swapReserveExactTokensForTokens.selector;
    }

    function swapOnVirtuSwap(
        IERC20 fromToken,
        IERC20,
        uint256 amountIn,
        address router,
        bytes calldata payload
    ) internal {
        bytes4 functionSelector = bytes4(payload);

        bytes memory callData;

        if (isSwapFunctionSelector(functionSelector)) {
            VirtuSwapRealPoolData memory data = abi.decode(payload, (VirtuSwapRealPoolData));

            address[] memory path = new address[](2);
            path[0] = data.path0;
            path[1] = data.path1;

            callData = abi.encodeWithSelector(
                data.functionSelector,
                path,
                amountIn,
                1, // UniswapV3 adapter also uses 1 as minAmountOut
                address(this),
                data.deadline
            );
        } else if (isSwapReserveFunctionSelector(functionSelector)) {
            VirtuSwapVirtualPoolData memory data = abi.decode(payload, (VirtuSwapVirtualPoolData));

            callData = abi.encodeWithSelector(
                data.functionSelector,
                data.tokenOut,
                data.commonToken,
                data.ikPair,
                amountIn,
                1, // UniswapV3 adapter also uses 1 as minAmountOut
                address(this),
                data.deadline
            );
        } else {
            revert("Unsupported function selector");
        }

        bool success;

        if (address(fromToken) == Utils.ethAddress()) {
            (success, ) = address(router).call{value: amountIn}(callData);
        } else {
            Utils.approve(router, address(fromToken), amountIn);

            (success, ) = address(router).call(callData);
        }

        require(success, "Swap failed");
    }

    function buyOnVirtuSwap(
        IERC20 fromToken,
        IERC20,
        uint256 maxAmountIn,
        uint256 amountOut,
        address router,
        bytes calldata payload
    ) internal {
        bytes4 functionSelector = bytes4(payload);

        bytes memory callData;

        if (isSwapFunctionSelector(functionSelector)) {
            VirtuSwapRealPoolData memory data = abi.decode(payload, (VirtuSwapRealPoolData));

            address[] memory path = new address[](2);
            path[0] = data.path0;
            path[1] = data.path1;

            callData = abi.encodeWithSelector(
                data.functionSelector,
                path,
                amountOut,
                maxAmountIn,
                address(this),
                data.deadline
            );
        } else if (isSwapReserveFunctionSelector(functionSelector)) {
            VirtuSwapVirtualPoolData memory data = abi.decode(payload, (VirtuSwapVirtualPoolData));

            callData = abi.encodeWithSelector(
                data.functionSelector,
                data.tokenOut,
                data.commonToken,
                data.ikPair,
                amountOut,
                maxAmountIn,
                address(this),
                data.deadline
            );
        } else {
            revert("Unsupported function selector");
        }

        bool success;

        if (address(fromToken) == Utils.ethAddress()) {
            (success, ) = address(router).call{value: maxAmountIn}(callData);
        } else {
            Utils.approve(router, address(fromToken), maxAmountIn);

            (success, ) = address(router).call(callData);
        }

        require(success, "Swap failed");
    }
}
