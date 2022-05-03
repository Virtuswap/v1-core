pragma solidity >=0.5.0;

import "./vPairFactory/IvPoolFactoryVPoolManager.sol";
import "./vPairFactory/IvPairFactoryEvents.sol";
import "./vPairFactory/IvPairFactoryActions.sol";
import "./vPairFactory/IvPairFactoryPairs.sol";

interface IvPairFactory is
    IvPairFactoryEvents,
    IvPoolFactoryVPoolManager,
    IvPairFactoryActions,
    IvPairFactoryPairs
{}
