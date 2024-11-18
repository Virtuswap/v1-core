// SPDX-License-Identifier: Apache-2.0

pragma solidity 0.8.28;

import '@openzeppelin/contracts/token/ERC20/IERC20.sol';
import '@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol';
import '@uniswap/lib/contracts/libraries/TransferHelper.sol';

import './types.sol';
import './vPair.sol';
import './libraries/PoolAddress.sol';
import './libraries/vSwapLibrary.sol';
import './interfaces/IvRouter.sol';
import './interfaces/IvPairFactory.sol';
import './interfaces/IvPoolManager.sol';
import './interfaces/IvPair.sol';
import './interfaces/external/IWETH9.sol';

contract vRouter is IvRouter, IvFlashSwapCallback {
    address public override factory;
    address public immutable override WETH9;

    modifier _onlyFactoryAdmin() {
        require(
            msg.sender == IvPairFactory(factory).admin(),
            'VSWAP:ONLY_ADMIN'
        );
        _;
    }

    modifier notAfter(uint256 deadline) {
        require(deadline >= block.timestamp, 'VSWAP:EXPIRED');
        _;
    }

    constructor(address _factory, address _WETH9) {
        WETH9 = _WETH9;
        factory = _factory;
    }

    receive() external payable {
        require(msg.sender == WETH9, 'Not WETH9');
    }

    function getPairAddress(
        address tokenA,
        address tokenB
    ) internal view returns (address) {
        return PoolAddress.computeAddress(factory, tokenA, tokenB);
    }

    function unwrapTransferETH(address to, uint256 amount) internal {
        IWETH9(WETH9).withdraw(amount);
        (bool success, ) = to.call{value: amount}('');
        require(success, 'VSWAP: TRANSFER FAILED');
    }

    function getAmountsIn(
        address[] memory path,
        uint256 amountOut
    ) public view returns (uint[] memory amountsIn) {
        unchecked {
            amountsIn = new uint[](path.length);
            amountsIn[amountsIn.length - 1] = amountOut;
            for (uint i = path.length - 1; i > 0; --i) {
                uint prevI = i - 1;
                amountsIn[prevI] = getAmountIn(path[prevI], path[i], amountsIn[i]);
            }
        }
    }

    function getAmountsOut(
        address[] memory path,
        uint256 amountIn
    ) public view returns (uint[] memory amountsOut) {
        amountsOut = new uint[](path.length);
        amountsOut[0] = amountIn;
        unchecked {
            for (uint i = 1; i < amountsOut.length; ++i) {
                uint prevI = i - 1;
                amountsOut[i] = getAmountOut(
                    path[prevI],
                    path[i],
                    amountsOut[prevI]
                );
            }
        }
    }

    function unwrapRoute(
        RouteData route
    ) internal pure returns (uint256 transitStartIndex, uint256 transitLength, uint256 amount) {
        uint256 data = RouteData.unwrap(route);
        transitStartIndex = uint64(data >> 192);
        transitLength = uint64(data >> 128); // if transitLength = type(uint64).max => virtual route
        amount = uint128(data);
    }

    function vFlashSwapCallback(
        address tokenIn,
        address tokenOut,
        uint256 requiredAmountIn,
        bytes calldata data
    ) external override {
        PoolCallbackData memory decodedData = abi.decode(data, (PoolCallbackData));

        address pairAddress = getPairAddress(decodedData.poolToken, tokenOut);
        require(msg.sender == pairAddress, 'VSWAP: INVALID_CALLER');

        if (decodedData.from == address(this)) {
            SafeERC20.safeTransfer(IERC20(tokenIn), pairAddress, requiredAmountIn);
        } else {
            SafeERC20.safeTransferFrom(IERC20(tokenIn), decodedData.from, pairAddress, requiredAmountIn);
        }
    }

    function swapExactIn(
        address tokenIn,
        address tokenOut,
        address[] calldata transitTokens,
        address from,
        address to,
        uint256 transitStartIndex,
        uint256 transitLength,
        uint256 amountIn
    ) internal returns (uint256 amountOut) {
        address transitToken = transitTokens[transitStartIndex];
        address transitPairAddress = getPairAddress(tokenIn, transitToken);

        amountOut = getAmountOutByPair(
            tokenIn,
            transitPairAddress,
            amountIn
        );

        if (from == address(this)) {
            SafeERC20.safeTransfer(IERC20(tokenIn), transitPairAddress, amountIn);
        } else {
            SafeERC20.safeTransferFrom(IERC20(tokenIn), from, transitPairAddress, amountIn);
        }


        for (uint j = 1; j < transitLength; ++j) {
            address nextTransitToken = transitTokens[transitStartIndex + j];
            address nextTransitPairAddress = getPairAddress(transitToken, nextTransitToken);
            IvPair(transitPairAddress).swapNative(
                amountOut,
                transitToken,
                nextTransitPairAddress,
                new bytes(0)
            );
            amountOut = getAmountOutByPair(
                transitToken,
                nextTransitPairAddress,
                amountOut
            );
            transitPairAddress = nextTransitPairAddress;
            transitToken = nextTransitToken;
        }

        address lastTransitPairAddress = getPairAddress(transitToken, tokenOut);

        IvPair(transitPairAddress).swapNative(
            amountOut,
            transitToken,
            lastTransitPairAddress,
            new bytes(0)
        );

        amountOut = getAmountOutByPair(
            transitToken,
            lastTransitPairAddress,
            amountOut
        );

        IvPair(lastTransitPairAddress).swapNative(
            amountOut,
            tokenOut,
            to,
            new bytes(0)
        );
    }

    function trySwapReserveExactIn(
        address tokenIn,
        address tokenOut,
        address commonToken,
        address from,
        address to,
        uint256 amountIn
    ) internal returns (uint256 amountOut) {
        address ikPairAddress = getPairAddress(tokenIn, commonToken);
        address jkPairAddress = getPairAddress(commonToken, tokenOut);

        try IvPoolManager(IvPairFactory(factory).vPoolManager())
            .getVirtualPool(jkPairAddress, ikPairAddress) returns (VirtualPoolModel memory vPool) {
            amountOut = vSwapLibrary.getAmountOut(
                amountIn,
                vPool.balance0,
                vPool.balance1,
                vPool.fee
            );
            try IvPair(jkPairAddress).swapReserveToNative(
                amountOut,
                ikPairAddress,
                to,
                abi.encode(
                    PoolCallbackData({
                        from: from,
                        poolToken: commonToken
                    })
                )
            ) { } catch {
                amountOut = 0;
            }
        } catch {
            amountOut = 0;
        }

        if (amountOut == 0) {
            uint256 commonAmount = getAmountOutByPair(
                tokenIn,
                ikPairAddress,
                amountIn
            );

            if (from == address(this)) {
                SafeERC20.safeTransfer(IERC20(tokenIn), ikPairAddress, amountIn);
            } else {
                SafeERC20.safeTransferFrom(IERC20(tokenIn), from, ikPairAddress, amountIn);
            }

            IvPair(ikPairAddress).swapNative(
                commonAmount,
                commonToken,
                jkPairAddress,
                new bytes(0)
            );

            amountOut = getAmountOutByPair(
                commonToken,
                jkPairAddress,
                commonAmount
            );

            IvPair(jkPairAddress).swapNative(
                amountOut,
                tokenOut,
                to,
                new bytes(0)
            );
        }
    }

    function multiSwapExactTokensForTokens(
        uint256 deadline,
        RouteData[] calldata routeData,
        address[] calldata transitTokens,
        address tokenIn,
        address tokenOut,
        address to,
        uint256 minAmountOut
    ) external {
        {
            require(deadline >= block.timestamp, 'VSWAP:EXPIRED');
        }

        uint256 totalAmountOut = 0;

        unchecked {
            for (uint i = 0; i < routeData.length; ++i) {
                (uint256 transitStartIndex, uint256 transitLength, uint256 amountIn) = unwrapRoute(routeData[i]);

                if (transitLength < type(uint64).max) {
                    if (transitLength == 0) {
                        address directPairAddress = getPairAddress(tokenIn, tokenOut);

                        uint256 amountOut = getAmountOutByPair(
                            tokenIn,
                            directPairAddress,
                            amountIn
                        );

                        SafeERC20.safeTransferFrom(IERC20(tokenIn), msg.sender, directPairAddress, amountIn);

                        IvPair(directPairAddress).swapNative(
                            amountOut,
                            tokenOut,
                            to,
                            new bytes(0)
                        );

                        totalAmountOut += amountOut;
                    } else {
                        totalAmountOut += swapExactIn(
                            tokenIn,
                            tokenOut,
                            transitTokens,
                            msg.sender,
                            to,
                            transitStartIndex,
                            transitLength,
                            amountIn
                        );
                    }
                } else {
                    address commonToken = transitTokens[transitStartIndex];

                    totalAmountOut += trySwapReserveExactIn(
                        tokenIn,
                        tokenOut,
                        commonToken,
                        msg.sender,
                        to,
                        amountIn
                    );
                }
            }
        }

        require(
            totalAmountOut >= minAmountOut,
            'VSWAP: INSUFFICIENT_OUTPUT_AMOUNT'
        );
    }

    function multiSwapExactETHForTokens(
        uint256 deadline,
        RouteData[] calldata routeData,
        address[] calldata transitTokens,
        address tokenOut,
        address to,
        uint256 minAmountOut
    ) external payable {
        {
            require(deadline >= block.timestamp, 'VSWAP:EXPIRED');
        }

        uint256 totalAmountOut = 0;

        unchecked {
            address tokenIn = WETH9;

            {
                uint256 totalAmountIn = 0;
                for (uint i = 0; i < routeData.length; ++i) {
                    totalAmountIn += uint128(RouteData.unwrap(routeData[i]));
                }

                IWETH9(tokenIn).deposit{value: totalAmountIn}();
            }

            for (uint i = 0; i < routeData.length; ++i) {
                (uint256 transitStartIndex, uint256 transitLength, uint256 amountIn) = unwrapRoute(routeData[i]);

                if (transitLength < type(uint64).max) {
                    if (transitLength == 0) {
                        address directPairAddress = getPairAddress(tokenIn, tokenOut);

                        uint256 amountOut = getAmountOutByPair(
                            tokenIn,
                            directPairAddress,
                            amountIn
                        );

                        SafeERC20.safeTransfer(IERC20(tokenIn), directPairAddress, amountIn);

                        IvPair(directPairAddress).swapNative(
                            amountOut,
                            tokenOut,
                            to,
                            new bytes(0)
                        );

                        totalAmountOut += amountOut;
                    } else {
                        totalAmountOut += swapExactIn(
                            tokenIn,
                            tokenOut,
                            transitTokens,
                            address(this),
                            to,
                            transitStartIndex,
                            transitLength,
                            amountIn
                        );
                    }
                } else {
                    address commonToken = transitTokens[transitStartIndex];

                    totalAmountOut += trySwapReserveExactIn(
                        tokenIn,
                        tokenOut,
                        commonToken,
                        address(this),
                        to,
                        amountIn
                    );
                }
            }
        }

        {
            uint256 leftover = address(this).balance;
            if (leftover > 0) {
                (bool success, ) = to.call{value: leftover}('');
                require(success, 'VSWAP: TRANSFER FAILED');
            }
        }

        require(
            totalAmountOut >= minAmountOut,
            'VSWAP: INSUFFICIENT_OUTPUT_AMOUNT'
        );
    }

    function multiSwapExactTokensForETH(
        uint256 deadline,
        RouteData[] calldata routeData,
        address[] calldata transitTokens,
        address tokenIn,
        address to,
        uint256 minAmountOut
    ) external {
        {
            require(deadline >= block.timestamp, 'VSWAP:EXPIRED');
        }

        uint256 totalAmountOut = 0;

        unchecked {
            address tokenOut = WETH9;

            for (uint i = 0; i < routeData.length; ++i) {
                (uint256 transitStartIndex, uint256 transitLength, uint256 amountIn) = unwrapRoute(routeData[i]);

                if (transitLength < type(uint64).max) {
                    if (transitLength == 0) {
                        address directPairAddress = getPairAddress(tokenIn, tokenOut);

                        uint256 amountOut = getAmountOutByPair(
                            tokenIn,
                            directPairAddress,
                            amountIn
                        );

                        SafeERC20.safeTransferFrom(IERC20(tokenIn), msg.sender, directPairAddress, amountIn);

                        IvPair(directPairAddress).swapNative(
                            amountOut,
                            tokenOut,
                            address(this),
                            new bytes(0)
                        );

                        totalAmountOut += amountOut;
                    } else {
                        totalAmountOut += swapExactIn(
                            tokenIn,
                            tokenOut,
                            transitTokens,
                            msg.sender,
                            address(this),
                            transitStartIndex,
                            transitLength,
                            amountIn
                        );
                    }
                } else {
                    address commonToken = transitTokens[transitStartIndex];

                    totalAmountOut += trySwapReserveExactIn(
                        tokenIn,
                        tokenOut,
                        commonToken,
                        msg.sender,
                        address(this),
                        amountIn
                    );
                }
            }

            IWETH9(tokenOut).withdraw(totalAmountOut);
            (bool success, ) = to.call{value: totalAmountOut}('');
            require(success, 'VSWAP: TRANSFER FAILED');
        }

        require(
            totalAmountOut >= minAmountOut,
            'VSWAP: INSUFFICIENT_OUTPUT_AMOUNT'
        );
    }

    function swapExactOut(
        address tokenIn,
        address tokenOut,
        address[] calldata transitTokens,
        address from,
        address to,
        uint256 transitStartIndex,
        uint256 transitLength,
        uint256 amountOut
    ) internal returns (uint256 amountIn) {

        address[] memory path = new address[](transitLength + 2);
        path[0] = tokenIn;
        for (uint j = 0; j < transitLength; ++j) {
            path[j + 1] = transitTokens[transitStartIndex + j];
        }
        path[transitLength + 1] = tokenOut;

        uint256[] memory amounts = getAmountsIn(path, amountOut);
        amountIn = amounts[0];

        address transitPairAddress = getPairAddress(tokenIn, path[1]);

        if (from == address(this)) {
            SafeERC20.safeTransfer(IERC20(tokenIn), transitPairAddress, amountIn);
        } else {
            SafeERC20.safeTransferFrom(IERC20(tokenIn), from, transitPairAddress, amountIn);
        }

        for (uint j = 0; j < transitLength; ++j) {
            uint jNext = j + 1;
            address nextTransitPairAddress = getPairAddress(path[jNext], path[j + 2]);
            IvPair(transitPairAddress).swapNative(
                amounts[jNext],
                path[jNext],
                nextTransitPairAddress,
                new bytes(0)
            );
            transitPairAddress = nextTransitPairAddress;
        }

        uint256 lastPathIndex = transitLength + 1;
        IvPair(transitPairAddress).swapNative(
            amounts[lastPathIndex],
            path[lastPathIndex],
            to,
            new bytes(0)
        );
    }

    function trySwapReserveExactOut(
        address tokenIn,
        address tokenOut,
        address commonToken,
        address from,
        address to,
        uint256 amountOut
    ) internal returns (uint256 amountIn) {
        address ikPairAddress = getPairAddress(tokenIn, commonToken);
        address jkPairAddress = getPairAddress(commonToken, tokenOut);

        try IvPoolManager(IvPairFactory(factory).vPoolManager())
            .getVirtualPool(jkPairAddress, ikPairAddress) returns (VirtualPoolModel memory vPool) {
            amountIn = vSwapLibrary.getAmountIn(
                amountOut,
                vPool.balance0,
                vPool.balance1,
                vPool.fee
            );
            try IvPair(jkPairAddress).swapReserveToNative(
                amountOut,
                ikPairAddress,
                to,
                abi.encode(
                    PoolCallbackData({
                        from: from,
                        poolToken: commonToken
                    })
                )
            ) { } catch {
                amountIn = 0;
            }
        } catch {
            amountIn = 0;
        }
        
        if (amountIn == 0) {
            uint256 commonAmount = getAmountInByPair(
                commonToken,
                jkPairAddress,
                amountOut
            );

            amountIn = getAmountInByPair(
                tokenIn,
                ikPairAddress,
                commonAmount
            );

            if (from == address(this)) {
                SafeERC20.safeTransfer(IERC20(tokenIn), ikPairAddress, amountIn);
            } else {
                SafeERC20.safeTransferFrom(IERC20(tokenIn), from, ikPairAddress, amountIn);
            }

            IvPair(ikPairAddress).swapNative(
                commonAmount,
                commonToken,
                jkPairAddress,
                new bytes(0)
            );

            IvPair(jkPairAddress).swapNative(
                amountOut,
                tokenOut,
                to,
                new bytes(0)
            );
        }
    }

    function multiSwapTokensForExactTokens(
        uint256 deadline,
        RouteData[] calldata routeData,
        address[] calldata transitTokens,
        address tokenIn,
        address tokenOut,
        address to,
        uint256 maxAmountIn
    ) external {
        {
            require(deadline >= block.timestamp, 'VSWAP:EXPIRED');
        }

        uint256 totalAmountIn = 0;

        unchecked {
            for (uint i = 0; i < routeData.length; ++i) {
                (uint256 transitStartIndex, uint256 transitLength, uint256 amountOut) = unwrapRoute(routeData[i]);

                if (transitLength < type(uint64).max) {
                    if (transitLength == 0) {
                        address directPairAddress = getPairAddress(tokenIn, tokenOut);

                        uint256 amountIn = getAmountInByPair(
                            tokenIn,
                            directPairAddress,
                            amountOut
                        );

                        SafeERC20.safeTransferFrom(IERC20(tokenIn), msg.sender, directPairAddress, amountIn);

                        IvPair(directPairAddress).swapNative(
                            amountOut,
                            tokenOut,
                            to,
                            new bytes(0)
                        );

                        totalAmountIn += amountIn;
                    } else {
                        totalAmountIn += swapExactOut(
                            tokenIn,
                            tokenOut,
                            transitTokens,
                            msg.sender,
                            to,
                            transitStartIndex,
                            transitLength,
                            amountOut
                        );
                    }
                } else {
                    address commonToken = transitTokens[transitStartIndex];

                    totalAmountIn += trySwapReserveExactOut(
                        tokenIn,
                        tokenOut,
                        commonToken,
                        msg.sender,
                        to,
                        amountOut
                    );
                }
            }
        }

        require(
            totalAmountIn <= maxAmountIn,
            'VSWAP: REQUIRED_AMOUNT_EXCEEDS'
        );
    }

    function multiSwapETHForExactTokens(
        uint256 deadline,
        RouteData[] calldata routeData,
        address[] calldata transitTokens,
        address tokenOut,
        address to,
        uint256 maxAmountIn
    ) external payable {
        {
            require(deadline >= block.timestamp, 'VSWAP:EXPIRED');
        }

        uint256 totalAmountIn = 0;
        uint256 leftover = address(this).balance;

        unchecked {
            address tokenIn = WETH9;

            {
                IWETH9(tokenIn).deposit{value: leftover}();
            }

            for (uint i = 0; i < routeData.length; ++i) {
                (uint256 transitStartIndex, uint256 transitLength, uint256 amountOut) = unwrapRoute(routeData[i]);

                if (transitLength < type(uint64).max) {
                    if (transitLength == 0) {
                        address directPairAddress = getPairAddress(tokenIn, tokenOut);

                        uint256 amountIn = getAmountInByPair(
                            tokenIn,
                            directPairAddress,
                            amountOut
                        );

                        SafeERC20.safeTransfer(IERC20(tokenIn), directPairAddress, amountIn);

                        IvPair(directPairAddress).swapNative(
                            amountOut,
                            tokenOut,
                            to,
                            new bytes(0)
                        );

                        totalAmountIn += amountIn;
                    } else {
                        totalAmountIn += swapExactOut(
                            tokenIn,
                            tokenOut,
                            transitTokens,
                            address(this),
                            to,
                            transitStartIndex,
                            transitLength,
                            amountOut
                        );
                    }
                } else {
                    address commonToken = transitTokens[transitStartIndex];

                    totalAmountIn += trySwapReserveExactOut(
                        tokenIn,
                        tokenOut,
                        commonToken,
                        address(this),
                        to,
                        amountOut
                    );
                }
            }

            leftover = leftover - totalAmountIn;
            if (leftover > 0) {
                IWETH9(tokenIn).withdraw(leftover);
                (bool success, ) = to.call{value: leftover}('');
                require(success, 'VSWAP: TRANSFER FAILED');
            }
        }

        require(
            totalAmountIn <= maxAmountIn,
            'VSWAP: REQUIRED_AMOUNT_EXCEEDS'
        );
    }

    function multiSwapTokensForExactETH(
        uint256 deadline,
        RouteData[] calldata routeData,
        address[] calldata transitTokens,
        address tokenIn,
        address to,
        uint256 maxAmountIn
    ) external {
        {
            require(deadline >= block.timestamp, 'VSWAP:EXPIRED');
        }

        uint256 totalAmountIn = 0;

        unchecked {
            uint256 totalAmountOut = 0;
            address tokenOut = WETH9;

            for (uint i = 0; i < routeData.length; ++i) {
                (uint256 transitStartIndex, uint256 transitLength, uint256 amountOut) = unwrapRoute(routeData[i]);
                totalAmountOut += amountOut;

                if (transitLength < type(uint64).max) {
                    if (transitLength == 0) {
                        address directPairAddress = getPairAddress(tokenIn, tokenOut);

                        uint256 amountIn = getAmountInByPair(
                            tokenIn,
                            directPairAddress,
                            amountOut
                        );

                        SafeERC20.safeTransferFrom(IERC20(tokenIn), msg.sender, directPairAddress, amountIn);

                        IvPair(directPairAddress).swapNative(
                            amountOut,
                            tokenOut,
                            address(this),
                            new bytes(0)
                        );

                        totalAmountIn += amountIn;
                    } else {
                        totalAmountIn += swapExactOut(
                            tokenIn,
                            tokenOut,
                            transitTokens,
                            msg.sender,
                            address(this),
                            transitStartIndex,
                            transitLength,
                            amountOut
                        );
                    }
                } else {
                    address commonToken = transitTokens[transitStartIndex];

                    totalAmountIn += trySwapReserveExactOut(
                        tokenIn,
                        tokenOut,
                        commonToken,
                        msg.sender,
                        address(this),
                        amountOut
                    );
                }
            }

            IWETH9(tokenOut).withdraw(totalAmountOut);
            (bool success, ) = to.call{value: totalAmountOut}('');
            require(success, 'VSWAP: TRANSFER FAILED');
        }

        require(
            totalAmountIn <= maxAmountIn,
            'VSWAP: REQUIRED_AMOUNT_EXCEEDS'
        );
    }

    function _addLiquidity(
        address tokenA,
        address tokenB,
        uint256 amountADesired,
        uint256 amountBDesired,
        uint256 amountAMin,
        uint256 amountBMin
    ) internal returns (uint256 amountA, uint256 amountB, address pairAddress) {
        pairAddress = IvPairFactory(factory).pairs(tokenA, tokenB);
        // create the pair if it doesn't exist yet
        if (pairAddress == address(0))
            pairAddress = IvPairFactory(factory).createPair(tokenA, tokenB);

        (uint256 reserve0, uint256 reserve1) = IvPair(pairAddress)
            .getBalances();

        (reserve0, reserve1) = vSwapLibrary.sortBalances(
            IvPair(pairAddress).token0(),
            tokenA,
            reserve0,
            reserve1
        );

        if (reserve0 == 0 && reserve1 == 0) {
            (amountA, amountB) = (amountADesired, amountBDesired);
        } else {
            uint256 amountBOptimal = vSwapLibrary.quote(
                amountADesired,
                reserve0,
                reserve1
            );

            if (amountBOptimal <= amountBDesired) {
                require(
                    amountBOptimal >= amountBMin,
                    'VSWAP: INSUFFICIENT_B_AMOUNT'
                );
                (amountA, amountB) = (amountADesired, amountBOptimal);
            } else {
                uint256 amountAOptimal = vSwapLibrary.quote(
                    amountBDesired,
                    reserve1,
                    reserve0
                );

                assert(amountAOptimal <= amountADesired);
                require(
                    amountAOptimal >= amountAMin,
                    'VSWAP: INSUFFICIENT_A_AMOUNT'
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
        notAfter(deadline)
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
        notAfter(deadline)
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

        require(amountA >= amountAMin, 'VSWAP: INSUFFICIENT_A_AMOUNT');
        require(amountB >= amountBMin, 'VSWAP: INSUFFICIENT_B_AMOUNT');
    }

    function getVirtualAmountIn(
        address jkPair,
        address ikPair,
        uint256 amountOut
    ) external view override returns (uint256 amountIn) {
        VirtualPoolModel memory vPool = getVirtualPool(jkPair, ikPair);

        amountIn = vSwapLibrary.getAmountIn(
            amountOut,
            vPool.balance0,
            vPool.balance1,
            vPool.fee
        );
    }

    function getVirtualAmountOut(
        address jkPair,
        address ikPair,
        uint256 amountIn
    ) external view override returns (uint256 amountOut) {
        VirtualPoolModel memory vPool = getVirtualPool(jkPair, ikPair);

        amountOut = vSwapLibrary.getAmountOut(
            amountIn,
            vPool.balance0,
            vPool.balance1,
            vPool.fee
        );
    }

    function getVirtualPools(
        address token0,
        address token1
    ) external view override returns (VirtualPoolModel[] memory vPools) {
        vPools = IvPoolManager(IvPairFactory(factory).vPoolManager())
            .getVirtualPools(token0, token1);
    }

    function getVirtualPool(
        address jkPair,
        address ikPair
    ) public view override returns (VirtualPoolModel memory vPool) {
        vPool = IvPoolManager(IvPairFactory(factory).vPoolManager())
            .getVirtualPool(jkPair, ikPair);
    }

    function quote(
        address inputToken,
        address outputToken,
        uint256 amountIn
    ) external view override returns (uint256 amountOut) {
        IvPair pair = IvPair(getPairAddress(inputToken, outputToken));

        (uint256 balance0, uint256 balance1) = pair.getBalances();

        (balance0, balance1) = vSwapLibrary.sortBalances(
            inputToken,
            pair.token0(),
            balance0,
            balance1
        );

        amountOut = vSwapLibrary.quote(amountIn, balance0, balance1);
    }

    function getAmountOutByPair(
        address tokenIn,
        address pairAddress,
        uint256 amountIn
    ) internal view returns (uint256 amountOut) {
        IvPair pair = IvPair(pairAddress);

        (uint256 balance0, uint256 balance1) = pair.getBalances();

        (balance0, balance1) = vSwapLibrary.sortBalances(
            tokenIn,
            pair.token0(),
            balance0,
            balance1
        );

        amountOut = vSwapLibrary.getAmountOut(
            amountIn,
            balance0,
            balance1,
            pair.fee()
        );
    }

    function getAmountOut(
        address tokenIn,
        address tokenOut,
        uint256 amountIn
    ) public view virtual override returns (uint256 amountOut) {
        return getAmountOutByPair(
            tokenIn,
            getPairAddress(tokenIn, tokenOut),
            amountIn
        );
    }

    function getAmountInByPair(
        address tokenIn,
        address pairAddress,
        uint256 amountOut
    ) internal view returns (uint256 amountIn) {
        IvPair pair = IvPair(pairAddress);
        (uint256 balance0, uint256 balance1) = pair.getBalances();

        (balance0, balance1) = vSwapLibrary.sortBalances(
            tokenIn,
            pair.token0(),
            balance0,
            balance1
        );

        amountIn = vSwapLibrary.getAmountIn(
            amountOut,
            balance0,
            balance1,
            pair.fee()
        );
    }

    function getAmountIn(
        address tokenIn,
        address tokenOut,
        uint256 amountOut
    ) public view virtual override returns (uint256 amountIn) {
        return getAmountInByPair(
            tokenIn,
            getPairAddress(tokenIn, tokenOut),
            amountOut
        );
    }

    function getMaxVirtualTradeAmountRtoN(
        address jkPair,
        address ikPair
    ) external view override returns (uint256 maxAmountIn) {
        VirtualPoolModel memory vPool = getVirtualPool(jkPair, ikPair);
        maxAmountIn = vSwapLibrary.getMaxVirtualTradeAmountRtoN(vPool);
    }

    function changeFactory(
        address _factory
    ) external override _onlyFactoryAdmin {
        require(
            _factory > address(0) && _factory != factory,
            'VSWAP:INVALID_FACTORY'
        );
        factory = _factory;

        emit RouterFactoryChanged(_factory);
    }
}
