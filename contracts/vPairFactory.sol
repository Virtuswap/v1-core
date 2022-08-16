// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "./vPair.sol";
import "./interfaces/IvPairFactory.sol";
import "./interfaces/IvSwapPoolDeployer.sol";
import "./libraries/PoolAddress.sol";
import "./types.sol";

contract vPairFactory is IvPairFactory, IvSwapPoolDeployer {
    mapping(address => mapping(address => address)) public pairs;
    address[] public allPairs;

    address public immutable override admin;
    address public override exchangeReserves;

    PairCreationParams public override poolCreationParameters;

    modifier onlyAdmin() {
        require(msg.sender == admin, "OA");
        _;
    }

    constructor() {
        admin = msg.sender;
    }

    function getPair(address tokenA, address tokenB)
        external
        view
        override
        returns (address)
    {
        return pairs[tokenA][tokenB];
    }

    function createPair(address tokenA, address tokenB)
        external
        override
        returns (address pair)
    {
        require(tokenA != tokenB, "VSWAP: IDENTICAL_ADDRESSES");

        (address token0, address token1) = PoolAddress.orderAddresses(
            tokenA,
            tokenB
        );

        require(token0 != address(0), "VSWAP: ZERO_ADDRESS");

        require(pairs[token0][token1] == address(0), "VSWAP: PAIR_EXISTS");

        poolCreationParameters = PairCreationParams({
            factory: address(this),
            token0: token0,
            token1: token1,
            fee: 997,
            vFee: 997,
            max_whitelist_count: 8,
            max_reserve_ratio: 2000 * 1e18
        });

        bytes32 _salt = PoolAddress.getSalt(token0, token1);
        pair = address(new vPair{salt: _salt}());

        delete poolCreationParameters;

        pairs[token0][token1] = pair;
        pairs[token1][token0] = pair;
        allPairs.push(pair);

        emit PairCreated(pair, address(this), token0, token1);

        return pair;
    }

    function setExchangeReservesAddress(address _exchangeReserves)
        external
        onlyAdmin
    {
        exchangeReserves = _exchangeReserves;
    }

    function getInitCodeHash() public pure returns (bytes32) {
        return keccak256(abi.encodePacked(type(vPair).creationCode));
    }
}
