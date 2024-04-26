// SPDX-License-Identifier: Apache-2.0

pragma solidity ^0.8.18;

interface IvPairFactory {
    event PairCreated(
        address poolAddress,
        address factory,
        address token0,
        address token1,
        uint16 fee,
        uint16 vFee,
        uint256 maxReserveRatio
    );

    event DefaultAllowListChanged(address[] allowList);

    event FactoryNewAdmin(address newAdmin);
    event FactoryNewPendingAdmin(address newPendingAdmin);

    event FactoryNewEmergencyAdmin(address newEmergencyAdmin);
    event FactoryNewPendingEmergencyAdmin(address newPendingEmergencyAdmin);

    event ExchangeReserveAddressChanged(address newExchangeReserve);

    event FactoryVPoolManagerChanged(address newVPoolManager);

    function createPair(
        address tokenA,
        address tokenB
    ) external returns (address);

    function pairs(
        address tokenA,
        address tokenB
    ) external view returns (address);

    function setDefaultAllowList(address[] calldata _defaultAllowList) external;

    function allPairs(uint256 index) external view returns (address);

    function allPairsLength() external view returns (uint256);

    function vPoolManager() external view returns (address);

    function admin() external view returns (address);

    function emergencyAdmin() external view returns (address);

    function pendingEmergencyAdmin() external view returns (address);

    function setPendingEmergencyAdmin(address newEmergencyAdmin) external;

    function acceptEmergencyAdmin() external;

    function pendingAdmin() external view returns (address);

    function setPendingAdmin(address newAdmin) external;

    function setVPoolManagerAddress(address _vPoolManager) external;

    function acceptAdmin() external;

    function exchangeReserves() external view returns (address);

    function setExchangeReservesAddress(address _exchangeReserves) external;
}
