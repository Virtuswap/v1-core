pragma solidity >=0.4.22 <0.9.0;

import "./interfaces/IvPair.sol";
import "./interfaces/IvPairFactory.sol";
import "./ERC20/IERC20.sol";
import "./vPairFactory.sol";
import "./libraries/Math.sol";
import "./ERC20/vSwapERC20.sol";
import "./libraries/vSwapMath.sol";

contract vPair is IvPair, vSwapERC20 {
    address owner;
    address factory;
    address public token0;
    address public token1;
    address[] public whitelist;

    bytes4 private constant SELECTOR =
        bytes4(keccak256(bytes("transfer(address,uint256)")));

    uint256 public belowReserve;
    uint256 public reserveRatio;
    uint256 public fee;
    uint256 maxReserveRatio;
    mapping(address => bool) whitelistAllowance;

    event Debug(string message, uint256 value);
    event DebugA(string message, address value);

    event Mint(address indexed sender, uint256 amount0, uint256 amount1);

    event Burn(
        address indexed sender,
        uint256 amount0,
        uint256 amount1,
        address indexed to
    );
    event Swap(
        address indexed sender,
        uint256 amount0In,
        uint256 amount1In,
        uint256 amount0Out,
        uint256 amount1Out,
        address indexed to
    );
    event Sync(uint112 reserve0, uint112 reserve1);

    modifier onlyOwner() {
        require(msg.sender == owner);
        _;
    }

    modifier onlyFactory() {
        require(msg.sender == factory);
        _;
    }

    modifier onlyPool() {
        require(msg.sender == IvPairFactory(factory).getvPoolAddress());
        _;
    }

    constructor(
        address _owner,
        address _factory,
        address _tokenA,
        address _tokenB,
        address[] memory _whitelist
    ) {
        require(_whitelist.length <= 8, "Maximum 8 whitelist tokens");

        owner = _owner;
        factory = _factory;
        whitelist = _whitelist;
        token0 = _tokenA;
        token1 = _tokenB;
        belowReserve = 1;
        maxReserveRatio = 0.02 ether;
    }

    function getBelowReserve() external pure returns (uint256) {
        return 1;
    }

    function _calculateReserveRatio() public {
        uint256 _reserveRatio = 0;

        for (uint256 i = 0; i < whitelist.length; i++) {
            uint256 reserveBalance = IERC20(whitelist[i]).balanceOf(
                address(this)
            );

            if (reserveBalance > 0) {
                address ikAddress = vPairFactory(factory).getPairAddress(
                    token0,
                    whitelist[i]
                );

                address jkAddress = vPairFactory(factory).getPairAddress(
                    token1,
                    whitelist[i]
                );

                uint256 ikTokenABalance = IERC20(token0).balanceOf(ikAddress);

                uint256 ikTokenBBalance = IERC20(whitelist[i]).balanceOf(
                    ikAddress
                );

                uint256 jkTokenABalance = IERC20(token1).balanceOf(jkAddress);
                uint256 jkTokenBBalance = IERC20(whitelist[i]).balanceOf(
                    jkAddress
                );
                uint256 ijTokenABalance = IERC20(token0).balanceOf(
                    address(this)
                );
                uint256 ijTokenBBalance = IERC20(token1).balanceOf(
                    address(this)
                );

                uint256 cRR = vSwapMath.calculateReserveRatio(
                    reserveBalance,
                    ikTokenABalance,
                    ikTokenBBalance,
                    jkTokenABalance,
                    jkTokenBBalance,
                    ijTokenABalance,
                    ijTokenBBalance
                );

                _reserveRatio = _reserveRatio + cRR;
            }
        }

        reserveRatio = _reserveRatio;
    }

    function _mint() internal {}

    function collect(uint256 token0Amount, uint256 token1Amount) external {
        require(
            IERC20(token0).transferFrom(
                msg.sender,
                address(this),
                token0Amount
            ),
            "Could not transfer token 0"
        );
        require(
            IERC20(token1).transferFrom(
                msg.sender,
                address(this),
                token1Amount
            ),
            "Could not transfer token 1"
        );

        emit LiquidityChange(address(this), token0Amount, token1Amount);

        uint256 lpAmount = 10000 ether;
        uint256 token0Balance = IERC20(token0).balanceOf(address(this));

        if (token0Balance > token0Amount) {
            lpAmount = vSwapMath.calculateLPTokensAmount(
                token0Amount,
                IERC20(address(this)).totalSupply(),
                token0Balance,
                reserveRatio
            );
        }

        _mint(msg.sender, lpAmount);
    }

    function _safeTransfer(
        address token,
        address to,
        uint256 value
    ) private {
        (bool success, bytes memory data) = token.call(
            abi.encodeWithSelector(SELECTOR, to, value)
        );
        require(
            success && (data.length == 0 || abi.decode(data, (bool))),
            "vSwap: TRANSFER_FAILED"
        );
    }

    function transferToken(
        address token,
        address to,
        uint256 amount
    ) external onlyPool returns (bool) {
        require(
            token == token0 || token == token1,
            "Token dont exist in the pool"
        );

        return ERC20(token).transfer(to, amount);
    }

    function withdrawal() external {}

    function quote(
        address inToken,
        address outToken,
        uint256 amount
    ) external {}

    function setWhitelistAllowance(address reserveToken, bool activateReserve)
        external
        onlyOwner
    {
        whitelistAllowance[reserveToken] = activateReserve;
    }

    function isReserveAllowed(address reserveToken) public view returns (bool) {
        return whitelistAllowance[reserveToken];
    }
}
