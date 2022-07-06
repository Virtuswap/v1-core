pragma solidity ^0.8.15;

interface IvRouterState {
    function changeFactory(address factory) external;

    function factory() external view returns (address);

    function WETH() external view returns (address);

    function owner() external view returns (address);
}
