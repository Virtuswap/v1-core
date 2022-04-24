pragma solidity >=0.4.22 <0.9.0;

import "./interfaces/IvPairFactory.sol";
import "./vPair.sol";
import "./ERC20/IERC20.sol";

contract vPairFactory is IvPairFactory {
    mapping(address => mapping(address => address)) public getPair;
    address[] public allPairs;

    constructor() {}

    function allPairsLength() external view returns (uint256) {
        return allPairs.length;
    }

    function getPairAddress(address tokenA, address tokenB)
        external
        view
        returns (address)
    {
        return getPair[tokenA][tokenB];
    }

    function createPair(
        address tokenA,
        address tokenB,
        address[] memory whitelist
    ) external {
        require(tokenA != tokenB, "vSwap: IDENTICAL_ADDRESSES");

        (address token0, address token1) = tokenA < tokenB
            ? (tokenA, tokenB)
            : (tokenB, tokenA);

        require(token0 != address(0), "vSwap: ZERO_ADDRESS");

        require(getPair[token0][token1] == address(0), "vSwap: PAIR_EXISTS");

        vPair newPair = new vPair(
            msg.sender,
            address(this),
            tokenA,
            tokenB,
            whitelist
        );

        address pairAddress = address(newPair);

        getPair[token0][token1] = pairAddress;
        getPair[token1][token0] = pairAddress;
        allPairs.push(pairAddress);

        emit PairCreated(
            pairAddress,
            msg.sender,
            address(this),
            tokenA,
            tokenB,
            whitelist
        );
    }
}
