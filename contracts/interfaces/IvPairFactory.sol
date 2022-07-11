 pragma solidity =0.8.1;

import "./vPairFactory/IvPairFactoryEvents.sol";
import "./vPairFactory/IvPairFactoryActions.sol";
import "./vPairFactory/IvPairFactoryPairs.sol";

interface IvPairFactory is
    IvPairFactoryEvents,
    IvPairFactoryActions,
    IvPairFactoryPairs
{}
