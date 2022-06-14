// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./types.sol";
import "./ERC20/IERC20.sol";
import "./libraries/SafeERC20.sol";
import "./libraries/vSwapMath.sol";
import "./interfaces/IvPair.sol";
import "./interfaces/IvPairFactory.sol";
import "./interfaces/IvRouter.sol";
import "./interfaces/IvSwapCallee.sol";
import "./interfaces/IWETH.sol";

contract vRouter is IvRouter, IvSwapCallee {
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

    function quote() public view returns (uint256) {}

    function vSwapcallee(
        address sender,
        uint256 amount,
        uint256 expectedAmount,
        address tokenIn,
        bytes memory data
    ) external virtual {
        address token0 = IvPair(msg.sender).token0();
        address token1 = IvPair(msg.sender).token1();
        require(
            msg.sender == IvPairFactory(factory).getPair(token0, token1),
            "VSWAP:INVALID_POOL"
        ); // ensure that msg.sender is actually a registered pair

        // uint256 eth_balance = IERC20(0xaCD5165C3fC730c536cF255454fD1F5E01C36d80)
        //     .balanceOf(address(this));

        emit Debug("Callback fired ETH balance", 0);

        SafeERC20.safeTransferFrom(
            IERC20(tokenIn),
            msg.sender,
            sender,
            expectedAmount
        );
    }

    function testFlashSwap(
        address inputToken,
        address outputToken,
        uint256 amountOut
    ) external {
        address nativePool = IvPairFactory(factory).getPair(
            inputToken,
            outputToken
        );

        bytes memory data = abi.encodePacked(inputToken);
        IvPair(nativePool).swapNative(
            amountOut,
            outputToken,
            address(this),
            data
        );
    }

    function testNative(
        address inputToken,
        address outputToken,
        uint256 amountIn,
        uint256 amountOutMin
    ) external {
        address nativePool = IvPairFactory(factory).getPair(
            inputToken,
            outputToken
        );
        SafeERC20.safeTransferFrom(
            IERC20(inputToken),
            msg.sender,
            nativePool,
            amountIn
        );
        IvPair(nativePool).swapNative(
            amountOutMin,
            outputToken,
            msg.sender,
            new bytes(0)
        );
    }

    function testReserve(
        address poolAddress,
        address tokenIn,
        uint256 amount,
        uint256 minAmountOut,
        address ikPool,
        address to
    ) external {
        SafeERC20.safeTransferFrom(
            IERC20(tokenIn),
            msg.sender,
            poolAddress,
            amount
        );

        // IvPair(poolAddress).swapReserves(
        //     minAmountOut,
        //     ikPool,
        //     to,
        //     new bytes(0)
        // );
    }

    function swap(
        address[] calldata pools,
        uint256[] calldata amountsIn,
        uint256[] calldata amountsOut,
        address[] calldata iks,
        address inputToken,
        address outputToken,
        address to
    ) external {
        //check for real pool
        for (uint256 i = 0; i < pools.length; i++) {
            if (iks[i] > address(0)) {
                // REAL POOL
                SafeERC20.safeTransferFrom(
                    IERC20(inputToken),
                    msg.sender,
                    pools[i],
                    amountsIn[i]
                );

                IvPair(pools[i]).swapNative(
                    amountsOut[i],
                    outputToken,
                    to,
                    new bytes(0)
                );
            } else {
                SafeERC20.safeTransferFrom(
                    IERC20(inputToken),
                    msg.sender,
                    pools[i],
                    amountsIn[i]
                );

                // IvPair(pools[i]).swapReserves(
                //     amountsOut[i],
                //     iks[i],
                //     to,
                //     new bytes(0)
                // );
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

    // function swapExactETHForTokens(
    //     address[] calldata pools,
    //     uint256[] calldata amountsIn,
    //     uint256[] calldata amountsOut,
    //     address outputToken,
    //     uint256 deadline
    // )
    //     external
    //     payable
    //     virtual
    //     override
    //     ensure(deadline)
    //     returns (uint256[] memory amounts)
    // {
    //     amounts = UniswapV2Library.getAmountsOut(factory, msg.value, path);
    //     require(
    //         amounts[amounts.length - 1] >= amountOutMin,
    //         "UniswapV2Router: INSUFFICIENT_OUTPUT_AMOUNT"
    //     );
    //     IWETH(WETH).deposit{value: amounts[0]}();
    //     assert(
    //         IWETH(WETH).transfer(
    //             UniswapV2Library.pairFor(factory, path[0], path[1]),
    //             amounts[0]
    //         )
    //     );
    //     _swap(amounts, path, to);
    // }

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
