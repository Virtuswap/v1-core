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

    uint256 public override reserve0;
    uint256 public override reserve1;

    address[] public whitelist;

    uint256 belowReserve;
    uint256 public override reserveRatio;
    uint256 maxReserveRatio;

    mapping(address => bool) whitelistAllowance;
    mapping(address => uint256) reserves;

    event Sync(uint256 reserve0, uint256 reserve1);

    uint256 private unlocked = 1;
    modifier lock() {
        require(unlocked == 1, "UniswapV2: LOCKED");
        unlocked = 0;
        _;
        unlocked = 1;
    }

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

        //sync
        _update(
            IERC20(token0).balanceOf(address(this)),
            IERC20(token1).balanceOf(address(this))
        );
    }

    function _getSortedReservesBalances(address tokenIn)
        private
        view
        returns (uint256, uint256)
    {
        return token0 == tokenIn ? (reserve0, reserve1) : (reserve1, reserve0);
    }

    function _update(uint256 balance0, uint256 balance1) private {
        reserve0 = balance0;
        reserve1 = balance1;
        emit Sync(balance0, balance1);
    }

    function _updateReserves(address reserveToken, uint256 balance) private {
        reserves[reserveToken] = balance;
    }

    function tokens() external view returns (address, address) {
        return (token0, token1);
    }

    function getNativeReserves() external view returns (uint256, uint256) {
        return (reserve0, reserve1);
    }

    function getrReserve(address token) external view returns (uint256) {
        return reserves[token];
    }

    function quote(
        address tokenIn,
        uint256 amount,
        bool calculateFees
    ) external view returns (uint256) {
        (uint256 reserveIn, uint256 reserveOut) = _getSortedReservesBalances(
            tokenIn
        );

        return
            vSwapMath.quote(reserveIn, reserveOut, fee, amount, calculateFees);
    }

    function swapNative(uint256 minAmountOut, address to)
        external
        noDelegateCall
    {
        uint256 balance0Subst = IERC20(token0).balanceOf(address(this)) -
            reserve0;
        uint256 balance1Subst = IERC20(token1).balanceOf(address(this)) -
            reserve1;

        require(
            balance0Subst > 0 || balance1Subst > 0,
            "VSWAP: INSUFFICIENT_INPUT_AMOUNT"
        );

        (
            address _inputToken,
            address _outputToken,
            uint256 _amountIn
        ) = balance0Subst > 0
                ? (token0, token1, balance0Subst)
                : (token1, token0, balance1Subst);

        (uint256 _reserveIn, uint256 _reserveOut) = _getSortedReservesBalances(
            _inputToken
        );

        uint256 _amountOut = vSwapMath.quote(
            _reserveIn,
            _reserveOut,
            fee,
            _amountIn,
            true
        );

        // require(_amountOut < minAmountOut, "VSWAP: INSUFFICIENT_OUTPUT_AMOUNT");
        require(to > address(0) && to != _inputToken, "VSWAP:INVALID_TO");

        SafeERC20.safeTransfer(IERC20(_outputToken), to, _amountOut);

        (uint256 _reserve0, uint256 _reserve1) = _inputToken < _outputToken
            ? ((_reserveIn + _amountIn), (_reserveOut - _amountOut))
            : ((_reserveOut - _amountOut), (_reserveIn + _amountIn));

        _update(_reserve0, _reserve1);
    }

    // //Receive native token
    // //Out reserve token
    // function exchangeReserves(
    //     address tokenOut,
    //     uint256 minAmountOut,
    //     address to
    // ) external noDelegateCall lock {
    //     uint256 balance0Subst = IERC20(token0).balanceOf(address(this)) -
    //         reserve0;
    //     uint256 balance1Subst = IERC20(token1).balanceOf(address(this)) -
    //         reserve1;

    //     require(
    //         balance0Subst > 0 || balance1Subst > 0,
    //         "VSWAP: INSUFFICIENT_INPUT_AMOUNT"
    //     );

    //     (address _inputToken, uint256 _amountIn) = balance0Subst > 0
    //         ? (token0, balance0Subst)
    //         : (token1, balance1Subst);

    //     //find oracle pools
    //     address native0Oracle = IvPairFactory(factory).getPair(
    //         tokenOut,
    //         token0
    //     );
    //     address native1Oracle = IvPairFactory(factory).getPair(
    //         tokenOut,
    //         token1
    //     );

    //     require(
    //         native0Oracle > address(0) || native1Oracle > address(0),
    //         "VSWAP:NO_ORACLE_POOL"
    //     );

    //     uint256 finalb = 0;
    //     address selectedToken;
    //     if (native0Oracle > address(0) && native1Oracle > address(0)) {
    //         uint256 token0bid = IvPair(native0Oracle).quote(
    //             token0,
    //             _amountIn,
    //             false
    //         );
    //         uint256 token1bid = IvPair(native1Oracle).quote(
    //             token1,
    //             _amountIn,
    //             false
    //         );

    //         if (token0bid > 0 && token1bid > 0) {
    //             // get lower bid to prevent malicious pools
    //             (selectedToken, finalb) = (((token0bid / token1bid) * 1000) >=
    //                 ((reserve0 / reserve1) * 1000))
    //                 ? (token1, token1bid)
    //                 : (token0, token0bid);
    //         } else {
    //             (selectedToken, finalb) = token1bid == 0
    //                 ? (token0, token0bid)
    //                 : (token1, token1bid);
    //         }
    //     } else {
    //         (selectedToken, finalb) = (native0Oracle == address(0))
    //             ? (
    //                 token0,
    //                 IvPair(native1Oracle).quote(token1, _amountIn, false)
    //             )
    //             : (
    //                 token1,
    //                 IvPair(native0Oracle).quote(token0, _amountIn, false)
    //             );
    //     }

    //     //selected token is output token
    //     if (tokenOut != selectedToken) {
    //         (uint256 _reserve0, uint256 _reserve1) = _getSortedReservesBalances(
    //             selectedToken
    //         );
    //         finalb = vSwapMath.quote(_reserve0, _reserve1, fee, finalb, true);
    //     }

    //     // require(finalb >= minAmountOut, "VSWAP: INSUFFICIENT_OUTPUT_AMOUNT");

    //     SafeERC20.safeTransfer(IERC20(tokenOut), to, finalb);

    //     _updateReserves(tokenOut, reserves[tokenOut] - finalb);
    //     _update(
    //         IERC20(token0).balanceOf(address(this)),
    //         IERC20(token1).balanceOf(address(this))
    //     );
    // }

    //Receive reserve token
    //Out native token
    function swapReserves(
        address tokenIn,
        address tokenOut,
        uint256 minAmountOut,
        address to
    ) external noDelegateCall lock {
        require(
            whitelistAllowance[tokenIn] == true,
            "VSWAP:TOKEN_NOT_WHITELISTED"
        );

        require(
            tokenOut == token0 || tokenOut == token1,
            "VSWAP:INVALID_OUTTOKEN"
        );

        uint256 amountIn = IERC20(tokenIn).balanceOf(address(this)) -
            reserves[tokenIn];

        require(amountIn > 0, "VSWAP:INSUFFICIENT_INPUT_AMOUNT");

        //find oracle pools
        address native0Oracle = IvPairFactory(factory).getPair(tokenIn, token0);
        address native1Oracle = IvPairFactory(factory).getPair(tokenIn, token1);

        require(
            native0Oracle > address(0) || native1Oracle > address(0),
            "VSWAP:NO_ORACLE_POOL"
        );

        uint256 finalb = 0;
        address selectedToken;
        if (native0Oracle > address(0) && native1Oracle > address(0)) {
            uint256 token0bid = IvPair(native0Oracle).quote(
                tokenIn,
                amountIn,
                false
            );
            uint256 token1bid = IvPair(native1Oracle).quote(
                tokenIn,
                amountIn,
                false
            );

            if (token0bid > 0 && token1bid > 0) {
                // get lower bid to prevent malicious pools
                (selectedToken, finalb) = (((token0bid / token1bid) * 1000) >=
                    ((reserve0 / reserve1) * 1000))
                    ? (token1, token1bid)
                    : (token0, token0bid);
            } else {
                (selectedToken, finalb) = token1bid == 0
                    ? (token0, token0bid)
                    : (token1, token1bid);
            }
        } else {
            (selectedToken, finalb) = (native0Oracle == address(0))
                ? (
                    token0,
                    IvPair(native1Oracle).quote(tokenIn, amountIn, false)
                )
                : (
                    token1,
                    IvPair(native0Oracle).quote(tokenIn, amountIn, false)
                );
        }

        //selected token is output token
        if (tokenOut != selectedToken) {
            (uint256 _reserve0, uint256 _reserve1) = _getSortedReservesBalances(
                selectedToken
            );
            finalb = vSwapMath.quote(_reserve0, _reserve1, fee, finalb, true);
        }

        // require(finalb >= minAmountOut, "VSWAP: INSUFFICIENT_OUTPUT_AMOUNT");

        SafeERC20.safeTransfer(IERC20(tokenOut), to, finalb);

        _updateReserves(tokenIn, reserves[tokenIn] + amountIn);
        _update(
            IERC20(token0).balanceOf(address(this)),
            IERC20(token1).balanceOf(address(this))
        );
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

    // force balances to match reserves
    function skim(address to) external lock onlyOwner {
        address _token0 = token0; // gas savings
        address _token1 = token1; // gas savings

        SafeERC20.safeTransfer(
            IERC20(_token0),
            to,
            IERC20(_token0).balanceOf(address(this)) - reserve0
        );
        SafeERC20.safeTransfer(
            IERC20(_token1),
            to,
            IERC20(_token1).balanceOf(address(this)) - reserve1
        );
    }

    // force reserves to match balances
    function sync() external lock onlyOwner {
        _update(
            IERC20(token0).balanceOf(address(this)),
            IERC20(token1).balanceOf(address(this))
        );
    }
}
