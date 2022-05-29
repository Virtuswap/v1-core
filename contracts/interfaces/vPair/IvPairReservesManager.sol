interface IvPairReservesManager {
    function setWhitelistAllowance(address reserveToken, bool activateReserve)
        external;

    function isReserveAllowed(address reserveToken)
        external
        view
        returns (bool);

    function getBelowReserve() external pure returns (uint256);

    function getrReserve(address token) external view returns (uint256);
}
