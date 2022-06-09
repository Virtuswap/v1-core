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
        address poolAddress,
        address inputToken,
        address outputToken,
        uint256 amount,
        bytes calldata data
    ) external;

    function testReserve(
        address poolAddress,
        address tokenIn,
        uint256 amount,
        uint256 minAmountOut,
        address ikPool,
        address to,
        bytes calldata data
    ) external;
}
