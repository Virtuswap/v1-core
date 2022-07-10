pragma solidity =0.8.1;

import "./interfaces/IvPairFactory.sol";
import "./vPair.sol";

contract vPairFactory is IvPairFactory {
    mapping(address => mapping(address => address)) public pairs;
    address[] public allPairs;

    address public immutable override admin;

    modifier onlyAdmin() {
        require(msg.sender == admin);
        _;
    }

    constructor() {
        admin = msg.sender;
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
            997,
            996,
            2000
        ); // 997 = 0.03%

        pairs[token0][token1] = address(newPair);
        pairs[token1][token0] = address(newPair);
        allPairs.push(address(newPair));

        emit PairCreated(address(newPair), address(this), token0, token1);

        return address(newPair);
    }
}
