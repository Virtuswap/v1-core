pragma solidity >=0.4.22 <0.9.0;

import "./vPool/IvPoolEvents.sol";
import "./vPool/IvPoolState.sol";
import "./vPool/IvPoolActions.sol";

interface IvPool is IvPoolEvents, IvPoolState, IvPoolActions {}
