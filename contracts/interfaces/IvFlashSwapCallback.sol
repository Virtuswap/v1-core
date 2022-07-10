pragma solidity =0.8.1;

interface IvFlashSwapCallback {
    function vFlashSwapCallback(
        address sender,
        uint256 amount,
        uint256 requiredBackAmount,
        address tokenIn,
        bytes memory data
    ) external;
}
