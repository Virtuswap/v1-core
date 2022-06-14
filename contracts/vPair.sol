pragma solidity ^0.8.0;

import "./interfaces/IvPair.sol";
import "./interfaces/IvPairFactory.sol";
import "./ERC20/vSwapERC20.sol";
import "./libraries/SafeERC20.sol";
import "./libraries/Math.sol";
import "./libraries/vSwapMath.sol";
import "./NoDelegateCall.sol";
import "./interfaces/IvSwapCallee.sol";

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

    // function quoteInput(
    //     address tokenIn,
    //     uint256 amount,
    //     bool calculateFees
    // ) external view returns (uint256) {
    //     (uint256 reserveIn, uint256 reserveOut) = _getSortedReservesBalances(
    //         tokenIn
    //     );

    //     return
    //         vSwapMath.quoteInput(
    //             reserveIn,
    //             reserveOut,
    //             fee,
    //             amount,
    //             calculateFees
    //         );
    // }

    function swapNative(
        uint256 amountOut,
        address tokenOut,
        address to,
        bytes memory data
    ) external noDelegateCall {
        require(to > address(0), "VSWAP:INVALID_TO");

        SafeERC20.safeTransfer(IERC20(tokenOut), to, amountOut);

        address _inputToken = tokenOut == token0 ? token1 : token0;

        (uint256 _reserveIn, uint256 _reserveOut) = _getSortedReservesBalances(
            _inputToken
        );

        uint256 _amountIn = IERC20(_inputToken).balanceOf(address(this)) -
            _reserveIn;

        uint256 _expectedAmountIn = vSwapMath.quoteInput(
            _reserveIn,
            _reserveOut,
            fee,
            amountOut,
            true
        );

        if (data.length > 0)
            IvSwapCallee(to).vSwapcallee(
                msg.sender,
                amountOut,
                _expectedAmountIn,
                _inputToken,
                data
            );

        require(
            _amountIn > 0 && _amountIn > _expectedAmountIn,
            "VSWAP: INSUFFICIENT_INPUT_AMOUNT"
        );

        (uint256 _reserve0, uint256 _reserve1) = _inputToken < tokenOut
            ? ((_reserveIn + _amountIn), (_reserveOut - amountOut))
            : ((_reserveOut - amountOut), (_reserveIn + _amountIn));

        _update(_reserve0, _reserve1);
    }

    function swapReserves(
        uint256 amountOut,
        address ikPairAddress,
        address to,
        bytes calldata data
    ) external noDelegateCall lock {
        (address _ikToken0, address _ikToken1) = IvPair(ikPairAddress).tokens();

        (address _jkToken0, address _jkToken1) = (token0, token1);
        //find common token
        (_ikToken0, _ikToken1, _jkToken0, _jkToken1) = vSwapMath
            .findCommonToken(_ikToken0, _ikToken1, _jkToken0, _jkToken1);

        //validate with factory
        require(
            IvPairFactory(factory).getPair(_ikToken0, _ikToken1) ==
                ikPairAddress &&
                ikPairAddress > address(0) &&
                _ikToken1 == _jkToken1,
            "VSWAP:INVALID_IK_POOL"
        );

        VirtualPoolModel memory vPool;
        {
            uint256 ikReserve0 = _ikToken0 == IvPair(ikPairAddress).token0()
                ? IvPair(ikPairAddress).reserve0()
                : IvPair(ikPairAddress).reserve1();

            uint256 ikReserve1 = _ikToken0 == IvPair(ikPairAddress).token0()
                ? IvPair(ikPairAddress).reserve1()
                : IvPair(ikPairAddress).reserve0();

            vPool = vSwapMath.calculateVPool(
                ikReserve0,
                ikReserve1,
                _jkToken0 == token0 ? reserve0 : reserve1,
                _jkToken0 == token0 ? reserve1 : reserve0
            );
        }
        require(
            whitelistAllowance[_ikToken0] == true,
            "VSWAP:TOKEN_NOT_WHITELISTED"
        );

        require(
            (_jkToken0 == token0 || _jkToken0 == token1),
            "VSWAP:INVALID_OUTTOKEN"
        );

        SafeERC20.safeTransfer(IERC20(_jkToken0), to, amountOut);

        uint256 requiredAmountIn = vSwapMath.quoteInput(
            vPool.tokenABalance,
            vPool.tokenBBalance,
            fee,
            amountOut,
            true
        );

        // emit Debug("vPool.tokenABalance", vPool.tokenABalance);
        // emit Debug("vPool.tokenBBalance", vPool.tokenBBalance);
        // emit Debug("amountOut", amountOut);
        // emit Debug("requiredAmountIn", requiredAmountIn);

        if (data.length > 0)
            IvSwapCallee(to).vSwapcallee(
                msg.sender,
                amountOut,
                requiredAmountIn,
                _ikToken0,
                data
            );

        uint256 reserveInBalance = IERC20(_ikToken0).balanceOf(address(this));
        uint256 amountIn = reserveInBalance - reserves[_ikToken0];

        require(
            amountIn > 0 && amountIn >= requiredAmountIn,
            "VSWAP: INSUFFICIENT_INPUT_AMOUNT"
        );

        _updateReserves(_ikToken0, reserveInBalance);
        _update(
            IERC20(token0).balanceOf(address(this)),
            IERC20(token1).balanceOf(address(this))
        );
    }

    // function getBelowReserve() external pure returns (uint256) {
    //     return 1;
    // }

    function _calculateReserveRatio() external returns (uint256) {
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

        return _reserveRatio;
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

    // function setFactory(address _factory) external onlyOwner noDelegateCall {
    //     factory = _factory;
    // }

    // force balances to match reserves
    // function skim(address to) external lock onlyOwner {
    //     address _token0 = token0; // gas savings
    //     address _token1 = token1; // gas savings

    //     SafeERC20.safeTransfer(
    //         IERC20(_token0),
    //         to,
    //         IERC20(_token0).balanceOf(address(this)) - reserve0
    //     );
    //     SafeERC20.safeTransfer(
    //         IERC20(_token1),
    //         to,
    //         IERC20(_token1).balanceOf(address(this)) - reserve1
    //     );
    // }

    // // force reserves to match balances
    // function sync() external lock onlyOwner {
    //     _update(
    //         IERC20(token0).balanceOf(address(this)),
    //         IERC20(token1).balanceOf(address(this))
    //     );
    // }
}
