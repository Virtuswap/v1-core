pragma solidity ^0.8.15;

interface IvSwapCallee {
    function vSwapcallee(
        address sender,
        uint256 amount,
        uint256 requiredBackAmount,
        address tokenIn,
        bytes memory data
    ) external;
}
