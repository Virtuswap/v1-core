import "../../types.sol";

interface IvPoolActions {
    function Quote(VirtualPoolRequest calldata vPoolRequest, uint256 amount)
        external
        view
        returns (uint256);

    function Swap(VirtualPoolRequest calldata vPoolRequest, uint256 amount)
        external;
}
