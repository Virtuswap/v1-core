interface IvPair {
    event LiquidityChange(
        address poolAddress,
        uint256 tokenABalance,
        uint256 tokenBBalance
    );

    function setWhitelistAllowance(address reserveToken, bool activateReserve)
        external;

    function isReserveAllowed(address reserveToken)
        external
        view
        returns (bool);

    function withdrawal() external;

    function quote(
        address inToken,
        address outToken,
        uint256 amount
    ) external;

    function swap(
        address inToken,
        address outToken,
        uint256 amount,
        address reserveToken,
        address reserveRPool
    ) external;

    function collect(uint256 tokenAAmount, uint256 tokenBAmount) external;

    function getBelowReserve() external pure returns (uint256);

    function token0() external view returns (address);

    function token1() external view returns (address);

    function fee() external view returns (uint256);
}
