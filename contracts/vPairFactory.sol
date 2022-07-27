 pragma solidity ^0.8.0;  

import "./interfaces/IvPairFactory.sol";
import "./vPair.sol";

contract vPairFactory is IvPairFactory {
    mapping(address => mapping(address => address)) public pairs;
    address[] public allPairs;

    address public immutable override admin;

    uint256 max_reserve_ratio_default;
    uint256 max_whitelist_count_default;
    uint256 pair_fee_default;
    uint256 pair_vfee_default;

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

    function setMaxWhitelistCount(uint256 _max_whitelist_count_default)
        external
        override
        onlyAdmin
    {
        max_whitelist_count_default = _max_whitelist_count_default;
    }

    function setPairFeeDefault(uint256 _pair_fee_default)
        external
        override
        onlyAdmin
    {
        pair_fee_default = _pair_fee_default;
    }

    function setPairVFeeDefault(uint256 _pair_vfee_default)
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

        (address token0, address token1) = tokenA < tokenB
            ? (tokenA, tokenB)
            : (tokenB, tokenA);

        require(token0 != address(0), "VSWAP: ZERO_ADDRESS");

        require(pairs[token0][token1] == address(0), "VSWAP: PAIR_EXISTS");

        vPair newPair = new vPair(
            address(this),
            token0,
            token1,
            pair_fee_default,
            pair_vfee_default,
            max_reserve_ratio_default,
            max_whitelist_count_default
        );

        pairs[token0][token1] = address(newPair);
        pairs[token1][token0] = address(newPair);
        allPairs.push(address(newPair));

        emit PairCreated(address(newPair), address(this), token0, token1);

        return address(newPair);
    }
}
