pragma solidity ^0.8.0;

interface IvFlashSwapCallback {
    function vFlashSwapCallback(
        address sender,
        uint256 amountOut,
        uint256 requiredBackAmount,
        bytes memory data
    ) external;
}
