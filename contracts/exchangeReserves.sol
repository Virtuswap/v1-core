// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@uniswap/lib/contracts/libraries/TransferHelper.sol";

import "./types.sol";
import "./libraries/vSwapLibrary.sol";
import "./interfaces/IvPair.sol";
import "./interfaces/IvRouter.sol";
import "./interfaces/IvPairFactory.sol";
import "./interfaces/IvFlashSwapCallback.sol";

contract exchangeReservesWrapper is IvFlashSwapCallback {
    address factory;
    address router;

    address tokenA;
    address tokenB;
    address tokenC;

    constructor(
        address _factory,
        address _router,
        address _tokenA,
        address _tokenB,
        address _tokenC
    ) {
        factory = _factory;
        router = _router;
        tokenA = _tokenA;
        tokenB = _tokenB;
        tokenC = _tokenC;
    }

    function vFlashSwapCallback(
        address sender,
        uint256 amount,
        uint256 requiredBackAmount,
        bytes memory data
    ) external override {
        //call nativeToReserve swap on pool BC get out token A for C input
        //payback A to pool AB flashswap
    }

    function exchangeReserves() external {
        // A/B : 100/200 (C-1.3A)
        // A/C : 100/400
        // B/C : 200/400 (A-2B)

        address jkPool = IvPairFactory(factory).getPair(tokenA, tokenB);

        address ikPool = IvPairFactory(factory).getPair(tokenC, tokenB);

        //call reservesBaseValue on pool AB. get value of C in A tokens. (1.3A)
        uint256 reserveBalance = IvPair(jkPool).reserves(tokenC);

        //call getVirtualAmountOut on pool BC to get amount out of A for C input. assert 1.3
        uint256 amountInA = IvRouter(router).getVirtualAmountOut(
            jkPool,
            ikPool,
            reserveBalance
        );

        bytes memory encodedAddress = abi.encodePacked(msg.sender);

        //call nativeToReserve flashswap on pool AB. take out C reserve
        IvPair(jkPool).swapNativeToReserve(
            reserveBalance,
            ikPool,
            address(this),
            encodedAddress
        );
    }
}
