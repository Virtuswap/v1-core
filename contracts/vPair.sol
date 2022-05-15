pragma solidity ^0.8.0;

import "./interfaces/IvPair.sol";
import "./interfaces/IvPairFactory.sol";
import "./ERC20/vSwapERC20.sol";
import "./libraries/SafeERC20.sol";
import "./libraries/Math.sol";
import "./libraries/vSwapMath.sol";
import "./NoDelegateCall.sol";

contract vPair is IvPair, vSwapERC20, NoDelegateCall {
    address owner;
    address factory;

    address public immutable override token0;
    address public immutable override token1;

    uint256 public override fee;

    uint256 reserve0;
    uint256 reserve1;

    address[] public whitelist;

    uint256 belowReserve;
    uint256 reserveRatio;
    uint256 maxReserveRatio;

    uint32 public blockTimestampLast;
    uint256 public price0CumulativeLast;
    uint256 public price1CumulativeLast;

    mapping(address => bool) whitelistAllowance;
    mapping(address => uint256) reserves;

    event Sync(uint256 reserve0, uint256 reserve1);

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
            IvPairFactory(factory).getvPoolAddress() == msg.sender,
            "VSWAP:ONLY_VPOOL"
        );
        _;
    }

    constructor(
        address _owner,
        address _factory,
        address _tokenA,
        address _tokenB,
        uint256 _fee,
        address[] memory _whitelist
    ) {
        require(_whitelist.length <= 12, "VSWAP:MAX_WHITELIST");

        owner = _owner;
        factory = _factory;
        whitelist = _whitelist;
        token0 = _tokenA;
        token1 = _tokenB;
        fee = _fee;
        belowReserve = 1;
        maxReserveRatio = 0.02 ether;

        for (uint256 i = 0; i < whitelist.length; i++)
            whitelistAllowance[whitelist[i]] = true;
    }

    function tokens() external view returns (address, address) {
        return (token0, token1);
    }

    function getReserves()
        external
        view
        returns (
            uint256,
            uint256,
            uint256
        )
    {
        return (reserve0, reserve1, blockTimestampLast);
    }

    function _getSortedReservesBalances(address tokenIn)
        internal
        view
        returns (uint256, uint256)
    {
        return token0 == tokenIn ? (reserve0, reserve1) : (reserve1, reserve0);
    }

    function quote(address tokenIn, uint256 amount)
        external
        view
        returns (uint256)
    {
        (uint256 reserveIn, uint256 reserveOut) = _getSortedReservesBalances(
            tokenIn
        );

        return vSwapMath.quote(reserveIn, reserveOut, fee, amount, true);
    }

    function swapNative(
        address tokenIn,
        uint256 amount,
        uint256 minAmountOut,
        address to
    ) external noDelegateCall {
        require(
            tokenIn == token0 || tokenIn == token1,
            "VSWAP:NON_NATIVE_TOKEN"
        );

        (address _inputToken, address _outputToken) = token0 == tokenIn
            ? (token0, token1)
            : (token1, token0);

        (uint256 reserveIn, uint256 reserveOut) = _getSortedReservesBalances(
            tokenIn
        );

        uint256 balance0 = IERC20(_inputToken).balanceOf(address(this));
        uint256 balance1 = IERC20(_outputToken).balanceOf(address(this));

        uint256 amountOut = vSwapMath.quote(
            reserveIn,
            reserveOut,
            fee,
            amount,
            true
        );

        require(to > address(0) && to != tokenIn, "VSWAP:INVALID_TO");
        // require(amountOut >= minAmountOut, "VSWAP:NO_MINIMUM_AMOUNT");

        SafeERC20.safeTransferFrom(
            IERC20(_inputToken),
            msg.sender,
            address(this),
            amount
        );

        SafeERC20.safeTransfer(IERC20(_outputToken), to, amountOut);

        _update(balance0, balance1);
    }

    function swapReserves(
        address tokenIn,
        address tokenOut,
        uint256 amount,
        uint256 minAmountOut,
        address ikPairAddress,
        address to
    ) external noDelegateCall {
        require(
            whitelistAllowance[tokenIn] == true,
            "VSWAP:TOKEN_NOT_WHITELISTED"
        );

        require(
            tokenOut == token0 || tokenOut == token1,
            "VSWAP:INVALID_OUTTOKEN"
        );

        require(ikPairAddress > address(0), "VSWAP:INVALID_IKPOOL");

        (address ikToken0, address ikToken1) = IvPair(ikPairAddress).tokens();
        (address _jkToken0, address _jkToken1) = (token0, token1);

        //find common token
        (ikToken0, ikToken1, _jkToken0, _jkToken1) = vSwapMath.findCommonToken(
            ikToken0,
            ikToken1,
            token0,
            token1
        );

        require(_jkToken1 == tokenOut, "VSWAP_INVALID_TOKENOUT");

        uint256 ikAmountOut = IvPair(ikPairAddress).quote(tokenIn, amount);

        uint256 tokenOutAmount = this.quote(ikToken1, ikAmountOut);

        SafeERC20.safeTransferFrom(
            IERC20(tokenIn),
            msg.sender,
            address(this),
            amount
        );

        // require(tokenOutAmount >= minAmountOut, "VSWAP:NO_MINIMUM_AMOUNT");

        SafeERC20.safeTransfer(IERC20(tokenOut), to, tokenOutAmount);
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

    // update reserves and, on the first call per block, price accumulators
    function _update(uint256 balance0, uint256 balance1) private {
        uint32 blockTimestamp = uint32(block.timestamp % 2**32);
        uint32 timeElapsed = blockTimestamp - blockTimestampLast; // overflow is desired

        if (timeElapsed > 0 && reserve0 != 0 && reserve1 != 0) {
            price0CumulativeLast += (reserve1 / reserve0) * timeElapsed;
            price1CumulativeLast += (reserve0 / reserve1) * timeElapsed;
        }

        reserve0 = balance0;
        reserve1 = balance1;
        blockTimestampLast = blockTimestamp;
        emit Sync(reserve0, reserve1);
    }

    function collect(uint256 token0Amount, uint256 token1Amount)
        external
        noDelegateCall
    {
        uint256 balance0 = IERC20(token0).balanceOf(address(this));
        uint256 balance1 = IERC20(token1).balanceOf(address(this));

        SafeERC20.safeTransferFrom(
            IERC20(token0),
            msg.sender,
            address(this),
            token0Amount
        );

        SafeERC20.safeTransferFrom(
            IERC20(token1),
            msg.sender,
            address(this),
            token1Amount
        );

        emit LiquidityChange(address(this), token0Amount, token1Amount);

        uint256 lpAmount = 0;

        if (balance0 == 0) lpAmount = 10000 ether;
        else {
            lpAmount = vSwapMath.calculateLPTokensAmount(
                token0Amount,
                IERC20(address(this)).totalSupply(),
                balance0,
                reserveRatio
            );
        }

        require(lpAmount > 0, "VSWAP:ERROR_CALCULATING_LPTOKENS");

        _mint(msg.sender, lpAmount);
        emit Mint(msg.sender, token0Amount, token1Amount);

        balance0 = IERC20(token0).balanceOf(address(this));
        balance1 = IERC20(token1).balanceOf(address(this));

        _update(balance0, balance1);
    }

    function transferToken(
        address token,
        address to,
        uint256 amount
    ) external onlyVPool noDelegateCall returns (bool) {
        SafeERC20.safeTransfer(IERC20(token), to, amount);
        return true;
    }

    function withdrawal() external noDelegateCall {}

    function setWhitelistAllowance(address reserveToken, bool activateReserve)
        external
        noDelegateCall
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

    function setFactory(address _factory) external onlyOwner noDelegateCall {
        factory = _factory;
    }
}
