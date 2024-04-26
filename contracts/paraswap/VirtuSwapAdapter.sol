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

    mapping(bytes4 => bool) private vRouterSwapFunctionsSelectors;
    mapping(bytes4 => bool) private vRouterSwapReserveFunctionsSelectors;

    constructor() {
        vRouterSwapFunctionsSelectors[IvRouter.swapExactETHForTokens.selector] = true;
        vRouterSwapFunctionsSelectors[IvRouter.swapExactTokensForETH.selector] = true;
        vRouterSwapFunctionsSelectors[IvRouter.swapETHForExactTokens.selector] = true;
        vRouterSwapFunctionsSelectors[IvRouter.swapTokensForExactETH.selector] = true;
        vRouterSwapFunctionsSelectors[IvRouter.swapTokensForExactTokens.selector] = true;
        vRouterSwapFunctionsSelectors[IvRouter.swapExactTokensForTokens.selector] = true;

        vRouterSwapReserveFunctionsSelectors[IvRouter.swapReserveETHForExactTokens.selector] = true;
        vRouterSwapReserveFunctionsSelectors[IvRouter.swapReserveTokensForExactETH.selector] = true;
        vRouterSwapReserveFunctionsSelectors[IvRouter.swapReserveExactTokensForETH.selector] = true;
        vRouterSwapReserveFunctionsSelectors[IvRouter.swapReserveExactETHForTokens.selector] = true;
        vRouterSwapReserveFunctionsSelectors[IvRouter.swapReserveTokensForExactTokens.selector] = true;
        vRouterSwapReserveFunctionsSelectors[IvRouter.swapReserveExactTokensForTokens.selector] = true;
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

    function swapOnVirtuSwap(
        IERC20 fromToken,
        IERC20,
        uint256 amountIn,
        address router,
        bytes calldata payload
    ) internal {
        bytes4 functionSelector = bytes4(payload[:4]);

        bytes memory callData;

        if (vRouterSwapFunctionsSelectors[functionSelector]) {
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
        } else if (vRouterSwapReserveFunctionsSelectors[functionSelector]) {
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
        bytes4 functionSelector = bytes4(payload[:4]);

        bytes memory callData;

        if (vRouterSwapFunctionsSelectors[functionSelector]) {
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
        } else if (vRouterSwapReserveFunctionsSelectors[functionSelector]) {
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
