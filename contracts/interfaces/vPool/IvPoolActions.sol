import "../../types.sol";

interface IvPoolActions {
    function swap(
        address[] calldata pools,
        uint256[] calldata amountsIn,
        uint256[] calldata amountsOut,
        bool[] calldata isReserve,
        address[] calldata iks,
        address inputToken,
        address outputToken
    ) external;
}
