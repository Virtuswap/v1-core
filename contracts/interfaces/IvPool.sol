pragma solidity >=0.4.22 <0.9.0;

import "../types.sol";

interface IvPool {
    function CalculateVirtualPool(address[] memory ks, address[] memory js)
        external
        returns (virtualPoolModel memory vPool);

    function CalculateTotalPool(
        uint256[] memory ks,
        uint256[] memory js,
        address vPairAddress
    ) external view returns (virtualPoolModel memory);

    function Quote(
        uint256[] memory ks,
        uint256[] memory js,
        address vPairAddress,
        int256 amount
    ) external view returns (int256);

    function ChangeFactory(address factory) external;
}
