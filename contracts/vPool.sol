// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./types.sol";
import "./ERC20/IERC20.sol";
import "./libraries/SafeERC20.sol";
import "./libraries/vSwapMath.sol";
import "./interfaces/IvPair.sol";
import "./interfaces/IvPairFactory.sol";
import "./interfaces/IvPool.sol";
import "./interfaces/IWETH.sol";

contract vPool is IvPool {
    address public override factory;
    address public immutable override owner;
    address public immutable override WETH;

    uint256 constant EPSILON = 1 wei;

    modifier onlyOwner() {
        require(msg.sender == owner);
        _;
    }

    modifier ensure(uint256 deadline) {
        require(deadline >= block.timestamp, "VSWAP: EXPIRED");
        _;
    }

    receive() external payable {
        assert(msg.sender == WETH); // only accept ETH via fallback from the WETH contract
    }

    constructor(address _factory, address _WETH) {
        owner = msg.sender;
        factory = _factory;
        WETH = _WETH;
    }

    function testNative(
        address poolAddress,
        address inputToken,
        uint256 amount
    ) external {
        SafeERC20.safeTransferFrom(
            IERC20(inputToken),
            msg.sender,
            poolAddress,
            amount
        );

        IvPair(poolAddress).swapNative(0, msg.sender);
    }

    function testReserve(
        address poolAddress,
        address tokenIn,
        address tokenOut,
        uint256 amount,
        uint256 minAmountOut,
        address to
    ) external {
        SafeERC20.safeTransferFrom(
            IERC20(tokenIn),
            msg.sender,
            poolAddress,
            amount
        );

        IvPair(poolAddress).swapReserves(tokenIn, tokenOut, minAmountOut, to);
    }

    function swap(
        address[] calldata pools,
        uint256[] calldata amountsIn,
        uint256[] calldata amountsOut,
        address inputToken,
        address outputToken
    ) external {
        //check for real pool
        address rPool = IvPairFactory(factory).getPair(inputToken, outputToken);
        for (uint256 i = 0; i < pools.length; i++) {
            if (pools[i] == rPool && rPool > address(0)) {
                // REAL POOL
                SafeERC20.safeTransferFrom(
                    IERC20(inputToken),
                    msg.sender,
                    pools[i],
                    amountsIn[i]
                );

                IvPair(pools[i]).swapNative(amountsOut[i], msg.sender);
            } else {
                SafeERC20.safeTransferFrom(
                    IERC20(inputToken),
                    msg.sender,
                    pools[i],
                    amountsIn[i]
                );

                IvPair(pools[i]).swapReserves(
                    inputToken,
                    outputToken,
                    amountsOut[i],
                    msg.sender
                );
            }
        }
    }

    function changeFactory(address _factory) external onlyOwner {
        factory = _factory;
    }

    // function swapExactTokensForTokens(
    //     uint256 amountIn,
    //     uint256 amountOutMin,
    //     address[] calldata path,
    //     address to,
    //     uint256 deadline
    // )
    //     external
    //     virtual
    //     override
    //     ensure(deadline)
    //     returns (uint256[] memory amounts)
    // {
    //     amounts = UniswapV2Library.getAmountsOut(factory, amountIn, path);
    //     require(
    //         amounts[amounts.length - 1] >= amountOutMin,
    //         "UniswapV2Router: INSUFFICIENT_OUTPUT_AMOUNT"
    //     );
    //     TransferHelper.safeTransferFrom(
    //         path[0],
    //         msg.sender,
    //         UniswapV2Library.pairFor(factory, path[0], path[1]),
    //         amounts[0]
    //     );
    //     _swap(amounts, path, to);
    // }

    // function swapTokensForExactTokens(
    //     uint256 amountOut,
    //     uint256 amountInMax,
    //     address[] calldata path,
    //     address to,
    //     uint256 deadline
    // )
    //     external
    //     virtual
    //     override
    //     ensure(deadline)
    //     returns (uint256[] memory amounts)
    // {
    //     amounts = UniswapV2Library.getAmountsIn(factory, amountOut, path);
    //     require(
    //         amounts[0] <= amountInMax,
    //         "UniswapV2Router: EXCESSIVE_INPUT_AMOUNT"
    //     );
    //     TransferHelper.safeTransferFrom(
    //         path[0],
    //         msg.sender,
    //         UniswapV2Library.pairFor(factory, path[0], path[1]),
    //         amounts[0]
    //     );
    //     _swap(amounts, path, to);
    // }

    function swapExactETHForTokens(
        address[] calldata pools,
        uint256[] calldata amountsIn,
        uint256[] calldata amountsOut,
        address outputToken,
        uint256 deadline
    )
        external
        payable
        virtual
        override
        ensure(deadline)
        returns (uint256[] memory amounts)
    {
        amounts = UniswapV2Library.getAmountsOut(factory, msg.value, path);
        require(
            amounts[amounts.length - 1] >= amountOutMin,
            "UniswapV2Router: INSUFFICIENT_OUTPUT_AMOUNT"
        );
        IWETH(WETH).deposit{value: amounts[0]}();
        assert(
            IWETH(WETH).transfer(
                UniswapV2Library.pairFor(factory, path[0], path[1]),
                amounts[0]
            )
        );
        _swap(amounts, path, to);
    }

    // function swapTokensForExactETH(
    //     uint256 amountOut,
    //     uint256 amountInMax,
    //     address[] calldata path,
    //     address to,
    //     uint256 deadline
    // )
    //     external
    //     virtual
    //     override
    //     ensure(deadline)
    //     returns (uint256[] memory amounts)
    // {
    //     require(path[path.length - 1] == WETH, "UniswapV2Router: INVALID_PATH");
    //     amounts = UniswapV2Library.getAmountsIn(factory, amountOut, path);
    //     require(
    //         amounts[0] <= amountInMax,
    //         "UniswapV2Router: EXCESSIVE_INPUT_AMOUNT"
    //     );
    //     TransferHelper.safeTransferFrom(
    //         path[0],
    //         msg.sender,
    //         UniswapV2Library.pairFor(factory, path[0], path[1]),
    //         amounts[0]
    //     );
    //     _swap(amounts, path, address(this));
    //     IWETH(WETH).withdraw(amounts[amounts.length - 1]);
    //     TransferHelper.safeTransferETH(to, amounts[amounts.length - 1]);
    // }

    // function swapExactTokensForETH(
    //     uint256 amountIn,
    //     uint256 amountOutMin,
    //     address[] calldata path,
    //     address to,
    //     uint256 deadline
    // )
    //     external
    //     virtual
    //     override
    //     ensure(deadline)
    //     returns (uint256[] memory amounts)
    // {
    //     require(path[path.length - 1] == WETH, "UniswapV2Router: INVALID_PATH");
    //     amounts = UniswapV2Library.getAmountsOut(factory, amountIn, path);
    //     require(
    //         amounts[amounts.length - 1] >= amountOutMin,
    //         "UniswapV2Router: INSUFFICIENT_OUTPUT_AMOUNT"
    //     );
    //     TransferHelper.safeTransferFrom(
    //         path[0],
    //         msg.sender,
    //         UniswapV2Library.pairFor(factory, path[0], path[1]),
    //         amounts[0]
    //     );
    //     _swap(amounts, path, address(this));
    //     IWETH(WETH).withdraw(amounts[amounts.length - 1]);
    //     TransferHelper.safeTransferETH(to, amounts[amounts.length - 1]);
    // }

    // function swapETHForExactTokens(
    //     uint256 amountOut,
    //     address[] calldata path,
    //     address to,
    //     uint256 deadline
    // )
    //     external
    //     payable
    //     virtual
    //     override
    //     ensure(deadline)
    //     returns (uint256[] memory amounts)
    // {
    //     require(path[0] == WETH, "UniswapV2Router: INVALID_PATH");
    //     amounts = UniswapV2Library.getAmountsIn(factory, amountOut, path);
    //     require(
    //         amounts[0] <= msg.value,
    //         "UniswapV2Router: EXCESSIVE_INPUT_AMOUNT"
    //     );
    //     IWETH(WETH).deposit{value: amounts[0]}();
    //     assert(
    //         IWETH(WETH).transfer(
    //             UniswapV2Library.pairFor(factory, path[0], path[1]),
    //             amounts[0]
    //         )
    //     );
    //     _swap(amounts, path, to);
    //     // refund dust eth, if any
    //     if (msg.value > amounts[0])
    //         TransferHelper.safeTransferETH(msg.sender, msg.value - amounts[0]);
    // }
}
