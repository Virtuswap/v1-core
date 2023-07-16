// SPDX-License-Identifier: Apache-2.0

pragma solidity 0.8.18;

import '@openzeppelin/contracts/token/ERC20/IERC20.sol';
import '@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol';
import '@openzeppelin/contracts/utils/Multicall.sol';
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

contract vRouter is IvRouter, Multicall {
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

    function getPair(
        address tokenA,
        address tokenB
    ) internal view returns (IvPair) {
        return IvPair(getPairAddress(tokenA, tokenB));
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
        amountsIn = new uint[](path.length);
        amountsIn[amountsIn.length - 1] = amountOut;
        for (uint i = path.length - 1; i > 0; --i) {
            amountsIn[i - 1] = getAmountIn(path[i - 1], path[i], amountsIn[i]);
        }
    }

    function getAmountsOut(
        address[] memory path,
        uint256 amountIn
    ) public view returns (uint[] memory amountsOut) {
        amountsOut = new uint[](path.length);
        amountsOut[0] = amountIn;
        for (uint i = 1; i < amountsOut.length; ++i) {
            amountsOut[i] = getAmountOut(
                path[i - 1],
                path[i],
                amountsOut[i - 1]
            );
        }
    }

    function swapExactETHForTokens(
        address[] memory path,
        uint256 amountIn,
        uint256 minAmountOut,
        address to,
        uint256 deadline
    ) external payable override notAfter(deadline) {
        require(path[0] == WETH9, 'VSWAP: INPUT TOKEN MUST BE WETH9');
        uint[] memory amountsOut = getAmountsOut(path, amountIn);
        require(
            amountsOut[amountsOut.length - 1] >= minAmountOut,
            'VSWAP: INSUFFICIENT_INPUT_AMOUNT'
        );
        transferETHInput(amountsOut[0], getPairAddress(path[0], path[1]));
        swap(path, amountsOut, to);
    }

    function swapExactTokensForETH(
        address[] memory path,
        uint256 amountIn,
        uint256 minAmountOut,
        address to,
        uint256 deadline
    ) external override notAfter(deadline) {
        require(
            path[path.length - 1] == WETH9,
            'VSWAP: OUTPUT TOKEN MUST BE WETH9'
        );
        uint[] memory amountsOut = getAmountsOut(path, amountIn);
        require(
            amountsOut[amountsOut.length - 1] >= minAmountOut,
            'VSWAP: INSUFFICIENT_INPUT_AMOUNT'
        );
        transferInput(path[0], amountsOut[0], getPairAddress(path[0], path[1]));
        swap(path, amountsOut, address(this));
        unwrapTransferETH(to, amountsOut[amountsOut.length - 1]);
    }

    function swapETHForExactTokens(
        address[] memory path,
        uint256 amountOut,
        uint256 maxAmountIn,
        address to,
        uint256 deadline
    ) external payable override notAfter(deadline) {
        require(path[0] == WETH9, 'VSWAP: INPUT TOKEN MUST BE WETH9');
        uint[] memory amountsIn = getAmountsIn(path, amountOut);
        require(amountsIn[0] <= maxAmountIn, 'VSWAP: REQUIRED_AMOUNT_EXCEEDS');
        transferETHInput(amountsIn[0], getPairAddress(path[0], path[1]));
        swap(path, amountsIn, to);
    }

    function swapTokensForExactETH(
        address[] memory path,
        uint256 amountOut,
        uint256 maxAmountIn,
        address to,
        uint256 deadline
    ) external override notAfter(deadline) {
        require(
            path[path.length - 1] == WETH9,
            'VSWAP: OUTPUT TOKEN MUST BE WETH9'
        );
        uint[] memory amountsIn = getAmountsIn(path, amountOut);
        require(amountsIn[0] <= maxAmountIn, 'VSWAP: REQUIRED_AMOUNT_EXCEEDS');
        transferInput(path[0], amountsIn[0], getPairAddress(path[0], path[1]));
        swap(path, amountsIn, address(this));
        unwrapTransferETH(to, amountsIn[amountsIn.length - 1]);
    }

    function swapReserveETHForExactTokens(
        address tokenOut,
        address commonToken,
        address ikPair,
        uint256 amountOut,
        uint256 maxAmountIn,
        address to,
        uint256 deadline
    ) external payable override notAfter(deadline) {
        (address ik0, address ik1) = IvPair(ikPair).getTokens();
        address tokenIn = ik0 == commonToken ? ik1 : ik0;
        require(tokenIn == WETH9, 'VSWAP: INPUT TOKEN MUST BE WETH9');
        address jkAddress = getPairAddress(tokenOut, commonToken);
        uint256 amountIn = getVirtualAmountIn(jkAddress, ikPair, amountOut);
        require(amountIn <= maxAmountIn, 'VSWAP: REQUIRED_VINPUT_EXCEED');
        transferETHInput(amountIn, jkAddress);
        swapReserve(amountOut, jkAddress, ikPair, to);
    }

    function swapReserveTokensForExactETH(
        address tokenOut,
        address commonToken,
        address ikPair,
        uint256 amountOut,
        uint256 maxAmountIn,
        address to,
        uint256 deadline
    ) external override notAfter(deadline) {
        require(tokenOut == WETH9, 'VSWAP: OUTPUT TOKEN MUST BE WETH9');
        (address ik0, address ik1) = IvPair(ikPair).getTokens();
        address tokenIn = ik0 == commonToken ? ik1 : ik0;
        address jkAddress = getPairAddress(tokenOut, commonToken);
        uint256 amountIn = getVirtualAmountIn(jkAddress, ikPair, amountOut);
        require(amountIn <= maxAmountIn, 'VSWAP: REQUIRED_VINPUT_EXCEED');
        transferInput(tokenIn, amountIn, jkAddress);
        swapReserve(amountOut, jkAddress, ikPair, address(this));
        unwrapTransferETH(to, amountOut);
    }

    function swapReserveExactTokensForETH(
        address tokenOut,
        address commonToken,
        address ikPair,
        uint256 amountIn,
        uint256 minAmountOut,
        address to,
        uint256 deadline
    ) external override notAfter(deadline) {
        require(tokenOut == WETH9, 'VSWAP: OUTPUT TOKEN MUST BE WETH9');
        (address ik0, address ik1) = IvPair(ikPair).getTokens();
        address tokenIn = ik0 == commonToken ? ik1 : ik0;
        address jkAddress = getPairAddress(tokenOut, commonToken);
        uint256 amountOut = getVirtualAmountOut(jkAddress, ikPair, amountIn);
        require(
            amountOut >= minAmountOut,
            'VSWAP: INSUFFICIENT_VOUTPUT_AMOUNT'
        );
        transferInput(tokenIn, amountIn, jkAddress);
        swapReserve(amountOut, jkAddress, ikPair, address(this));
        unwrapTransferETH(to, amountOut);
    }

    function swapReserveExactETHForTokens(
        address tokenOut,
        address commonToken,
        address ikPair,
        uint256 amountIn,
        uint256 minAmountOut,
        address to,
        uint256 deadline
    ) external payable override notAfter(deadline) {
        (address ik0, address ik1) = IvPair(ikPair).getTokens();
        address tokenIn = ik0 == commonToken ? ik1 : ik0;
        require(tokenIn == WETH9, 'VSWAP: INPUT TOKEN MUST BE WETH9');
        address jkAddress = getPairAddress(tokenOut, commonToken);
        uint256 amountOut = getVirtualAmountOut(jkAddress, ikPair, amountIn);
        require(
            amountOut >= minAmountOut,
            'VSWAP: INSUFFICIENT_VOUTPUT_AMOUNT'
        );
        transferETHInput(amountIn, jkAddress);
        swapReserve(amountOut, jkAddress, ikPair, to);
    }

    function swapTokensForExactTokens(
        address[] memory path,
        uint256 amountOut,
        uint256 maxAmountIn,
        address to,
        uint256 deadline
    ) external override notAfter(deadline) {
        uint[] memory amountsIn = getAmountsIn(path, amountOut);
        require(amountsIn[0] <= maxAmountIn, 'VSWAP: REQUIRED_AMOUNT_EXCEEDS');
        transferInput(path[0], amountsIn[0], getPairAddress(path[0], path[1]));
        swap(path, amountsIn, to);
    }

    function swapExactTokensForTokens(
        address[] memory path,
        uint256 amountIn,
        uint256 minAmountOut,
        address to,
        uint256 deadline
    ) external override notAfter(deadline) {
        uint[] memory amountsOut = getAmountsOut(path, amountIn);
        require(
            amountsOut[amountsOut.length - 1] >= minAmountOut,
            'VSWAP: INSUFFICIENT_INPUT_AMOUNT'
        );
        transferInput(path[0], amountsOut[0], getPairAddress(path[0], path[1]));
        swap(path, amountsOut, to);
    }

    function swapReserveTokensForExactTokens(
        address tokenOut,
        address commonToken,
        address ikPair,
        uint256 amountOut,
        uint256 maxAmountIn,
        address to,
        uint256 deadline
    ) external override notAfter(deadline) {
        (address ik0, address ik1) = IvPair(ikPair).getTokens();
        address tokenIn = ik0 == commonToken ? ik1 : ik0;
        address jkAddress = getPairAddress(tokenOut, commonToken);
        uint256 amountIn = getVirtualAmountIn(jkAddress, ikPair, amountOut);
        require(amountIn <= maxAmountIn, 'VSWAP: REQUIRED_VINPUT_EXCEED');
        transferInput(tokenIn, amountIn, jkAddress);
        swapReserve(amountOut, jkAddress, ikPair, to);
    }

    function swapReserveExactTokensForTokens(
        address tokenOut,
        address commonToken,
        address ikPair,
        uint256 amountIn,
        uint256 minAmountOut,
        address to,
        uint256 deadline
    ) external override notAfter(deadline) {
        (address ik0, address ik1) = IvPair(ikPair).getTokens();
        address tokenIn = ik0 == commonToken ? ik1 : ik0;
        address jkAddress = getPairAddress(tokenOut, commonToken);
        uint256 amountOut = getVirtualAmountOut(jkAddress, ikPair, amountIn);
        require(
            amountOut >= minAmountOut,
            'VSWAP: INSUFFICIENT_VOUTPUT_AMOUNT'
        );
        transferInput(tokenIn, amountIn, jkAddress);
        swapReserve(amountOut, jkAddress, ikPair, to);
    }

    function transferETHInput(uint amountIn, address pair) internal {
        require(
            address(this).balance >= amountIn,
            'VSWAP: INSUFFICIENT_ETH_INPUT_AMOUNT'
        );
        IWETH9(WETH9).deposit{value: amountIn}();
        SafeERC20.safeTransfer(IERC20(WETH9), pair, amountIn);
        (bool success, ) = msg.sender.call{value: address(this).balance}('');
        require(success, 'VSWAP: TRANSFER FAILED');
    }

    function transferInput(
        address token,
        uint amountIn,
        address pair
    ) internal {
        SafeERC20.safeTransferFrom(IERC20(token), msg.sender, pair, amountIn);
    }

    function swap(
        address[] memory path,
        uint[] memory amounts,
        address to
    ) internal {
        for (uint i = 0; i < path.length - 1; ++i) {
            getPair(path[i], path[i + 1]).swapNative(
                amounts[i + 1],
                path[i + 1],
                i == path.length - 2
                    ? to
                    : getPairAddress(path[i + 1], path[i + 2]),
                new bytes(0)
            );
        }
    }

    function swapReserve(
        uint amountOut,
        address jkAddress,
        address ikAddress,
        address to
    ) internal {
        IvPair(jkAddress).swapReserveToNative(
            amountOut,
            ikAddress,
            to,
            new bytes(0)
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
    ) public view override returns (uint256 amountIn) {
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
    ) public view override returns (uint256 amountOut) {
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
        IvPair pair = getPair(inputToken, outputToken);

        (uint256 balance0, uint256 balance1) = pair.getBalances();

        (balance0, balance1) = vSwapLibrary.sortBalances(
            inputToken,
            pair.token0(),
            balance0,
            balance1
        );

        amountOut = vSwapLibrary.quote(amountIn, balance0, balance1);
    }

    function getAmountOut(
        address tokenIn,
        address tokenOut,
        uint256 amountIn
    ) public view virtual override returns (uint256 amountOut) {
        IvPair pair = getPair(tokenIn, tokenOut);

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

    function getAmountIn(
        address tokenIn,
        address tokenOut,
        uint256 amountOut
    ) public view virtual override returns (uint256 amountIn) {
        IvPair pair = getPair(tokenIn, tokenOut);
        (uint256 balance0, uint256 balance1) = IvPair(pair).getBalances();

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
