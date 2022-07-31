pragma solidity ^0.8.0;

import "./interfaces/IvPairFactory.sol";
import "./vPair.sol";
import "./vSwapPoolDeployer.sol";
import "./libraries/PoolAddress.sol";

contract vPairFactory is IvPairFactory, vSwapPoolDeployer {
    mapping(address => mapping(address => address)) public pairs;
    address[] public allPairs;

    address public immutable override admin;

    uint256 max_reserve_ratio_default;
    uint24 max_whitelist_count_default;
    uint24 pair_fee_default;
    uint24 pair_vfee_default;

    modifier onlyAdmin() {
        require(msg.sender == admin);
        _;
    }

    constructor() {
        admin = msg.sender;
        max_reserve_ratio_default = 2000 * 1e18;
        max_whitelist_count_default = 8;
        pair_fee_default = 997;
        pair_vfee_default = 996;
    }

    function setMaxReserveThreshold(uint256 _max_reserve_ratio_default)
        external
        override
        onlyAdmin
    {
        max_reserve_ratio_default = _max_reserve_ratio_default;
    }

    function setMaxWhitelistCount(uint24 _max_whitelist_count_default)
        external
        override
        onlyAdmin
    {
        max_whitelist_count_default = _max_whitelist_count_default;
    }

    function setPairFeeDefault(uint24 _pair_fee_default)
        external
        override
        onlyAdmin
    {
        pair_fee_default = _pair_fee_default;
    }

    function setPairVFeeDefault(uint24 _pair_vfee_default)
        external
        override
        onlyAdmin
    {
        pair_vfee_default = _pair_vfee_default;
    }

    function allPairsLength() external view override returns (uint256) {
        return allPairs.length;
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
        returns (address)
    {
        require(tokenA != tokenB, "VSWAP: IDENTICAL_ADDRESSES");

        (address token0, address token1) = PoolAddress.orderAddresses(
            tokenA,
            tokenB
        );

        require(token0 != address(0), "VSWAP: ZERO_ADDRESS");

        require(pairs[token0][token1] == address(0), "VSWAP: PAIR_EXISTS");

        address pair = deployPair(
            address(this),
            token0,
            token1,
            pair_fee_default,
            pair_vfee_default,
            max_whitelist_count_default,
            max_reserve_ratio_default
        );

        pairs[token0][token1] = pair;
        pairs[token1][token0] = pair;
        allPairs.push(pair);

        emit PairCreated(pair, address(this), token0, token1);

        return pair;
    }

    //PROD: remove this function TBD
    function getInitCodeHash() public pure returns (bytes32) {
        return keccak256(abi.encode(type(vPair).creationCode));
    }
}
