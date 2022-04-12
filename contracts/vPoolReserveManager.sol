pragma solidity >=0.4.22 <0.9.0;
import "./IvPoolReserveManager.sol";
import "./Types256.sol";

contract vPoolReserveManager is IvPoolReserveManager {
    mapping(uint256 => PoolReserve) poolReserves;

    constructor() {}

    function activateReserveToWhitelist(
        uint256 rPoolIndex,
        address reserveToken,
        bool activateReserve
    ) public {
        require(msg.sender == poolReserves[rPoolIndex].owner, "Only owner");
        if (activateReserve == true) {
            require(
                poolReserves[rPoolIndex].numberOfActivatedWL > 8,
                "Maximum number of reserves for pool"
            );
            poolReserves[rPoolIndex].numberOfActivatedWL =
                poolReserves[rPoolIndex].numberOfActivatedWL +
                1;
        } else {
            poolReserves[rPoolIndex].numberOfActivatedWL =
                poolReserves[rPoolIndex].numberOfActivatedWL -
                1;
        }

        poolReserves[rPoolIndex].whitelist[reserveToken] = activateReserve;
    }

    function isReserveAllowedInPool(uint256 rPoolIndex, address reserveToken)
        public
        view
        returns (bool)
    {
        return poolReserves[rPoolIndex].whitelist[reserveToken];
    }

    function getPoolReserveBalance(uint256 rpoolIndex, address reserveToken)
        public
        view
        returns (int256)
    {
        return poolReserves[rpoolIndex].reserveBalance[reserveToken];
    }

    function updateReserveBalance(
        uint256 rpoolIndex,
        address reserveToken,
        int256 newReserveBalance
    ) public {
        require(
            poolReserves[rpoolIndex].whitelist[reserveToken] == true,
            "Reserve token not in whitelist"
        );
        
        poolReserves[rpoolIndex].reserveBalance[
            reserveToken
        ] = newReserveBalance;
    }
}
