pragma solidity =0.8.1;

interface IvPair {
    event Mint(address indexed sender, uint256 amount0, uint256 amount1);

    event Burn(
        address indexed sender,
        uint256 amount0,
        uint256 amount1,
        address indexed to
    );

    event WhitelistChanged(address[] tokens);

    event Sync(uint256 balance0, uint256 balance1);

    function fee() external view returns (uint256);

    function vFee() external view returns (uint256);

    function setFee(uint256 _fee, uint256 _vFee) external;

    function swapNative(
        uint256 amountOut,
        address tokenOut,
        address to,
        bytes calldata data
    ) external;

    function swapReserves(
        uint256 amountOut,
        address ikPair,
        address to,
        bytes calldata data
    ) external;

    function exchangeReserve(
        uint256 amountOut,
        address ikPair,
        address to,
        bytes calldata data
    ) external;

    function mint(address to) external returns (uint256 liquidity);

    function burn(address to)
        external
        returns (uint256 amount0, uint256 amount1);

    function setWhitelist(address[] memory _whitelist) external;

    function calculateReserveRatio() external view returns (uint256 rRatio);

    function setMaxReserveThreshold(uint256 threshold) external;

    function token0() external view returns (address);

    function token1() external view returns (address);

    function reserve0() external view returns (uint256);

    function reserve1() external view returns (uint256);

    function getReserves()
        external
        view
        returns (uint256 _reserve0, uint256 _reserve1);

    function getTokens()
        external
        view
        returns (address _token0, address _token1);
}
