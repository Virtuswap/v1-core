 pragma solidity =0.8.1;
// // SPDX-License-Identifier: MIT
// pragma solidity =0.8.1;;
// import "../interfaces/IvSwapCallee.sol";
// import "../interfaces/IvPair.sol";
// import "../libraries/vSwapMath.sol";
// import "..//ERC20/IERC20.sol";
// import "../interfaces/IvPairFactory.sol";
// import "../interfaces/IvRouter.sol";
// import "../libraries/SafeERC20.sol";

// contract flashSwapExample is IvSwapCallee {
//     address _factory;

//     address BTC = 0xa6dd9AdD507701da0f5f279a0462fDd2f5A1E13C;
//     address USDC = 0xdE9F3aFcDb060c939Ded87b7b851E005515b1DE9;
//     address ETH = 0xaCD5165C3fC730c536cF255454fD1F5E01C36d80;

//     constructor(address factory) {
//         _factory = factory;
//     }

//     //send 1ETH to BTC/USDC pool as reserve and take out USDC. send USDC to ETH/USDC pool to settle the flashswap.
//     function vSwapcallee(
//         address sender,
//         uint256 amount,
//         uint256 requiredBackAmount,
//         address tokenIn,
//         bytes memory data
//     ) external virtual {
//         address token0 = IvPair(msg.sender).token0();
//         address token1 = IvPair(msg.sender).token1();
//         address poolAddress = IvPairFactory(_factory).getPair(token0, token1);

//         require(msg.sender == poolAddress, "VSWAP:INVALID_POOL"); // ensure that msg.sender is actually a registered pair

//         address tokenOut = tokenIn == token0 ? token1 : token0;

//         (uint256 reserve0, uint256 reserve1) = (
//             IvPair(poolAddress).reserve0(),
//             IvPair(poolAddress).reserve1()
//         );

//         uint256 bidAmount = vSwapMath.getAmountIn(
//             amount,
//             reserve0,
//             reserve1,
//             997,
//             true
//         );
//         {
//             uint256 delta = bidAmount - requiredBackAmount;

//             if (delta > 0)
//                 SafeERC20.safeTransferFrom(
//                     IERC20(tokenOut),
//                     sender,
//                     poolAddress,
//                     delta
//                 );
//         }
//         SafeERC20.safeTransfer(IERC20(tokenOut), poolAddress, amount);

//         address reserveTradePool = IvPairFactory(_factory).getPair(BTC, USDC);
//         IvPair(reserveTradePool).swapReserves(
//             bidAmount,
//             IvPairFactory(_factory).getPair(ETH, BTC),
//             poolAddress,
//             new bytes(0)
//         );
//     }

//     //tade 1ETH out from ETH/USDC pool with a flashswap
//     function testFlashSwap() external {
//         address nativePool = IvPairFactory(_factory).getPair(USDC, ETH);

//         uint256 amountOut = 1 * 1e18;

//         bytes memory data = abi.encodePacked("1");
//         IvPair(nativePool).swapNative(amountOut, ETH, address(this), data);
//     }
// }
