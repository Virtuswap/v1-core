pragma solidity =0.8.1;

interface IvPairReservesManager {
    function setWhitelist(address[] memory _whitelist) external;

    function calculateReserveRatio() external view returns (uint256 rRatio);

    function setMaxReserveThreshold(uint256 threshold) external;
}
