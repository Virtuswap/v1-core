pragma solidity ^0.8.0;

import "./interfaces/IvPair.sol";
import "./interfaces/IvPairFactory.sol";
import "./ERC20/vSwapERC20.sol";
import "./libraries/SafeERC20.sol";
import "./libraries/Math.sol";
import "./libraries/vSwapMath.sol";
import "./interfaces/IvSwapCallee.sol";

contract vPair is IvPair, vSwapERC20 {
    address factory;

    address public immutable override token0;
    address public immutable override token1;

    uint256 public override fee;

    uint256 public override reserve0;
    uint256 public override reserve1;

    address[] public whitelist;
    mapping(address => bool) whitelistAllowance;

    mapping(address => uint256) public reserveRatio;
    mapping(address => uint256) reserves;

    uint256 private unlocked = 1;
    modifier lock() {
        require(unlocked == 1, "L");
        unlocked = 0;
        _;
        unlocked = 1;
    }

    function onlyFactoryAdmin() private view {
        require(msg.sender == IvPairFactory(factory).admin());
    }

    constructor(
        address _factory,
        address _tokenA,
        address _tokenB,
        uint256 _fee
    ) {
        factory = _factory;
        token0 = _tokenA;
        token1 = _tokenB;
        fee = _fee;
        // maxReserveRatio = 2000; //2PCT

        //sync
        _update(
            IERC20(token0).balanceOf(address(this)),
            IERC20(token1).balanceOf(address(this)),
            address(0),
            0
        );
    }

    function _update(
        uint256 balance0,
        uint256 balance1,
        address reserveToken,
        uint256 reserveAmount
    ) private {
        reserve0 = balance0;
        reserve1 = balance1;

        if (reserveToken > address(0) && reserveAmount > 0) {
            reserves[reserveToken] = reserveAmount;
        }
        emit Sync(balance0, balance1);
    }

    function swapNative(
        uint256 amountOut,
        address tokenOut,
        address to,
        bytes memory data
    ) external lock {
        require(to > address(0), "IT"); // INVALID TO

        SafeERC20.safeTransfer(IERC20(tokenOut), to, amountOut);

        address _inputToken = tokenOut == token0 ? token1 : token0;

        PoolReserve memory poolReserves = vSwapMath.SortedReservesBalances(
            _inputToken,
            token0,
            reserve0,
            reserve1
        );

        uint256 _amountIn = IERC20(_inputToken).balanceOf(address(this)) -
            poolReserves.reserve0;

        uint256 _expectedAmountIn = vSwapMath.getAmountIn(
            amountOut,
            poolReserves.reserve0,
            poolReserves.reserve1,
            fee,
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

        require(_amountIn > 0 && _amountIn > _expectedAmountIn, "IIA");

        (uint256 _reserve0, uint256 _reserve1) = _inputToken < tokenOut
            ? (
                (poolReserves.reserve0 + _amountIn),
                (poolReserves.reserve1 - amountOut)
            )
            : (
                (poolReserves.reserve1 - amountOut),
                (poolReserves.reserve0 + _amountIn)
            );

        _update(_reserve0, _reserve1, address(0), 0);
    }

    function calculateReserveRatio() external view returns (uint256 rRatio) {
        for (uint256 i = 0; i < whitelist.length; i++) {
            rRatio += reserveRatio[whitelist[i]];
        }
    }

    function calculateVirtualPool(uint256 ikReserve0, uint256 ikReserve1)
        internal
        returns (VirtualPoolModel memory vPool)
    {}

    function swapReserves(
        uint256 amountOut,
        address ikPairAddress,
        address to,
        bytes calldata data
    ) external lock {
        (address _ikToken0, address _ikToken1) = (
            IvPair(ikPairAddress).token0(),
            IvPair(ikPairAddress).token1()
        );

        require(this.calculateReserveRatio() < 2000, "PRF");

        (address _jkToken0, address _jkToken1) = (token0, token1);
        //find common token
        (_ikToken0, _ikToken1, _jkToken0, _jkToken1) = vSwapMath
            .findCommonToken(_ikToken0, _ikToken1, _jkToken0, _jkToken1);

        //validate with factory
        require(
            IvPairFactory(factory).getPair(_ikToken0, _ikToken1) ==
                ikPairAddress &&
                _ikToken1 == _jkToken1,
            "IIKP"
        );

        require(whitelistAllowance[_ikToken0] == true, "TNW");

        SafeERC20.safeTransfer(IERC20(_jkToken0), to, amountOut);

        VirtualPoolModel memory vPool = vSwapMath.calculateVPool(
            _ikToken0 == IvPair(ikPairAddress).token0()
                ? IvPair(ikPairAddress).reserve0()
                : IvPair(ikPairAddress).reserve1(),
            _ikToken0 == IvPair(ikPairAddress).token0()
                ? IvPair(ikPairAddress).reserve1()
                : IvPair(ikPairAddress).reserve0(),
            _jkToken0 == token0 ? reserve0 : reserve1,
            _jkToken0 == token0 ? reserve1 : reserve0
        );

        uint256 requiredAmountIn = vSwapMath.getAmountIn(
            amountOut,
            vPool.tokenABalance,
            vPool.tokenBBalance,
            fee,
            true
        );

        if (data.length > 0)
            IvSwapCallee(to).vSwapcallee(
                msg.sender,
                amountOut,
                requiredAmountIn,
                _ikToken0,
                data
            );

        uint256 amountIn = IERC20(_ikToken0).balanceOf(address(this)) -
            reserves[_ikToken0];

        require(amountIn > 0 && amountIn >= requiredAmountIn, "IIA");

        if (_jkToken0 == token0) {
            //reserve ratio
            updateReserveRatio(_jkToken0, amountOut);
        } else {
            PoolReserve memory reserves = vSwapMath.SortedReservesBalances(
                _jkToken0,
                token0,
                reserve0,
                reserve1
            );

            uint256 baseTokenBid = vSwapMath.getAmountIn(
                amountOut,
                reserves.reserve0,
                reserves.reserve1,
                fee,
                true
            );

            updateReserveRatio(token1, baseTokenBid);
        }

        _update(
            IERC20(token0).balanceOf(address(this)),
            IERC20(token1).balanceOf(address(this)),
            _ikToken0,
            reserves[_ikToken0] + amountIn
        );
    }

    function updateReserveRatio(address token, uint256 amountOut) internal {
        reserveRatio[token] = ((amountOut * 100 * 100000) / reserve0) * 2;
    }

    function mint(address to) external lock returns (uint256 liquidity) {
        (uint256 _reserve0, uint256 _reserve1) = (reserve0, reserve1);
        uint256 balance0 = IERC20(token0).balanceOf(address(this));
        uint256 balance1 = IERC20(token1).balanceOf(address(this));
        uint256 amount0 = balance0 - _reserve0;
        uint256 amount1 = balance1 - _reserve1;

        uint256 _totalSupply = totalSupply;
        if (_totalSupply == 0) {
            liquidity = 10000 ether;
        } else {
            liquidity = vSwapMath.calculateLPTokensAmount(
                _reserve0,
                totalSupply,
                amount0,
                this.calculateReserveRatio()
            );
        }
        require(liquidity > 0, "ILM");
        _mint(to, liquidity);

        _update(balance0, balance1, address(0), 0);
        emit Mint(msg.sender, amount0, amount1);
    }

    // update reserves and, on the first call per block, price accumulators

    function burn(address to)
        external
        lock
        returns (uint256 amount0, uint256 amount1)
    {
        address _token0 = token0; // gas savings
        address _token1 = token1; // gas savings
        uint256 balance0 = IERC20(_token0).balanceOf(address(this));
        uint256 balance1 = IERC20(_token1).balanceOf(address(this));
        uint256 liquidity = balanceOf[address(this)];

        uint256 _totalSupply = totalSupply;
        amount0 = (liquidity / _totalSupply) * balance0;
        amount1 = (liquidity / _totalSupply) * balance1;

        require(amount0 > 0 && amount1 > 0, "ILB");

        _burn(address(this), liquidity);
        SafeERC20.safeTransfer(IERC20(_token0), to, amount0);
        SafeERC20.safeTransfer(IERC20(_token1), to, amount1);

        for (uint256 i = 0; i < whitelist.length; i++) {
            uint256 balance = IERC20(whitelist[i]).balanceOf(address(this));
            if (balance > 0) {
                uint256 amount = (liquidity / _totalSupply) * balance;
                SafeERC20.safeTransfer(IERC20(_token0), to, amount);
            }
        }

        balance0 = IERC20(_token0).balanceOf(address(this));
        balance1 = IERC20(_token1).balanceOf(address(this));

        _update(balance0, balance1, address(0), 0);
        emit Burn(msg.sender, amount0, amount1, to);
    }

    function setWhitelist(address[] memory _whitelist) external {
        onlyFactoryAdmin();
        require(_whitelist.length <= 8, "MW");

        address[] memory _oldWL = whitelist;

        for (uint256 i = 0; i < _oldWL.length; i++)
            whitelistAllowance[_oldWL[i]] = false;

        //set new whitelist
        whitelist = _whitelist;
        for (uint256 i = 0; i < _whitelist.length; i++)
            whitelistAllowance[_whitelist[i]] = true;
    }

    function isReserveAllowed(address reserveToken)
        external
        view
        returns (bool)
    {
        return whitelistAllowance[reserveToken];
    }

    function setFactory(address _factory) external {
        onlyFactoryAdmin();
        factory = _factory;
    }

    function setFee(uint256 _fee) external {
        onlyFactoryAdmin();
        fee = _fee;
    }
}
