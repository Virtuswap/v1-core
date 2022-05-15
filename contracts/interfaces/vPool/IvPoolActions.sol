import "../../types.sol";

interface IvPoolActions {
    function Quote(
        address[] memory iks,
        address[] memory jks,
        uint256 amount
    ) external view returns (uint256);

    function Swap(
        address[] memory iks,
        address[] memory jks,
        uint256 amount
    ) external;

    function swapTest(
        address tokenIn,
        address pairAddress,
        uint256 amount,
        uint256 amountOut
    ) external;
}
