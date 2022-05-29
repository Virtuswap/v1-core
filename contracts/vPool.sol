// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./types.sol";
import "./ERC20/IERC20.sol";
import "./libraries/SafeERC20.sol";
import "./libraries/vSwapMath.sol";
import "./interfaces/IvPair.sol";
import "./interfaces/IvPairFactory.sol";
import "./interfaces/IvPool.sol";

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
        address ikPairAddress,
        address to
    ) external {
        SafeERC20.safeTransferFrom(
            IERC20(tokenIn),
            msg.sender,
            poolAddress,
            amount
        );

        IvPair(poolAddress).swapReserves(
            tokenIn,
            tokenOut,
            minAmountOut,
            ikPairAddress,
            to
        );
    }

    function swap(
        address[] calldata pools,
        uint256[] calldata amountsIn,
        uint256[] calldata amountsOut,
        address[] calldata iks, 
        address inputToken,
        address outputToken
    ) external {
        for (uint256 i = 0; i < pools.length; i++) {
            if (iks[i] == address(0)) {
                //real pool
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
                    iks[i],
                    msg.sender
                );
            }
        }
    }

    function changeFactory(address _factory) external onlyOwner {
        factory = _factory;
    }
}
