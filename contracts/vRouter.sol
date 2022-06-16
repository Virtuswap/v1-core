// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./types.sol";
import "./ERC20/IERC20.sol";
import "./libraries/SafeERC20.sol";
import "./libraries/vSwapMath.sol";
import "./libraries/TransferHelper.sol";
import "./interfaces/IvPair.sol";
import "./interfaces/IvPairFactory.sol";
import "./interfaces/IvRouter.sol";
import "./interfaces/IvPairFactory.sol";
import "./interfaces/IWETH.sol";

contract vRouter is IvRouter {
    address public override factory;
    address public immutable override owner;
    address public immutable override WETH;

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

        IvPair(poolAddress).swapReserves(
            minAmountOut,
            ikPool,
            to,
            new bytes(0)
        );
    }

    function _swap(
        address[] calldata pools,
        uint256[] calldata amountsIn,
        uint256[] calldata amountsOut,
        address[] calldata iks,
        address inputToken,
        address outputToken,
        address to
    ) internal {
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

                IvPair(pools[i]).swapReserves(
                    amountsOut[i],
                    iks[i],
                    to,
                    new bytes(0)
                );
            }
        }
    }

    function changeFactory(address _factory) external onlyOwner {
        factory = _factory;
    }

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

    // **** ADD LIQUIDITY ****
    function _addLiquidity(
        address tokenA,
        address tokenB,
        uint256 amountADesired,
        uint256 amountBDesired,
        uint256 amountAMin,
        uint256 amountBMin
    ) internal returns (uint256 amountA, uint256 amountB) {
        address pool = IvPairFactory(factory).getPair(tokenA, tokenB);
        // create the pair if it doesn't exist yet
        if (pool == address(0)) {
            address[] memory arr;
            IvPairFactory(factory).createPair(tokenA, tokenB, arr);
        }
        (uint256 reserveA, uint256 reserveB) = IvPair(pool).getNativeReserves();

        if (reserveA == 0 && reserveB == 0) {
            (amountA, amountB) = (amountADesired, amountBDesired);
        } else {
            uint256 amountBOptimal = vSwapMath.quoteOutput(
                reserveA,
                reserveB,
                0,
                amountADesired,
                false
            );
            if (amountBOptimal <= amountBDesired) {
                require(
                    amountBOptimal >= amountBMin,
                    "UniswapV2Router: INSUFFICIENT_B_AMOUNT"
                );
                (amountA, amountB) = (amountADesired, amountBOptimal);
            } else {
                uint256 amountAOptimal = vSwapMath.quoteOutput(
                    reserveA,
                    reserveB,
                    0,
                    amountBDesired,
                    false
                );

                assert(amountAOptimal <= amountADesired);
                require(
                    amountAOptimal >= amountAMin,
                    "UniswapV2Router: INSUFFICIENT_A_AMOUNT"
                );
                (amountA, amountB) = (amountAOptimal, amountBDesired);
            }
        }
    }

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
        virtual
        ensure(deadline)
        returns (
            uint256 amountA,
            uint256 amountB,
            uint256 liquidity
        )
    {
        (amountA, amountB) = _addLiquidity(
            tokenA,
            tokenB,
            amountADesired,
            amountBDesired,
            amountAMin,
            amountBMin
        );

        address pair = IvPairFactory(factory).getPair(tokenA, tokenB);

        SafeERC20.safeTransferFrom(IERC20(tokenA), msg.sender, pair, amountA);
        SafeERC20.safeTransferFrom(IERC20(tokenB), msg.sender, pair, amountB);
        liquidity = IvPair(pair).mint(to);
    }

    function addLiquidityETH(
        address token,
        uint256 amountTokenDesired,
        uint256 amountTokenMin,
        uint256 amountETHMin,
        address to,
        uint256 deadline
    )
        external
        payable
        virtual
        ensure(deadline)
        returns (
            uint256 amountToken,
            uint256 amountETH,
            uint256 liquidity
        )
    {
        (amountToken, amountETH) = _addLiquidity(
            token,
            WETH,
            amountTokenDesired,
            msg.value,
            amountTokenMin,
            amountETHMin
        );
        address pair = IvPairFactory(factory).getPair(token, WETH);
        SafeERC20.safeTransferFrom(
            IERC20(token),
            msg.sender,
            pair,
            amountToken
        );
        IWETH(WETH).deposit{value: amountETH}();
        assert(IWETH(WETH).transfer(pair, amountETH));
        liquidity = IvPair(pair).mint(to);
        // refund dust eth, if any
        if (msg.value > amountETH)
            TransferHelper.safeTransferETH(msg.sender, msg.value - amountETH);
    }

    // // **** REMOVE LIQUIDITY ****
    function removeLiquidity(
        address tokenA,
        address tokenB,
        uint256 liquidity,
        uint256 amountAMin,
        uint256 amountBMin,
        address to,
        uint256 deadline
    ) external ensure(deadline) returns (uint256 amountA, uint256 amountB) {
        address pair = IvPairFactory(factory).getPair(tokenA, tokenB);

        SafeERC20.safeTransferFrom(
            IERC20(IvPair(pair).LPToken()),
            msg.sender,
            pair,
            liquidity
        );

        (uint256 amount0, uint256 amount1) = IvPair(pair).burn(to);
        (address token0, ) = tokenA > tokenB ? tokenA : tokenB;
        (amountA, amountB) = tokenA == token0
            ? (amount0, amount1)
            : (amount1, amount0);
        require(
            amountA >= amountAMin,
            "UniswapV2Router: INSUFFICIENT_A_AMOUNT"
        );
        require(
            amountB >= amountBMin,
            "UniswapV2Router: INSUFFICIENT_B_AMOUNT"
        );
    }

    function removeLiquidityETH(
        address token,
        uint256 liquidity,
        uint256 amountTokenMin,
        uint256 amountETHMin,
        address to,
        uint256 deadline
    )
        public
        virtual
        override
        ensure(deadline)
        returns (uint256 amountToken, uint256 amountETH)
    {
        (amountToken, amountETH) = removeLiquidity(
            token,
            WETH,
            liquidity,
            amountTokenMin,
            amountETHMin,
            address(this),
            deadline
        );
        TransferHelper.safeTransfer(token, to, amountToken);
        IWETH(WETH).withdraw(amountETH);
        TransferHelper.safeTransferETH(to, amountETH);
    }
}
