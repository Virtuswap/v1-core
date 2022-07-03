interface IvPairReservesManager {
    function setWhitelist(address[] memory _whitelist) external;

    function calculateReserveRatio() external view returns (uint256 rRatio);
}
