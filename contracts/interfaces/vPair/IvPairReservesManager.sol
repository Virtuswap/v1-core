interface IvPairReservesManager {
    function setWhitelist(address[] memory _whitelist) external;

    function isReserveAllowed(address reserveToken)
        external
        view
        returns (bool);

    function calculateReserveRatio() external view returns (uint256 rRatio);
}
