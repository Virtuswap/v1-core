pragma solidity ^0.8.0;

import "./IvRouter/IvRouterEvents.sol";
import "./IvRouter/IvRouterState.sol";
import "./IvRouter/IvRouterActions.sol";

interface IvRouter is IvRouterEvents, IvRouterState, IvRouterActions {}
