// SPDX-License-Identifier: Apache-2.0

pragma solidity 0.8.2;

import './vPair.sol';
import './interfaces/IvPair.sol';
import './interfaces/IvPairFactory.sol';
import './interfaces/IvSwapPoolDeployer.sol';
import './libraries/PoolAddress.sol';
import './types.sol';

contract vPairFactory is IvPairFactory, IvSwapPoolDeployer {
    mapping(address => mapping(address => address)) public pairs;
    address[] public override allPairs;

    address public override admin;
    address public override pendingAdmin;
    address public override exchangeReserves;
    address public override vPoolManager;

    address[] defaultAllowList;

    PoolCreationDefaults public override poolCreationDefaults;

    modifier onlyAdmin() {
        require(msg.sender == admin, 'OA');
        _;
    }

    constructor() {
        admin = msg.sender;
    }

    function getPair(
        address tokenA,
        address tokenB
    ) external view override returns (address) {
        return pairs[tokenA][tokenB];
    }

    function createPair(
        address tokenA,
        address tokenB
    ) external override returns (address pair) {
        require(tokenA != tokenB, 'VSWAP: IDENTICAL_ADDRESSES');

        (address token0, address token1) = PoolAddress.orderAddresses(
            tokenA,
            tokenB
        );

        require(token0 != address(0), 'VSWAP: ZERO_ADDRESS');

        require(pairs[token0][token1] == address(0), 'VSWAP: PAIR_EXISTS');

        poolCreationDefaults = PoolCreationDefaults({
            factory: address(this),
            token0: token0,
            token1: token1,
            fee: 997,
            vFee: 997,
            maxAllowListCount: uint24(defaultAllowList.length),
            maxReserveRatio: 2000
        });

        bytes32 _salt = PoolAddress.getSalt(token0, token1);
        pair = address(new vPair{salt: _salt}());

        delete poolCreationDefaults;

        IvPair(pair).setAllowList(defaultAllowList);

        pairs[token0][token1] = pair;
        pairs[token1][token0] = pair;
        allPairs.push(pair);

        emit PairCreated(pair, address(this), token0, token1, 997, 997, 2000);

        return pair;
    }

    function setExchangeReservesAddress(
        address _exchangeReserves
    ) external override onlyAdmin {
        require(
            _exchangeReserves > address(0),
            'VSWAP:INVALID_EXCHANGE_RESERVE_ADDRESS'
        );
        exchangeReserves = _exchangeReserves;

        emit ExchangeReserveAddressChanged(_exchangeReserves);
    }

    function setVPoolManagerAddress(address _vPoolManager) external override onlyAdmin {
        require(
            _vPoolManager > address(0),
            'VSWAP:INVALID_VPOOL_MANAGER_ADDRESS'
        );
        vPoolManager = _vPoolManager;
    }

    function setPendingAdmin(
        address newPendingAdmin
    ) external override onlyAdmin {
        pendingAdmin = newPendingAdmin;
        emit FactoryNewPendingAdmin(newPendingAdmin);
    }

    function acceptAdmin() external override {
        require(
            msg.sender != address(0) && msg.sender == pendingAdmin,
            'Only for pending admin'
        );
        admin = pendingAdmin;
        pendingAdmin = address(0);
        emit FactoryNewAdmin(admin);
    }

    function setDefaultAllowList(
        address[] calldata _defaultAllowList
    ) external override onlyAdmin {
        defaultAllowList = _defaultAllowList;
        emit DefaultAllowListChanged(_defaultAllowList);
    }

    function allPairsLength() external view override returns (uint256) {
        return allPairs.length;
    }

    function getInitCodeHash() external pure returns (bytes32) {
        return keccak256(abi.encodePacked(type(vPair).creationCode));
    }
}
