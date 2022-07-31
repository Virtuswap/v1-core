// // SPDX-License-Identifier: MIT
// pragma solidity ^0.8.0;

// import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
// import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

// import "../interfaces/IvFlashSwapCallback.sol";
// import "../interfaces/IvPair.sol";
// import "../interfaces/IvPairFactory.sol";
// import "../interfaces/IvRouter.sol";

// contract flashSwapExample is IvFlashSwapCallback {
//     address factory;
//     address router;

//     address tokenA;
//     address tokenB;
//     address tokenC;

//     constructor(
//         address _factory,
//         address _router,
//         address _tokenA,
//         address _tokenB,
//         address _tokenC
//     ) {
//         factory = _factory;
//         router = _router;
//         tokenA = _tokenA;
//         tokenB = _tokenB;
//         tokenC = _tokenC;
//     }

//     function decodeAddress(bytes memory data)
//         internal
//         pure
//         returns (address _address)
//     {
//         bytes memory b = data;
//         assembly {
//             _address := mload(add(b, 20))
//         }
//     }

//     //send 10 token B to A/C pool swapReserveToNative and take out A and repay flash swap
//     function vFlashSwapCallback(uint256 requiredBackAmount, bytes memory data)
//         external
//         override
//     {
//         (address token0, address token1) = IvPair(msg.sender).getTokens();
//         address poolAddress = IvPairFactory(factory).getPair(token0, token1);

//         require(msg.sender == poolAddress, "VSWAP:INVALID_POOL"); // ensure that msg.sender is actually a registered pair

//         address ik = IvPairFactory(factory).getPair(tokenB, tokenC);
//         address jk = IvPairFactory(factory).getPair(tokenA, tokenC);

//         uint256 vAmountIn = IvRouter(router).getVirtualAmountIn(ik, jk, amount);

//         //FIX THIS LINE
//         vAmountIn = vAmountIn - 1e18;

//         address caller = decodeAddress(data);

//         SafeERC20.safeTransfer(IERC20(tokenB), jk, amount);

//         //swap B to A in virtual pool A/B
//         IvPair(jk).swapReserveToNative(
//             vAmountIn,
//             ik,
//             poolAddress,
//             new bytes(0)
//         );

//         //take delta from transaction caller
//         uint256 delta = requiredBackAmount - vAmountIn;

//         if (delta > 0) {
//             SafeERC20.safeTransferFrom(
//                 IERC20(tokenB),
//                 caller,
//                 poolAddress,
//                 delta
//             );
//         }
//     }

//     //take 10 token B out from A/B pool with a flashswap
//     function testFlashswap() external {
//         address abPoolAddress = IvPairFactory(factory).getPair(tokenA, tokenB);

//         uint256 amountOut = 10 * 1e18;

//         bytes memory encodedAddress = abi.encodePacked(msg.sender);

//         //call flashswap
//         IvPair(abPoolAddress).swapNative(
//             amountOut,
//             tokenB,
//             address(this),
//             encodedAddress
//         );
//     }
// }
