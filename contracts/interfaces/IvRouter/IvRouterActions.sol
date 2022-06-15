import "../../types.sol";

interface IvRouterActions {
    // function swap(
    //     address[] calldata pools,
    //     uint256[] calldata amountsIn,
    //     uint256[] calldata amountsOut,
    //     address[] calldata iks,
    //     address inputToken,
    //     address outputToken,
    //     address to
    // ) external;

    function testNative(
        address inputToken,
        address outputToken,
        uint256 amountIn,
        uint256 amountOutMin
    ) external;

    function addLiquidity(
        address tokenA,
        address tokenB,
        uint256 amountADesired,
        uint256 amountBDesired,
        uint256 amountAMin,
        uint256 amountBMin,
        address to,
        uint256 deadline
    )
        external
        returns (
            uint256 amountA,
            uint256 amountB,
            uint256 liquidity
        );

    function addLiquidityETH(
        address token,
        uint256 amountTokenDesired,
        uint256 amountTokenMin,
        uint256 amountETHMin,
        address to,
        uint256 deadline
    )
        external
        payable
        returns (
            uint256 amountToken,
            uint256 amountETH,
            uint256 liquidity
        );
}
