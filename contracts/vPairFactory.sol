pragma solidity ^0.8.0;


import "./interfaces/IvPairFactory.sol";
import "./vPair.sol";
import "./ERC20/IERC20.sol";

contract vPairFactory is IvPairFactory {
    mapping(address => mapping(address => address)) public pairs;
    address[] public allPairs;

    address _admin;

    address _vPool;

    modifier onlyAdmin() {
        require(msg.sender == _admin);
        _;
    }

    constructor() {
        _admin = msg.sender;
    }

    function allPairsLength() external view returns (uint256) {
        return allPairs.length;
    }

    function getvPoolAddress() external view returns (address) {
        return _vPool;
    }

    function updateVPoolAddress(address vPool) external onlyAdmin {
        _vPool = vPool;
    }

    function getPair(address tokenA, address tokenB)
        external
        view
        returns (address)
    {
        return pairs[tokenA][tokenB];
    }

    function createPair(
        address tokenA,
        address tokenB,
        address[] memory whitelist
    ) external {
        require(tokenA != tokenB, "VSWAP: IDENTICAL_ADDRESSES");

        (address token0, address token1) = tokenA < tokenB
            ? (tokenA, tokenB)
            : (tokenB, tokenA);

        require(token0 != address(0), "VSWAP: ZERO_ADDRESS");

        require(pairs[token0][token1] == address(0), "VSWAP: PAIR_EXISTS");

        vPair newPair = new vPair(
            msg.sender,
            address(this),
            token0,
            token1,
            whitelist
        );

        pairs[token0][token1] = address(newPair);
        pairs[token1][token0] = address(newPair);
        allPairs.push(address(newPair));

        emit PairCreated(
            address(newPair),
            msg.sender,
            address(this),
            token0,
            token1,
            whitelist
        );
    }
}
