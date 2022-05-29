import "../../types.sol";

interface IvPoolActions {
    function swap(
        address[] calldata pools,
        uint256[] calldata amountsIn,
        uint256[] calldata amountsOut,
        address[] calldata iks,
        address inputToken,
        address outputToken
    ) external;

    function testNative(
        address poolAddress,
        address inputToken,
        uint256 amount
    ) external;
}
