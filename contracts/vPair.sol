// SPDX-License-Identifier: Apache-2.0

pragma solidity 0.8.2;

import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import '@openzeppelin/contracts/token/ERC20/IERC20.sol';
import '@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol';
import '@openzeppelin/contracts/utils/math/Math.sol';
import '@uniswap/v3-core/contracts/interfaces/IERC20Minimal.sol';

import './interfaces/IvPair.sol';
import './interfaces/IvSwapPoolDeployer.sol';
import './interfaces/IvPairFactory.sol';
import './interfaces/IvFlashSwapCallback.sol';
import './libraries/vSwapLibrary.sol';
import './vSwapERC20.sol';

contract vPair is IvPair, vSwapERC20, ReentrancyGuard {
    uint24 internal constant BASE_FACTOR = 1000;
    uint24 internal constant MINIMUM_LIQUIDITY = BASE_FACTOR;
    uint24 internal constant RESERVE_RATIO_FACTOR = BASE_FACTOR;
    uint256 internal constant RESERVE_RATIO_WHOLE = (10**3) * 100 * 1e18;

    address public factory;

    address public immutable override token0;
    address public immutable override token1;

    uint24 public override fee;
    uint24 public override vFee;

    uint256 public override pairBalance0;
    uint256 public override pairBalance1;

    uint256 private _lastBlockUpdated;
    uint256 private _lastPairBalance0;
    uint256 private _lastPairBalance1;

    uint256 public maxReserveRatio;

    address[] public allowList;
    mapping(address => bool) public allowListMap;
    uint24 public override maxAllowListCount;

    mapping(address => uint256) public override reservesBaseValue;
    mapping(address => uint256) public override reserves;

    function _onlyFactoryAdmin() internal view {
        require(msg.sender == IvPairFactory(factory).admin(), 'OA');
    }

    modifier onlyFactoryAdmin() {
        _onlyFactoryAdmin();
        _;
    }

    modifier onlyForExchangeReserves() {
        require(msg.sender == IvPairFactory(factory).exchangeReserves(), 'OER');
        _;
    }

    /// @dev This function is gas optimized to avoid a redundant extcodesize check in addition to the returndatasize
    function fetchBalance(address token) internal view returns (uint256) {
        (bool success, bytes memory data) = token.staticcall(
            abi.encodeWithSelector(
                IERC20Minimal.balanceOf.selector,
                address(this)
            )
        );
        require(success && data.length >= 32);
        return abi.decode(data, (uint256));
    }

    constructor() {
        (
            factory,
            token0,
            token1,
            fee,
            vFee,
            maxAllowListCount,
            maxReserveRatio
        ) = IvSwapPoolDeployer(msg.sender).poolCreationDefaults();
    }

    function _update(uint256 balance0, uint256 balance1) internal {
        if (block.number > _lastBlockUpdated) {
            (_lastPairBalance0, _lastPairBalance1) = (balance0, balance1);
            _lastBlockUpdated = block.number;
        }

        (pairBalance0, pairBalance1) = (balance0, balance1);

        emit Sync(balance0, balance1);
    }

    function getLastBalances()
        external
        view
        override
        returns (
            uint256 _lastBalance0,
            uint256 _lastBalance1,
            uint256 _blockNumber
        )
    {
        return (_lastPairBalance0, _lastPairBalance1, _lastBlockUpdated);
    }

    function getBalances()
        external
        view
        override
        returns (uint256 _balance0, uint256 _balance1)
    {
        return (pairBalance0, pairBalance1);
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
        bytes calldata data
    ) external override nonReentrant returns (uint256 _amountIn) {
        require(to > address(0) && to != token0 && to != token1, 'IT');
        require(tokenOut == token0 || tokenOut == token1, 'NNT');
        require(amountOut > 0, 'IAO');

        SafeERC20.safeTransfer(IERC20(tokenOut), to, amountOut);

        address _tokenIn = tokenOut == token0 ? token1 : token0;

        (uint256 _balanceIn, uint256 _balanceOut) = vSwapLibrary.sortBalances(
            _tokenIn,
            token0,
            pairBalance0,
            pairBalance1
        );

        require(amountOut <= _balanceOut, 'AOE');

        uint256 requiredAmountIn = vSwapLibrary.getAmountIn(
            amountOut,
            _balanceIn,
            _balanceOut,
            fee
        );

        if (data.length > 0) {
            IvFlashSwapCallback(msg.sender).vFlashSwapCallback(
                _tokenIn,
                tokenOut,
                requiredAmountIn,
                data
            );
        }

        _amountIn = fetchBalance(_tokenIn) - _balanceIn;

        require(_amountIn > 0 && _amountIn >= requiredAmountIn, 'IIA');

        {
            //avoid stack too deep
            bool _isTokenIn0 = _tokenIn == token0;

            _update(
                _isTokenIn0 ? _balanceIn + _amountIn : _balanceOut - amountOut,
                _isTokenIn0 ? _balanceOut - amountOut : _balanceIn + _amountIn
            );
        }

        emit Swap(
            msg.sender,
            _tokenIn,
            tokenOut,
            requiredAmountIn,
            amountOut,
            to
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
        nonReentrant
        returns (uint256 _amountIn)
    {
        require(amountOut > 0, 'IAO');
        require(to > address(0) && to != token0 && to != token1, 'IT');

        VirtualPoolModel memory vPool = vSwapLibrary.getVirtualPool(
            ikPair,
            address(this)
        );

        // validate ikPair with factory
        require(
            IvPairFactory(factory).getPair(vPool.token1, vPool.commonToken) ==
                ikPair,
            'IIKP'
        );

        require(amountOut <= vPool.balance1, 'AOE');
        require(allowListMap[vPool.token1], 'TNW');
        require(vPool.token0 == token0 || vPool.token0 == token1, 'NNT');

        SafeERC20.safeTransfer(IERC20(vPool.token1), to, amountOut);
        uint256 requiredAmountIn = 0;

        requiredAmountIn = vSwapLibrary.quote(
            amountOut,
            vPool.balance1,
            vPool.balance0
        );

        if (data.length > 0)
            IvFlashSwapCallback(msg.sender).vFlashSwapCallback(
                vPool.token0,
                vPool.token1,
                requiredAmountIn,
                data
            );

        _amountIn =
            fetchBalance(vPool.token0) -
            (vPool.token0 == token0 ? pairBalance0 : pairBalance1);

        require(_amountIn > 0 && _amountIn >= requiredAmountIn, 'IIA');

        // //update reserve balance in the equivalent of token0 value

        uint256 _reserveBaseValue = reserves[vPool.token1] - amountOut;
        if (_reserveBaseValue > 0) {
            // //re-calculate price of reserve asset in token0 for the whole pool blance
            _reserveBaseValue = vSwapLibrary.quote(
                _reserveBaseValue,
                vPool.balance1,
                vPool.balance0
            );
        }

        if (_reserveBaseValue > 0 && vPool.token0 == token1) {
            //if tokenOut is not token0 we should quote it to token0 value
            _reserveBaseValue = vSwapLibrary.quote(
                _reserveBaseValue,
                pairBalance1,
                pairBalance0
            );
        }

        reservesBaseValue[vPool.token1] = _reserveBaseValue;

        //update reserve balance
        reserves[vPool.token1] -= amountOut;

        _update(fetchBalance(token0), fetchBalance(token1));

        emit ReserveSync(vPool.token1, reserves[vPool.token1]);
        emit SwapReserve(
            msg.sender,
            vPool.token0,
            vPool.token1,
            requiredAmountIn,
            amountOut,
            ikPair,
            to
        );
    }

    function swapReserveToNative(
        uint256 amountOut,
        address ikPair,
        address to,
        bytes calldata data
    ) external override nonReentrant returns (uint256 amountIn) {
        require(amountOut > 0, 'IAO');
        require(to > address(0) && to != token0 && to != token1, 'IT');

        VirtualPoolModel memory vPool = vSwapLibrary.getVirtualPoolBase(
            token0,
            token1,
            pairBalance0,
            pairBalance1,
            vFee,
            ikPair
        );

        // validate ikPair with factory
        require(
            IvPairFactory(factory).getPair(vPool.token0, vPool.commonToken) ==
                ikPair,
            'IIKP'
        );

        require(amountOut <= vPool.balance1, 'AOE');
        require(allowListMap[vPool.token0], 'TNW');
        require(vPool.token1 == token0 || vPool.token1 == token1, 'NNT');

        SafeERC20.safeTransfer(IERC20(vPool.token1), to, amountOut);

        uint256 requiredAmountIn = vSwapLibrary.getAmountIn(
            amountOut,
            vPool.balance0,
            vPool.balance1,
            vFee
        );

        if (data.length > 0)
            IvFlashSwapCallback(msg.sender).vFlashSwapCallback(
                vPool.token0,
                vPool.token1,
                requiredAmountIn,
                data
            );

        amountIn = fetchBalance(vPool.token0) - reserves[vPool.token0];

        require(amountIn > 0 && amountIn >= requiredAmountIn, 'IIA');

        //update reserve balance in the equivalent of token0 value
        uint256 _reserveBaseValue = reserves[vPool.token0] + amountIn;

        //re-calculate price of reserve asset in token0 for the whole pool blance
        _reserveBaseValue = vSwapLibrary.quote(
            _reserveBaseValue,
            vPool.balance0,
            vPool.balance1
        );

        if (vPool.token1 == token1) {
            //if tokenOut is not token0 we should quote it to token0 value
            _reserveBaseValue = vSwapLibrary.quote(
                _reserveBaseValue,
                pairBalance1,
                pairBalance0
            );
        }

        reservesBaseValue[vPool.token0] = _reserveBaseValue;

        //update reserve balance
        reserves[vPool.token0] += amountIn;

        require(calculateReserveRatio() < maxReserveRatio, 'TBPT'); // reserve amount goes beyond pool threshold

        _update(fetchBalance(token0), fetchBalance(token1));

        emit ReserveSync(vPool.token0, reserves[vPool.token0]);
        emit SwapReserve(
            msg.sender,
            vPool.token0,
            vPool.token1,
            requiredAmountIn,
            amountOut,
            ikPair,
            to
        );
    }

    function calculateReserveRatio()
        public
        view
        override
        returns (uint256 rRatio)
    {
        uint256 _balance0 = pairBalance0;
        for (uint256 i = 0; i < allowList.length; ++i) {
            uint256 _rReserve = reservesBaseValue[allowList[i]];
            if (_rReserve > 0) {
                rRatio += (vSwapLibrary.percent(_rReserve, _balance0 * 2) *
                    100);
            }
        }

        rRatio *= RESERVE_RATIO_FACTOR;
    }

    function mint(address to)
        external
        override
        nonReentrant
        returns (uint256 liquidity)
    {
        (uint256 _pairBalance0, uint256 _pairBalance1) = (
            pairBalance0,
            pairBalance1
        );
        uint256 currentBalance0 = fetchBalance(token0);
        uint256 currentBalance1 = fetchBalance(token1);
        uint256 amount0 = currentBalance0 - _pairBalance0;
        uint256 amount1 = currentBalance1 - _pairBalance1;

        uint256 _totalSupply = totalSupply();
        if (_totalSupply == 0) {
            liquidity = Math.sqrt(amount0 * amount1) - MINIMUM_LIQUIDITY;
            _mint(address(0), MINIMUM_LIQUIDITY); // permanently lock the first MINIMUM_LIQUIDITY tokens
        } else {
            liquidity = Math.min(
                (amount0 * _totalSupply) / _pairBalance0,
                (amount1 * _totalSupply) / _pairBalance1
            );
        }

        //substract reserve ratio PCT from minted liquidity tokens amount
        uint256 reserveRatio = calculateReserveRatio();

        liquidity =
            liquidity -
            ((liquidity * reserveRatio) / (RESERVE_RATIO_WHOLE + reserveRatio));

        require(liquidity > 0, 'ILM');

        _mint(to, liquidity);

        _update(currentBalance0, currentBalance1);
        emit Mint(msg.sender, amount0, amount1);
    }

    function burn(address to)
        external
        override
        nonReentrant
        returns (uint256 amount0, uint256 amount1)
    {
        address _token0 = token0; // gas savings
        address _token1 = token1; // gas savings
        uint256 balance0 = fetchBalance(_token0);
        uint256 balance1 = fetchBalance(_token1);
        uint256 liquidity = fetchBalance(address(this));

        uint256 _totalSupply = totalSupply();
        amount0 = (balance0 * liquidity) / _totalSupply;
        amount1 = (balance1 * liquidity) / _totalSupply;

        require(amount0 > 0 && amount1 > 0, 'ILB');

        _burn(address(this), liquidity);
        SafeERC20.safeTransfer(IERC20(_token0), to, amount0);
        SafeERC20.safeTransfer(IERC20(_token1), to, amount1);

        //distribute reserve tokens and update reserve ratios
        uint256 _currentReserveRatio = calculateReserveRatio();
        if (_currentReserveRatio > 0) {
            for (uint256 i = 0; i < allowList.length; ++i) {
                address _wlI = allowList[i];
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

        balance0 = fetchBalance(_token0);
        balance1 = fetchBalance(_token1);

        _update(balance0, balance1);
        emit Burn(msg.sender, amount0, amount1, to);
    }

    function setAllowList(address[] memory _allowList)
        external
        override
        onlyFactoryAdmin
    {
        require(allowList.length < maxAllowListCount, 'MW');

        address[] memory _oldWL = allowList;

        for (uint256 i = 0; i < _oldWL.length; ++i)
            allowListMap[_oldWL[i]] = false;

        //set new allowList
        allowList = _allowList;
        for (uint256 i = 0; i < _allowList.length; ++i)
            allowListMap[_allowList[i]] = true;

        emit AllowListChanged(_allowList);
    }

    function setFactory(address _factory) external onlyFactoryAdmin {
        require(_factory > address(0) && _factory != factory, 'IFA');
        factory = _factory;

        emit FactoryChanged(_factory);
    }

    function setFee(uint24 _fee, uint24 _vFee)
        external
        override
        onlyFactoryAdmin
    {
        require(_fee > 0 && _vFee > 0 && _fee < 1000 && _vFee < 1000, 'IFC');
        fee = _fee;
        vFee = _vFee;

        emit FeeChanged(_fee, _vFee);
    }

    function setMaxReserveThreshold(uint256 threshold)
        external
        override
        onlyFactoryAdmin
    {
        require(threshold > 0, 'IRT');
        maxReserveRatio = threshold;

        emit ReserveThresholdChanged(threshold);
    }

    function setMaxAllowListCount(uint24 _maxAllowListCount)
        external
        override
        onlyFactoryAdmin
    {
        maxAllowListCount = _maxAllowListCount;
        emit AllowListCountChanged(_maxAllowListCount);
    }
}
