import "../../types.sol";

interface IvRouterActions {
    function swap(
        address[] calldata pools,
        uint256[] calldata amountsIn,
        uint256[] calldata amountsOut,
        address[] calldata iks,
        address inputToken,
        address outputToken,
        address to
    ) external;

    function testNative(
        address inputToken,
        address outputToken,
        uint256 amountIn,
        uint256 amountOutMin
    ) external;
}
