pragma solidity =0.8.1;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/utils/math/Math.sol";
import "./interfaces/IvPair.sol";
import "./interfaces/IvPairFactory.sol";
import "./libraries/vSwapMath.sol";
import "./interfaces/IvFlashSwapCallback.sol";
import "./vSwapERC20.sol";

contract vPair is IvPair, vSwapERC20 {
    address public factory;

    address public immutable override token0;
    address public immutable override token1;

    uint256 public override fee;
    uint256 public override vFee;

    uint256 public override reserve0;
    uint256 public override reserve1;

    uint256 private constant MINIMUM_LIQUIDITY = 10 * 1e3;
    uint256 private constant MAX_RESERVE_RATIO = 2000; //2%

    address[] public whitelist;
    mapping(address => bool) public whitelistAllowance;

    mapping(address => uint256) public reserveRatio;
    mapping(address => uint256) reserves;

    uint256 private unlocked = 1;
    modifier lock() {
        require(unlocked == 1, "L");
        unlocked = 0;
        _;
        unlocked = 1;
    }

    function _onlyFactoryAdmin() internal view {
        require(msg.sender == IvPairFactory(factory).admin());
    }

    modifier onlyFactoryAdmin() {
        _onlyFactoryAdmin();
        _;
    }

    constructor(
        address _factory,
        address _tokenA,
        address _tokenB,
        uint256 _fee,
        uint256 _vFee
    ) vSwapERC20("Virtuswap-LP", "VSWAPLP") {
        factory = _factory;
        token0 = _tokenA;
        token1 = _tokenB;
        fee = _fee;
        vFee = _vFee;
    }

    function _update(uint256 balance0, uint256 balance1) private {
        reserve0 = balance0;
        reserve1 = balance1;

        emit Sync(balance0, balance1);
    }

    function swapNative(
        uint256 amountOut,
        address tokenOut,
        address to,
        bytes memory data
    ) external override lock {
        require(to > address(0), "IT"); // INVALID TO

        SafeERC20.safeTransfer(IERC20(tokenOut), to, amountOut);

        address _inputToken = tokenOut == token0 ? token1 : token0;

        PoolReserve memory poolReserves = vSwapMath.SortedReservesBalances(
            _inputToken,
            token0,
            reserve0,
            reserve1
        );

        uint256 _expectedAmountIn = vSwapMath.getAmountIn(
            amountOut,
            poolReserves.reserve0,
            poolReserves.reserve1,
            fee
        );

        if (data.length > 0)
            IvFlashSwapCallback(to).vFlashSwapCallback(
                msg.sender,
                amountOut,
                _expectedAmountIn,
                _inputToken,
                data
            );

        uint256 _amountIn = IERC20(_inputToken).balanceOf(address(this)) -
            poolReserves.reserve0;

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

        _update(_reserve0, _reserve1);
    }

    function calculateReserveRatio()
        external
        view
        override
        returns (uint256 rRatio)
    {
        uint256 _baseReserve = reserve0;
        for (uint256 i = 0; i < whitelist.length; ++i) {
            uint256 _rReserve = reserveRatio[whitelist[i]];
            if (_rReserve > 0) {
                rRatio = vSwapMath.calculateReserveRatio(
                    rRatio,
                    _rReserve,
                    _baseReserve
                );
            }
        }
    }

    function swapReserves(
        uint256 amountOut,
        address ikPairAddress,
        address to,
        bytes calldata data
    ) external override lock {
        require(this.calculateReserveRatio() < MAX_RESERVE_RATIO, "MRR");

        // find common token
        VirtualPoolTokens memory vPoolTokens = vSwapMath.findCommonToken(
            IvPair(ikPairAddress).token0(),
            IvPair(ikPairAddress).token1(),
            token0,
            token1
        );

        // validate with factory
        require(
            IvPairFactory(factory).getPair(vPoolTokens.ik0, vPoolTokens.ik1) ==
                ikPairAddress &&
                vPoolTokens.ik0 == vPoolTokens.jk0,
            "IIKP"
        );

        require(whitelistAllowance[vPoolTokens.ik0], "TNW");

        SafeERC20.safeTransfer(IERC20(vPoolTokens.jk0), to, amountOut);

        VirtualPoolModel memory vPool;
        {
            uint256 ikReserve0 = IvPair(ikPairAddress).reserve0();
            uint256 ikReserve1 = IvPair(ikPairAddress).reserve1();
            address ikPair0 = IvPair(ikPairAddress).token0();

            vPool = vSwapMath.calculateVPool(
                vPoolTokens.ik0 == ikPair0 ? ikReserve0 : ikReserve1,
                vPoolTokens.ik0 == ikPair0 ? ikReserve1 : ikReserve0,
                vPoolTokens.jk0 == token0 ? reserve0 : reserve1,
                vPoolTokens.jk0 == token0 ? reserve1 : reserve0
            );
        }

        uint256 requiredAmountIn = vSwapMath.getAmountIn(
            amountOut,
            vPool.tokenABalance,
            vPool.tokenBBalance,
            vFee
        );

        if (data.length > 0)
            IvFlashSwapCallback(to).vFlashSwapCallback(
                msg.sender,
                amountOut,
                requiredAmountIn,
                vPoolTokens.ik0,
                data
            );

        uint256 amountIn = IERC20(vPoolTokens.ik0).balanceOf(address(this)) -
            reserves[vPoolTokens.ik0];

        require(amountIn > 0 && amountIn >= requiredAmountIn, "IIA");

        reserveRatio[vPoolTokens.ik0] =
            reserveRatio[vPoolTokens.ik0] +
            (
                (vPoolTokens.jk0 == token0)
                    ? amountOut
                    : vSwapMath.quote(amountOut, reserve1, reserve0)
            );

        reserves[vPoolTokens.ik0] + amountIn;

        _update(
            IERC20(token0).balanceOf(address(this)),
            IERC20(token1).balanceOf(address(this))
        );
    }

    function mint(address to)
        external
        override
        lock
        returns (uint256 liquidity)
    {
        (uint256 _reserve0, uint256 _reserve1) = (reserve0, reserve1);
        uint256 balance0 = IERC20(token0).balanceOf(address(this));
        uint256 balance1 = IERC20(token1).balanceOf(address(this));
        uint256 amount0 = balance0 - _reserve0;
        uint256 amount1 = balance1 - _reserve1;

        uint256 _totalSupply = totalSupply(); // gas savings, must be defined here since totalSupply can update in _mintFee
        if (_totalSupply == 0) {
            liquidity = Math.sqrt(amount0 * amount1) - MINIMUM_LIQUIDITY;
            _mint(address(0), MINIMUM_LIQUIDITY); // permanently lock the first MINIMUM_LIQUIDITY tokens
        } else {
            liquidity = Math.min(
                (amount0 * _totalSupply) / _reserve0,
                (amount1 * _totalSupply) / _reserve1
            );
        }

        //deduct reserve ratio from liquidity
        // uint256 _reserveRatio = calculateReserveRatio();
        // uint256 multiplier =  (1000 - (_reserveRatio / 1000);
        // liquidity = (liquidity * multiplier) / 1000;
        liquidity =
            (liquidity * (1000 - (this.calculateReserveRatio() / 1000))) /
            1000;

        require(liquidity > 0, "ILM");
        _mint(to, liquidity);

        _update(balance0, balance1);
        emit Mint(msg.sender, amount0, amount1);
    }

    function burn(address to)
        external
        override
        lock
        returns (uint256 amount0, uint256 amount1)
    {
        address _token0 = token0; // gas savings
        address _token1 = token1; // gas savings
        uint256 balance0 = IERC20(_token0).balanceOf(address(this));
        uint256 balance1 = IERC20(_token1).balanceOf(address(this));
        uint256 liquidity = this.balanceOf(address(this));

        uint256 _totalSupply = totalSupply();
        amount0 = balance0 * (liquidity / _totalSupply);
        amount1 = balance1 * (liquidity / _totalSupply);

        require(amount0 > 0 && amount1 > 0, "ILB");

        _burn(address(this), liquidity);
        SafeERC20.safeTransfer(IERC20(_token0), to, amount0);
        SafeERC20.safeTransfer(IERC20(_token1), to, amount1);

        for (uint256 i = 0; i < whitelist.length; ++i) {
            uint256 balance = IERC20(whitelist[i]).balanceOf(address(this));
            if (balance > 0) {
                uint256 amount = balance * (liquidity / _totalSupply);
                SafeERC20.safeTransfer(IERC20(_token0), to, amount);
            }
        }

        balance0 = IERC20(_token0).balanceOf(address(this));
        balance1 = IERC20(_token1).balanceOf(address(this));

        _update(balance0, balance1);
        emit Burn(msg.sender, amount0, amount1, to);
    }

    function setWhitelist(address[] memory _whitelist)
        external
        override
        onlyFactoryAdmin
    {
        require(_whitelist.length <= 8, "MW");

        address[] memory _oldWL = whitelist;

        for (uint256 i = 0; i < _oldWL.length; ++i)
            whitelistAllowance[_oldWL[i]] = false;

        //set new whitelist
        whitelist = _whitelist;
        for (uint256 i = 0; i < _whitelist.length; ++i)
            whitelistAllowance[_whitelist[i]] = true;

        emit WhitelistChanged(_whitelist);
    }

    function setFactory(address _factory) external onlyFactoryAdmin {
        factory = _factory;
    }

    function setFee(uint256 _fee, uint256 _vFee)
        external
        override
        onlyFactoryAdmin
    {
        fee = _fee;
        vFee = _vFee;
    }
}
