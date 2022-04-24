pragma solidity >=0.4.22 <0.9.0;

import "../types.sol";

interface IvPool {
    function calculateVirtualPool(address[] memory ks, address[] memory js)
        external
        returns (VirtualPool memory vPool);

    function calculateTotalPool(VirtualPool memory vPool, address vPairAddress)
        external
        view
        returns (VirtualPool memory);

    function calculateTotalPool(
        uint256[] memory ks,
        uint256[] memory js,
        address vPairAddress
    ) external view returns (VirtualPool memory);

    function quote(
        uint256[] memory ks,
        uint256[] memory js,
        address vPairAddress,
        int256 amount
    ) external view returns (int256);

    function changeFactory(address factory) external;
}
