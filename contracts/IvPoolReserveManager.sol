 pragma solidity >=0.4.22 <0.9.0;
interface IvPoolReserveManager {
    function activateReserveToWhitelist(
        uint256 rPoolIndex,
        address reserveToken,
        bool activateReserve
    ) external;

    function isReserveAllowedInPool(uint256 rPoolIndex, address reserveToken)
        external
        view
        returns (bool);

    function getPoolReserveBalance(uint256 rpoolIndex, address reserveToken)
        external
        view
        returns (int256);

    function updateReserveBalance(
        uint256 rpoolIndex,
        address reserveToken,
        int256 newReserveBalance
    ) external;
}
