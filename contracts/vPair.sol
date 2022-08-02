pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/utils/math/Math.sol";

import "./interfaces/IvPair.sol";
import "./interfaces/IvSwapPoolDeployer.sol";
import "./interfaces/IvPairFactory.sol";
import "./interfaces/IvFlashSwapCallback.sol";

import "./libraries/vSwapLibrary.sol";
import "./libraries/constants.sol";

import "./vSwapERC20.sol";

contract vPair is IvPair, vSwapERC20 {
    uint256 internal constant RESERVE_RATIO_WHOLE = (10**3) * 100 * 1e18;

    address public factory;

    address public immutable override token0;
    address public immutable override token1;

    uint24 public override fee;
    uint24 public override vFee;

    uint256 public override reserve0;
    uint256 public override reserve1;

    uint256 public max_reserve_ratio;

    address[] public whitelist;
    mapping(address => bool) public whitelistAllowance;
    uint24 public override max_whitelist_count;

    mapping(address => uint256) public override reservesBaseValue;
    mapping(address => uint256) public reserves;

    uint256 private unlocked = 1;
    modifier lock() {
        require(unlocked == 1, "L");
        unlocked = 0;
        _;
        unlocked = 1;
    }

    function _onlyFactoryAdmin() internal view {
        require(msg.sender == IvPairFactory(factory).admin(), "OA");
    }

    modifier onlyFactoryAdmin() {
        _onlyFactoryAdmin();
        _;
    }

    modifier onlyForExchangeReserves() {
        require(msg.sender == IvPairFactory(factory).exchangeReserves(), "OER");
        _;
    }

    constructor() {
        (
            factory,
            token0,
            token1,
            fee,
            vFee,
            max_whitelist_count,
            max_reserve_ratio
        ) = IvSwapPoolDeployer(msg.sender).poolCreationParameters();
    }

    function _update(uint256 balance0, uint256 balance1) internal {
        reserve0 = balance0;
        reserve1 = balance1;

        emit Sync(balance0, balance1);
    }

    function getReserves()
        external
        view
        override
        returns (uint256 _reserve0, uint256 _reserve1)
    {
        return (reserve0, reserve1);
    }

    function getTokens()
        external
        view
        override
        returns (address _token0, address _token1)
    {
        return (token0, token1);
    }

    function swapNative(
        uint256 amountOut,
        address tokenOut,
        address to,
        bytes memory data
    ) external override lock returns (uint256 _amountIn) {
        require(to > address(0), "IT"); // INVALID TO

        SafeERC20.safeTransfer(IERC20(tokenOut), to, amountOut);

        address _tokenIn = tokenOut == token0 ? token1 : token0;

        (uint256 _reserve0, uint256 _reserve1) = vSwapLibrary.sortReserves(
            _tokenIn,
            token0,
            reserve0,
            reserve1
        );

        uint256 requiredAmountIn = vSwapLibrary.getAmountIn(
            amountOut,
            _reserve0,
            _reserve1,
            fee
        );

        if (data.length > 0) {
            IvFlashSwapCallback(msg.sender).vFlashSwapCallback(requiredAmountIn, data);
        }

        _amountIn = IERC20(_tokenIn).balanceOf(address(this)) - _reserve0;

        require(_amountIn > 0 && _amountIn >= requiredAmountIn, "IIA");

        bool _isTokenIn0 = _tokenIn == token0;

        _update(
            _isTokenIn0 ? _reserve0 + _amountIn : _reserve1 - amountOut,
            _isTokenIn0 ? _reserve1 - amountOut : _reserve0 + _amountIn
        );
    }

    function swapNativeToReserve(
        uint256 amountOut,
        address ikPair,
        address to,
        bytes calldata data
    )
        external
        override
        onlyForExchangeReserves
        lock
        returns (uint256 _amountIn)
    {
        VirtualPoolModel memory vPool = vSwapLibrary.getVirtualPool(
            ikPair,
            address(this)
        );

        // validate ikPair with factory
        require(
            IvPairFactory(factory).getPair(vPool.token1, vPool.commonToken) ==
                ikPair,
            "IIKP"
        );

        require(whitelistAllowance[vPool.token1], "TNW");
        require(vPool.token0 == token0 || vPool.token0 == token1, "NNT");

        SafeERC20.safeTransfer(IERC20(vPool.token1), to, amountOut);
        uint256 requiredAmountIn = 0;

        requiredAmountIn = vSwapLibrary.quote(
            amountOut,
            vPool.reserve1,
            vPool.reserve0
        );

        if (data.length > 0)
            IvFlashSwapCallback(msg.sender).vFlashSwapCallback(requiredAmountIn, data);

        _amountIn =
            IERC20(vPool.token0).balanceOf(address(this)) -
            (vPool.token0 == token0 ? reserve0 : reserve1);

        require(_amountIn > 0 && _amountIn >= requiredAmountIn, "IIA");

        // //update reserve balance in the equivalent of token0 value

        uint256 _reserveBaseValue = reserves[vPool.token1] - amountOut;

        //re-calculate price of reserve asset in token0 for the whole pool blance
        _reserveBaseValue = vSwapLibrary.quote(
            _reserveBaseValue,
            vPool.reserve0,
            vPool.reserve1
        );

        if (vPool.token0 == token1) {
            //if tokenOut is not token0 we should quote it to token0 value
            _reserveBaseValue = vSwapLibrary.quote(
                _reserveBaseValue,
                reserve1,
                reserve0
            );
        }

        reservesBaseValue[vPool.token1] = _reserveBaseValue;

        //update reserve balance
        reserves[vPool.token1] = reserves[vPool.token1] - amountOut;

        _update(
            IERC20(token0).balanceOf(address(this)),
            IERC20(token1).balanceOf(address(this))
        );
    }

    function swapReserveToNative(
        uint256 amountOut,
        address ikPair,
        address to,
        bytes calldata data
    ) external override lock returns (uint256 _amountIn) {
        VirtualPoolModel memory vPool = vSwapLibrary.getVirtualPoolBase(
            token0,
            token1,
            reserve0,
            reserve1,
            vFee,
            ikPair
        );

        // validate ikPair with factory
        require(
            IvPairFactory(factory).getPair(vPool.token0, vPool.commonToken) ==
                ikPair,
            "IIKP"
        );

        require(whitelistAllowance[vPool.token0], "TNW");
        require(vPool.token1 == token0 || vPool.token1 == token1, "NNT");

        SafeERC20.safeTransfer(IERC20(vPool.token1), to, amountOut);

        uint256 requiredAmountIn = vSwapLibrary.getAmountIn(
            amountOut,
            vPool.reserve0,
            vPool.reserve1,
            vFee
        );

        if (data.length > 0)
            IvFlashSwapCallback(msg.sender).vFlashSwapCallback(requiredAmountIn, data);

        _amountIn =
            IERC20(vPool.token0).balanceOf(address(this)) -
            reserves[vPool.token0];

        require(_amountIn > 0 && _amountIn >= requiredAmountIn, "IIA");

        //update reserve balance in the equivalent of token0 value

        uint256 _reserveBaseValue = reserves[vPool.token0] + _amountIn;

        //re-calculate price of reserve asset in token0 for the whole pool blance
        _reserveBaseValue = vSwapLibrary.quote(
            _reserveBaseValue,
            vPool.reserve0,
            vPool.reserve1
        );

        if (vPool.token1 == token1) {
            //if tokenOut is not token0 we should quote it to token0 value
            _reserveBaseValue = vSwapLibrary.quote(
                _reserveBaseValue,
                reserve1,
                reserve0
            );
        }

        reservesBaseValue[vPool.token0] = _reserveBaseValue;

        //update reserve balance
        reserves[vPool.token0] = reserves[vPool.token0] + _amountIn;

        require(this.calculateReserveRatio() < max_reserve_ratio, "TBPT"); // reserve amount goes beyond pool threshold

        _update(
            IERC20(token0).balanceOf(address(this)),
            IERC20(token1).balanceOf(address(this))
        );
    }

    function calculateReserveRatio()
        external
        view
        override
        returns (uint256 rRatio)
    {
        uint256 _reserve0 = reserve0;
        for (uint256 i = 0; i < whitelist.length; ++i) {
            uint256 _rReserve = reservesBaseValue[whitelist[i]];
            if (_rReserve > 0) {
                rRatio += (vSwapLibrary.percent(_rReserve, _reserve0 * 2) *
                    100);
            }
        }

        rRatio *= Constants.RESERVE_RATIO_FACTOR;
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

        uint256 _totalSupply = totalSupply();
        if (_totalSupply == 0) {
            liquidity =
                Math.sqrt(amount0 * amount1) -
                Constants.MINIMUM_LIQUIDITY;
            _mint(address(0), Constants.MINIMUM_LIQUIDITY); // permanently lock the first MINIMUM_LIQUIDITY tokens
        } else {
            liquidity = Math.min(
                (amount0 * _totalSupply) / _reserve0,
                (amount1 * _totalSupply) / _reserve1
            );
        }

        //substract reserve ratio PCT from minted liquidity tokens amount
        uint256 reserveRatio = this.calculateReserveRatio();

        liquidity =
            liquidity -
            ((liquidity * reserveRatio) / (RESERVE_RATIO_WHOLE + reserveRatio));

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
        amount0 = (balance0 * liquidity) / _totalSupply;
        amount1 = (balance1 * liquidity) / _totalSupply;

        require(amount0 > 0 && amount1 > 0, "ILB");

        _burn(address(this), liquidity);
        SafeERC20.safeTransfer(IERC20(_token0), to, amount0);
        SafeERC20.safeTransfer(IERC20(_token1), to, amount1);

        //distribute reserve tokens and update reserve ratios
        uint256 _currentReserveRatio = this.calculateReserveRatio();
        if (_currentReserveRatio > 0) {
            for (uint256 i = 0; i < whitelist.length; ++i) {
                address _wlI = whitelist[i];
                uint256 reserveBalance = reserves[_wlI];

                if (reserveBalance > 0) {
                    uint256 reserveAmountOut = (reserveBalance * liquidity) /
                        _totalSupply;

                    SafeERC20.safeTransfer(IERC20(_wlI), to, reserveAmountOut);

                    uint256 reserveBaseValuewlI = reservesBaseValue[_wlI]; //gas saving

                    reservesBaseValue[_wlI] =
                        reserveBaseValuewlI -
                        ((reserveBaseValuewlI * liquidity) / _totalSupply);

                    reserves[_wlI] = reserveBalance - reserveAmountOut;
                }
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
        require(_whitelist.length < max_whitelist_count, "MW");

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

    function setFee(uint24 _fee, uint24 _vFee)
        external
        override
        onlyFactoryAdmin
    {
        fee = _fee;
        vFee = _vFee;
    }

    function setMaxReserveThreshold(uint256 threshold)
        external
        override
        onlyFactoryAdmin
    {
        max_reserve_ratio = threshold;
    }

    function setMaxWhitelistCount(uint24 maxWhitelist)
        external
        override
        onlyFactoryAdmin
    {
        max_whitelist_count = maxWhitelist;
    }
}
