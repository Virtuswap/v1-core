pragma solidity >=0.4.22 <0.9.0;

import "./interfaces/IvPair.sol";
import "./interfaces/IvPairFactory.sol";
import "./ERC20/vSwapERC20.sol";
import "./libraries/SafeERC20.sol";
import "./libraries/Math.sol";
import "./libraries/vSwapMath.sol";

contract vPair is IvPair, vSwapERC20 {
    address owner;
    address factory;
    address token0;
    address token1;
    address[] public whitelist;

    uint256 public belowReserve;
    uint256 public reserveRatio;
    uint256 public fee;
    uint256 maxReserveRatio;
    mapping(address => bool) whitelistAllowance;

    event Debug(string message, uint256 value);
    event DebugA(string message, address value);

    event Sync(uint112 reserve0, uint112 reserve1);

    modifier onlyOwner() {
        require(msg.sender == owner);
        _;
    }

    modifier onlyFactory() {
        require(msg.sender == factory);
        _;
    }

    modifier onlyVPool() {
        require(
            msg.sender == IvPairFactory(factory).getvPoolAddress(),
            "VSWAP:ONLY_VPOOL"
        );
        _;
    }

    constructor(
        address _owner,
        address _factory,
        address _tokenA,
        address _tokenB,
        address[] memory _whitelist
    ) {
        require(_whitelist.length <= 12, "VSWAP:MAX_WHITELIST");

        owner = _owner;
        factory = _factory;
        whitelist = _whitelist;
        token0 = _tokenA;
        token1 = _tokenB;
        belowReserve = 1;
        maxReserveRatio = 0.02 ether;

        for (uint256 i = 0; i < whitelist.length; i++)
            whitelistAllowance[whitelist[i]] = true;
    }

    function getToken0() external view returns (address) {
        return token0;
    }

    function getToken1() external view returns (address) {
        return token1;
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
                address ikAddress = IvPairFactory(factory).getPair(
                    token0,
                    whitelist[i]
                );

                address jkAddress = IvPairFactory(factory).getPair(
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

    function collect(uint256 token0Amount, uint256 token1Amount) external {
        uint256 token0Balance = IERC20(token0).balanceOf(address(this));

        require(
            IERC20(token0).transferFrom(
                msg.sender,
                address(this),
                token0Amount
            ),
            "VSWAP:COLLECT_ERROR_TOKEN0"
        );
        require(
            IERC20(token1).transferFrom(
                msg.sender,
                address(this),
                token1Amount
            ),
            "VSWAP:COLLECT_ERROR_TOKEN1"
        );

        emit LiquidityChange(address(this), token0Amount, token1Amount);

        // uint256 lpAmount = 10000 ether;
        uint256 lpAmount = 0;

        if (token0Balance == 0) lpAmount = 10000 ether;
        else {
            lpAmount = vSwapMath.calculateLPTokensAmount(
                token0Amount,
                IERC20(address(this)).totalSupply(),
                token0Balance,
                reserveRatio
            );
        }

        require(lpAmount > 0, "VSWAP:ERROR_CALCULATING_LPTOKENS");
        
        _mint(msg.sender, lpAmount);
        emit Mint(msg.sender, token0Amount, token1Amount);
    }

    function transferToken(
        address token,
        address to,
        uint256 amount
    ) external returns (bool) {
        SafeERC20.safeTransfer(IERC20(token), to, amount);
        return true;
    }

    function withdrawal() external {}

    function setWhitelistAllowance(address reserveToken, bool activateReserve)
        external
        onlyOwner
    {
        whitelistAllowance[reserveToken] = activateReserve;
        emit WhitelistChanged(reserveToken, activateReserve);
    }

    function isReserveAllowed(address reserveToken)
        external
        view
        returns (bool)
    {
        return whitelistAllowance[reserveToken];
    }

    function setFactory(address _factory) external onlyOwner {
        factory = _factory;
    }
}
