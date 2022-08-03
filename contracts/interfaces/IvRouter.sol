pragma solidity ^0.8.0;
import "../types.sol";
import "./IvFlashSwapCallback.sol";

interface IvRouter is IvFlashSwapCallback {
    function changeFactory(address factory) external;

    function factory() external view returns (address);

    function owner() external view returns (address);

    function swapToExactNative(
        address tokenA,
        address tokenB,
        uint256 amountOut,
        address to,
        bytes calldata data,
        uint256 deadline
    ) external;

    function swapReserveToExactNative(
        address tokenA,
        address tokenB,
        address ikPair,
        uint256 amountOut,
        address to,
        bytes calldata data,
        uint256 deadline
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
        address tokenA,
        address tokenB,
        uint256 amount
    ) external view returns (uint256 quote);

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

    function getVirtualPool(address jkPair, address ikPair)
        external
        view
        returns (VirtualPoolModel memory vPool);
}
