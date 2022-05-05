pragma solidity >=0.5.0;

import "./vPool/IvPoolEvents.sol";
import "./vPool/IvPoolState.sol";
import "./vPool/IvPoolActions.sol";

interface IvPool is IvPoolEvents, IvPoolState, IvPoolActions {}
