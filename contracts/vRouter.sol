// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@uniswap/lib/contracts/libraries/TransferHelper.sol";

import "./types.sol";
import "./vPair.sol";
import "./base/multicall.sol";
import "./libraries/poolAddress.sol";
import "./libraries/vSwapLibrary.sol";
import "./interfaces/IvRouter.sol";
import "./interfaces/IvPairFactory.sol";
import "./interfaces/IvPair.sol";

contract vRouter is IvRouter, Multicall {
    address public override factory;
    address public immutable override owner;

    modifier onlyOwner() {
        require(msg.sender == owner);
        _;
    }

    modifier ensure(uint256 deadline) {
        require(deadline >= block.timestamp, "VSWAP: EXPIRED");
        _;
    }

    constructor(address _factory) {
        owner = msg.sender;
        factory = _factory;
    }

    function getPairAddress(address tokenA, address tokenB)
        internal
        view
        returns (address)
    {
        return PoolAddress.computeAddress(factory, tokenA, tokenB);
    }

    function vFlashSwapCallback(
        uint256 requiredBackAmount,
        bytes memory callbackData
    ) external override {
        SwapCallbackData memory data = abi.decode(
            callbackData,
            (SwapCallbackData)
        );

        require(
            msg.sender ==
                PoolAddress.computeAddress(
                    factory,
                    data.tokenIn,
                    data.tokenOut
                ),
            "VSWAP:INVALID_CALLBACK_POOL"
        );

        //validate amount to pay back dont exceeds
        require(
            requiredBackAmount <= data.tokenInMax,
            "VSWAP:REQUIRED_AMOUNT_EXECEDS"
        );

        SafeERC20.safeTransferFrom(
            IERC20(data.tokenIn),
            data.payer,
            msg.sender,
            requiredBackAmount
        );
    }

    function swapToExactNative(
        address tokenA,
        address tokenB,
        uint256 amountOut,
        address to,
        bytes calldata data,
        uint256 deadline
    ) external ensure(deadline) {
        IvPair(getPairAddress(tokenA, tokenB)).swapNative(
            amountOut,
            tokenB,
            to,
            data
        );
    }

    function swapReserveToExactNative(
        address tokenA,
        address tokenB,
        address ikPair,
        uint256 amountOut,
        address to,
        bytes calldata data,
        uint256 deadline
    ) external ensure(deadline) {
        IvPair(getPairAddress(tokenA, tokenB)).swapReserveToNative(
            amountOut,
            ikPair,
            to,
            data
        );
    }

    function _addLiquidity(
        address tokenA,
        address tokenB,
        uint256 amountADesired,
        uint256 amountBDesired,
        uint256 amountAMin,
        uint256 amountBMin
    )
        internal
        returns (
            uint256 amountA,
            uint256 amountB,
            address pairAddress
        )
    {
        pairAddress = IvPairFactory(factory).getPair(tokenA, tokenB);
        // create the pair if it doesn't exist yet
        if (pairAddress == address(0))
            pairAddress = IvPairFactory(factory).createPair(tokenA, tokenB);

        (uint256 reserve0, uint256 reserve1) = IvPair(pairAddress)
            .getReserves();

        if (reserve0 == 0 && reserve1 == 0) {
            (amountA, amountB) = (amountADesired, amountBDesired);
        } else {
            uint256 amountBOptimal = vSwapLibrary.quote(
                reserve0,
                reserve1,
                amountADesired
            );

            if (amountBOptimal <= amountBDesired) {
                require(
                    amountBOptimal >= amountBMin,
                    "VSWAP: INSUFFICIENT_B_AMOUNT"
                );
                (amountA, amountB) = (amountADesired, amountBOptimal);
            } else {
                uint256 amountAOptimal = vSwapLibrary.quote(
                    reserve1,
                    reserve0,
                    amountBDesired
                );

                assert(amountAOptimal <= amountADesired);
                require(
                    amountAOptimal >= amountAMin,
                    "VSWAP: INSUFFICIENT_A_AMOUNT"
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
        override
        ensure(deadline)
        returns (
            uint256 amountA,
            uint256 amountB,
            address pairAddress,
            uint256 liquidity
        )
    {
        (amountA, amountB, pairAddress) = _addLiquidity(
            tokenA,
            tokenB,
            amountADesired,
            amountBDesired,
            amountAMin,
            amountBMin
        );

        SafeERC20.safeTransferFrom(
            IERC20(tokenA),
            msg.sender,
            pairAddress,
            amountA
        );
        SafeERC20.safeTransferFrom(
            IERC20(tokenB),
            msg.sender,
            pairAddress,
            amountB
        );

        liquidity = IvPair(pairAddress).mint(to);
    }

    function removeLiquidity(
        address tokenA,
        address tokenB,
        uint256 liquidity,
        uint256 amountAMin,
        uint256 amountBMin,
        address to,
        uint256 deadline
    )
        external
        override
        ensure(deadline)
        returns (uint256 amountA, uint256 amountB)
    {
        address pairAddress = getPairAddress(tokenA, tokenB);

        SafeERC20.safeTransferFrom(
            IERC20(pairAddress),
            msg.sender,
            pairAddress,
            liquidity
        );

        (amountA, amountB) = IvPair(pairAddress).burn(to);

        require(amountA >= amountAMin, "VSWAP: INSUFFICIENT_A_AMOUNT");
        require(amountB >= amountBMin, "VSWAP: INSUFFICIENT_B_AMOUNT");
    }

    function getVirtualAmountIn(
        address jkPair,
        address ikPair,
        uint256 amountOut
    ) external view override returns (uint256 amountIn) {
        VirtualPoolModel memory vPool = this.getVirtualPool(jkPair, ikPair);

        amountIn = vSwapLibrary.getAmountIn(
            amountOut,
            vPool.reserve0,
            vPool.reserve1,
            vPool.fee
        );
    }

    function getVirtualAmountOut(
        address jkPair,
        address ikPair,
        uint256 amountIn
    ) external view override returns (uint256 amountOut) {
        VirtualPoolModel memory vPool = this.getVirtualPool(jkPair, ikPair);

        amountOut = vSwapLibrary.getAmountOut(
            amountIn,
            vPool.reserve0,
            vPool.reserve1,
            vPool.fee
        );
    }

    function getVirtualPool(address jkPair, address ikPair)
        external
        view
        override
        returns (VirtualPoolModel memory vPool)
    {
        vPool = vSwapLibrary.getVirtualPool(jkPair, ikPair);
    }

    function quote(
        address tokenA,
        address tokenB,
        uint256 amount
    ) external view override returns (uint256 quoteR) {
        address pairAddress = getPairAddress(tokenA, tokenB);

        (uint256 reserve0, uint256 reserve1) = IvPair(pairAddress)
            .getReserves();

        (reserve0, reserve1) = vSwapLibrary.sortReserves(
            tokenA,
            IvPair(pairAddress).token0(),
            reserve0,
            reserve1
        );

        quoteR = vSwapLibrary.quote(amount, reserve0, reserve1);
    }

    function getAmountOut(
        address tokenA,
        address tokenB,
        uint256 amountIn
    ) external view virtual override returns (uint256 amountOut) {
        (uint256 reserve0, uint256 reserve1) = IvPair(
            getPairAddress(tokenA, tokenB)
        ).getReserves();
        // (reserve0, reserve1) = vSwapLibrary.sortReserves(
        //     tokenA,
        //     pair.token0(),
        //     reserve0,
        //     reserve1
        // );

        // amountOut = vSwapLibrary.getAmountOut(
        //     amountIn,
        //     reserve0,
        //     reserve1,
        //     pair.fee()
        // );
    }

    function getAmountIn(
        address tokenA,
        address tokenB,
        uint256 amountOut
    ) external view virtual override returns (uint256 amountIn) {
        address pairAddress = getPairAddress(tokenA, tokenB);

        (uint256 reserve0, uint256 reserve1) = IvPair(pairAddress)
            .getReserves();

        (reserve0, reserve1) = vSwapLibrary.sortReserves(
            tokenA,
            IvPair(pairAddress).token0(),
            reserve0,
            reserve1
        );

        amountIn = vSwapLibrary.getAmountIn(
            amountOut,
            reserve0,
            reserve1,
            IvPair(pairAddress).fee()
        );
    }

    function changeFactory(address _factory) external override onlyOwner {
        factory = _factory;
    }
}
