pragma solidity >=0.5.0;

import "./vPair/IvPairState.sol";
import "./vPair/IvPairEvents.sol";
import "./vPair/IvPairReservesManager.sol";
import "./vPair/IvPairFee.sol";

interface IvPair is
    IvPairState,
    IvPairEvents,
    IvPairReservesManager,
    IvPairFee
{}
