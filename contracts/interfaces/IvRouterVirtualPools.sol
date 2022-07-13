pragma solidity =0.8.1;
import "../types.sol";

interface IvRouterVirtualPools {
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
