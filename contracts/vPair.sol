// SPDX-License-Identifier: Apache-2.0

pragma solidity 0.8.18;

import '@openzeppelin/contracts/security/ReentrancyGuard.sol';
import '@openzeppelin/contracts/token/ERC20/IERC20.sol';
import '@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol';
import '@openzeppelin/contracts/utils/math/Math.sol';

import './interfaces/IvPair.sol';
import './interfaces/IvSwapPoolDeployer.sol';
import './interfaces/IvPairFactory.sol';
import './interfaces/IvPoolManager.sol';
import './interfaces/IvFlashSwapCallback.sol';
import './libraries/vSwapLibrary.sol';
import './vSwapERC20.sol';

contract vPair is IvPair, vSwapERC20, ReentrancyGuard {
    uint24 internal constant BASE_FACTOR = 1000;
    uint24 internal constant MINIMUM_LIQUIDITY = BASE_FACTOR;
    uint24 internal constant RESERVE_RATIO_FACTOR = BASE_FACTOR * 100;

    address public immutable factory;
    address public immutable override token0;
    address public immutable override token1;

    uint112 public override pairBalance0;
    uint112 public override pairBalance1;
    uint16 public override fee;
    uint16 public override vFee;

    uint128 public override lastSwapBlock;
    uint128 public override blocksDelay;

    uint256 public override reservesBaseValueSum;
    uint256 public override maxReserveRatio;
    uint256 public reserveRatioWarningThreshold;

    address[] public allowList;
    mapping(address => bool) public override allowListMap;
    bool public closed;

    mapping(address => uint256) public override reservesBaseValue;
    mapping(address => uint256) public override reserves;

    function _onlyFactoryAdmin() internal view {
        require(
            msg.sender == IvPairFactory(factory).admin() ||
                msg.sender == factory,
            'OA'
        );
    }

    modifier onlyFactoryAdmin() {
        _onlyFactoryAdmin();
        _;
    }

    modifier onlyEmergencyAdmin() {
        require(msg.sender == IvPairFactory(factory).emergencyAdmin(), 'OE');
        _;
    }

    modifier isOpen() {
        require(!closed, 'C');
        _;
    }

    /// @dev This function is gas optimized to avoid a redundant extcodesize check in addition to the returndatasize
    function fetchBalance(address token) internal view returns (uint256) {
        (bool success, bytes memory data) = token.staticcall(
            abi.encodeWithSignature('balanceOf(address)', address(this))
        );
        require(success && data.length >= 32, 'FBF');
        return abi.decode(data, (uint256));
    }

    constructor() {
        (
            factory,
            token0,
            token1,
            fee,
            vFee,
            maxReserveRatio
        ) = IvSwapPoolDeployer(msg.sender).poolCreationDefaults();
        reserveRatioWarningThreshold = 1900;
        blocksDelay = 40;
    }

    function _update(uint112 balance0, uint112 balance1) internal {
        lastSwapBlock = uint128(block.number);

        (pairBalance0, pairBalance1) = (balance0, balance1);

        emit vSync(balance0, balance1);
    }

    function getBalances()
        external
        view
        override
        returns (uint112 _balance0, uint112 _balance1)
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
    ) external override nonReentrant isOpen returns (uint256 _amountIn) {
        require(to > address(0) && to != token0 && to != token1, 'IT');
        require(tokenOut == token0 || tokenOut == token1, 'NNT');
        require(amountOut > 0, 'IAO');

        address _tokenIn = tokenOut == token0 ? token1 : token0;

        (uint256 _balanceIn, uint256 _balanceOut) = vSwapLibrary.sortBalances(
            _tokenIn,
            token0,
            pairBalance0,
            pairBalance1
        );

        require(amountOut < _balanceOut, 'AOE');

        SafeERC20.safeTransfer(IERC20(tokenOut), to, amountOut);

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
                uint112(
                    _isTokenIn0
                        ? _balanceIn + _amountIn
                        : _balanceOut - amountOut
                ),
                uint112(
                    _isTokenIn0
                        ? _balanceOut - amountOut
                        : _balanceIn + _amountIn
                )
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
        uint256 incentivesLimitPct,
        bytes calldata data
    )
        external
        override
        nonReentrant
        isOpen
        returns (address _leftoverToken, uint256 _leftoverAmount)
    {
        require(msg.sender == IvPairFactory(factory).exchangeReserves(), 'OA');
        require(to > address(0) && to != token0 && to != token1, 'IT');

        VirtualPoolModel memory vPool = IvPoolManager(
            IvPairFactory(factory).vPoolManager()
        ).getVirtualPool(ikPair, address(this));

        // validate ikPair with factory
        require(
            IvPairFactory(factory).pairs(vPool.token1, vPool.commonToken) ==
                ikPair,
            'IIKP'
        );
        require(
            amountOut <= vPool.balance1 && amountOut <= reserves[vPool.token1],
            'AOE'
        );
        require(allowListMap[vPool.token1], 'TNW');
        require(vPool.token0 == token0 || vPool.token0 == token1, 'NNT');

        SafeERC20.safeTransfer(IERC20(vPool.token1), to, amountOut);
        uint256 requiredAmountIn = vSwapLibrary.quote(
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

        {
            // scope to avoid stack too deep errors
            uint256 balanceDiff = fetchBalance(vPool.token0) -
                (vPool.token0 == token0 ? pairBalance0 : pairBalance1);
            require(balanceDiff >= requiredAmountIn, 'IBD');
            (_leftoverAmount, _leftoverToken) = (
                Math.min(
                    balanceDiff - requiredAmountIn,
                    (balanceDiff * incentivesLimitPct) / 100
                ),
                vPool.token0
            );
            if (_leftoverAmount > 0) {
                SafeERC20.safeTransfer(
                    IERC20(_leftoverToken),
                    msg.sender,
                    _leftoverAmount
                );
            }
            IvPoolManager(IvPairFactory(factory).vPoolManager())
                .updateVirtualPoolBalances(
                    ikPair,
                    address(this),
                    vPool.balance0 + balanceDiff - _leftoverAmount,
                    vPool.balance1 - amountOut
                );
        }

        {
            // scope to avoid stack too deep errors
            // //update reserve balance in the equivalent of token0 value
            uint256 reserveTokenBalance = fetchBalance(vPool.token1);
            // //re-calculate price of reserve asset in token0 for the whole pool balance
            uint256 _reserveBaseValue = reserveTokenBalance > 0
                ? vSwapLibrary.quote(
                    reserveTokenBalance,
                    vPool.balance1,
                    vPool.balance0
                )
                : 0;

            if (_reserveBaseValue > 0 && vPool.token0 == token1) {
                //if tokenOut is not token0 we should quote it to token0 value
                _reserveBaseValue = vSwapLibrary.quote(
                    _reserveBaseValue,
                    pairBalance1,
                    pairBalance0
                );
            }
            unchecked {
                reservesBaseValueSum += _reserveBaseValue;
                reservesBaseValueSum -= reservesBaseValue[vPool.token1];
            }
            reservesBaseValue[vPool.token1] = _reserveBaseValue;
            //update reserve balance
            reserves[vPool.token1] = reserveTokenBalance;
        }

        _update(uint112(fetchBalance(token0)), uint112(fetchBalance(token1)));

        emit ReserveSync(
            vPool.token1,
            reserves[vPool.token1],
            calculateReserveRatio()
        );
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

    function allowListLength() external view returns (uint) {
        return allowList.length;
    }

    function liquidateReserve(
        address reserveToken,
        address nativePool
    ) external override nonReentrant {
        require(
            (msg.sender == IvPairFactory(factory).admin() &&
                calculateReserveRatio() >= reserveRatioWarningThreshold) ||
                msg.sender == IvPairFactory(factory).emergencyAdmin(),
            'OA'
        );
        require(allowListMap[reserveToken], 'TNW');

        (address nativeToken0, address nativeToken1) = IvPair(nativePool)
            .getTokens();
        (uint256 nativeBalance0, uint256 nativeBalance1) = IvPair(nativePool)
            .getBalances();
        if (nativeToken0 != reserveToken) {
            (nativeToken0, nativeToken1) = (nativeToken1, nativeToken0);
            (nativeBalance0, nativeBalance1) = (nativeBalance1, nativeBalance0);
        }
        uint256 reserveAmount = reserves[reserveToken];

        require(
            (nativeToken1 == token0 || nativeToken1 == token1) &&
                IvPairFactory(factory).pairs(reserveToken, nativeToken1) ==
                nativePool,
            'INP'
        );

        unchecked {
            reservesBaseValueSum -= reservesBaseValue[reserveToken];
        }
        reservesBaseValue[reserveToken] = 0;
        reserves[reserveToken] = 0;

        SafeERC20.safeTransfer(IERC20(reserveToken), nativePool, reserveAmount);
        IvPair(nativePool).swapNative(
            vSwapLibrary.getAmountOut(
                reserveAmount,
                nativeBalance0,
                nativeBalance1,
                IvPair(nativePool).fee()
            ),
            nativeToken1,
            address(this),
            new bytes(0)
        );

        _update(uint112(fetchBalance(token0)), uint112(fetchBalance(token1)));

        emit ReserveSync(reserveToken, 0, calculateReserveRatio());
    }

    function swapReserveToNative(
        uint256 amountOut,
        address ikPair,
        address to,
        bytes calldata data
    ) external override nonReentrant isOpen returns (uint256 amountIn) {
        require(amountOut > 0, 'IAO');
        require(to > address(0) && to != token0 && to != token1, 'IT');

        VirtualPoolModel memory vPool = IvPoolManager(
            IvPairFactory(factory).vPoolManager()
        ).getVirtualPool(address(this), ikPair);

        // validate ikPair with factory
        require(
            IvPairFactory(factory).pairs(vPool.token0, vPool.commonToken) ==
                ikPair,
            'IIKP'
        );

        require(amountOut < vPool.balance1, 'AOE');

        uint256 requiredAmountIn = vSwapLibrary.getAmountIn(
            amountOut,
            vPool.balance0,
            vPool.balance1,
            vFee
        );

        SafeERC20.safeTransfer(IERC20(vPool.token1), to, amountOut);

        if (data.length > 0)
            IvFlashSwapCallback(msg.sender).vFlashSwapCallback(
                vPool.token0,
                vPool.token1,
                requiredAmountIn,
                data
            );

        uint256 tokenInBalance = fetchBalance(vPool.token0);
        amountIn = tokenInBalance - reserves[vPool.token0];

        require(amountIn >= requiredAmountIn, 'IIA');

        {
            //update reserve balance in the equivalent of token0 value
            //re-calculate price of reserve asset in token0 for the whole pool blance
            uint256 _reserveBaseValue = vSwapLibrary.quote(
                tokenInBalance,
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

            unchecked {
                reservesBaseValueSum += _reserveBaseValue;
                reservesBaseValueSum -= reservesBaseValue[vPool.token0];
            }
            reservesBaseValue[vPool.token0] = _reserveBaseValue;
        }

        //update reserve balance
        reserves[vPool.token0] = tokenInBalance;

        _update(uint112(fetchBalance(token0)), uint112(fetchBalance(token1)));

        uint256 reserveRatio = calculateReserveRatio();
        require(reserveRatio <= maxReserveRatio, 'TBPT'); // reserve amount goes beyond pool threshold

        IvPoolManager(IvPairFactory(factory).vPoolManager())
            .updateVirtualPoolBalances(
                address(this),
                ikPair,
                vPool.balance0 + amountIn,
                vPool.balance1 - amountOut
            );

        emit ReserveSync(vPool.token0, tokenInBalance, reserveRatio);

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
        uint256 _pairBalance0 = pairBalance0;
        rRatio = _pairBalance0 > 0
            ? (reservesBaseValueSum * RESERVE_RATIO_FACTOR) /
                (_pairBalance0 << 1)
            : 0;
    }

    function mint(
        address to
    ) external override nonReentrant isOpen returns (uint256 liquidity) {
        (uint256 _pairBalance0, uint256 _pairBalance1) = (
            pairBalance0,
            pairBalance1
        );
        uint256 currentBalance0 = fetchBalance(token0);
        uint256 currentBalance1 = fetchBalance(token1);
        uint256 amount0 = currentBalance0 - _pairBalance0;
        uint256 amount1 = currentBalance1 - _pairBalance1;

        uint256 totalSupply_ = totalSupply();
        if (totalSupply_ == 0) {
            liquidity = Math.sqrt(amount0 * amount1) - MINIMUM_LIQUIDITY;
            _mint(address(0), MINIMUM_LIQUIDITY); // permanently lock the first MINIMUM_LIQUIDITY tokens
        } else {
            liquidity = Math.min(
                (amount0 * totalSupply_) / _pairBalance0,
                (amount1 * totalSupply_) / _pairBalance1
            );
        }

        //substract reserve ratio PCT from minted liquidity tokens amount
        uint256 reserveRatio = calculateReserveRatio();

        liquidity =
            (liquidity * RESERVE_RATIO_FACTOR) /
            (RESERVE_RATIO_FACTOR + reserveRatio);

        require(liquidity > 0, 'ILM');

        _mint(to, liquidity);

        _update(uint112(currentBalance0), uint112(currentBalance1));
        emit Mint(to, amount0, amount1, liquidity, totalSupply());
    }

    function burn(
        address to
    )
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

        uint256 totalSupply_ = totalSupply();
        amount0 = (balance0 * liquidity) / totalSupply_;
        amount1 = (balance1 * liquidity) / totalSupply_;

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
                        totalSupply_;

                    SafeERC20.safeTransfer(IERC20(_wlI), to, reserveAmountOut);

                    uint256 reserveBaseValuewlI = reservesBaseValue[_wlI]; //gas saving

                    reservesBaseValue[_wlI] =
                        reserveBaseValuewlI -
                        ((reserveBaseValuewlI * liquidity) / totalSupply_);

                    unchecked {
                        reservesBaseValueSum += reservesBaseValue[_wlI];
                        reservesBaseValueSum -= reserveBaseValuewlI;
                    }

                    reserves[_wlI] = reserveBalance - reserveAmountOut;
                }
            }
        }

        balance0 = fetchBalance(_token0);
        balance1 = fetchBalance(_token1);

        _update(uint112(balance0), uint112(balance1));
        emit Burn(msg.sender, amount0, amount1, to, totalSupply());
    }

    function setAllowList(address[] memory _allowList) external override {
        require(
            msg.sender == factory ||
                msg.sender == IvPairFactory(factory).admin() ||
                msg.sender == IvPairFactory(factory).emergencyAdmin(),
            'OA'
        );
        for (uint i = 1; i < _allowList.length; ++i) {
            require(
                _allowList[i] > _allowList[i - 1],
                'allow list must be unique and sorted'
            );
        }

        address[] memory _oldWL = allowList;
        for (uint256 i = 0; i < _oldWL.length; ++i)
            allowListMap[_oldWL[i]] = false;

        //set new allowList
        allowList = _allowList;
        address token0_ = token0;
        address token1_ = token1;
        uint256 newReservesBaseValueSum;
        for (uint256 i = 0; i < _allowList.length; ++i)
            if (_allowList[i] != token0_ && _allowList[i] != token1_) {
                allowListMap[_allowList[i]] = true;
                newReservesBaseValueSum += reservesBaseValue[_allowList[i]];
            }
        reservesBaseValueSum = newReservesBaseValueSum;

        emit AllowListChanged(_allowList);
    }

    function setFee(
        uint16 _fee,
        uint16 _vFee
    ) external override onlyFactoryAdmin {
        require(_fee > 0 && _vFee > 0 && _fee < 1000 && _vFee < 1000, 'IFC');
        fee = _fee;
        vFee = _vFee;

        emit FeeChanged(_fee, _vFee);
    }

    function setMaxReserveThreshold(
        uint256 threshold
    ) external override onlyFactoryAdmin {
        require(threshold > 0, 'IRT');
        maxReserveRatio = threshold;
        emit ReserveThresholdChanged(threshold);
    }

    function setReserveRatioWarningThreshold(
        uint256 _reserveRatioWarningThreshold
    ) external override onlyEmergencyAdmin {
        require(_reserveRatioWarningThreshold <= maxReserveRatio, 'IRWT');
        reserveRatioWarningThreshold = _reserveRatioWarningThreshold;
        emit ReserveRatioWarningThresholdChanged(_reserveRatioWarningThreshold);
    }

    function emergencyToggle() external override onlyEmergencyAdmin {
        closed = !closed;
    }

    function setBlocksDelay(uint128 _newBlocksDelay) external override {
        require(
            msg.sender == IvPairFactory(factory).emergencyAdmin() ||
                msg.sender == IvPairFactory(factory).admin(),
            'OA'
        );
        blocksDelay = _newBlocksDelay;
        emit BlocksDelayChanged(_newBlocksDelay);
    }

    function reserveRatioFactor() external pure override returns (uint256) {
        return RESERVE_RATIO_FACTOR;
    }
}
