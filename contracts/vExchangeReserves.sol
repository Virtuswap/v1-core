// SPDX-License-Identifier: Apache-2.0
pragma solidity 0.8.2;

import '@openzeppelin/contracts/token/ERC20/IERC20.sol';
import '@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol';
import '@openzeppelin/contracts/utils/Multicall.sol';

import './types.sol';
import './libraries/PoolAddress.sol';
import './interfaces/IvPair.sol';
import './interfaces/IvExchangeReserves.sol';
import './interfaces/IvPairFactory.sol';

contract vExchangeReserves is IvExchangeReserves, Multicall {
    address public immutable factory;
    uint256 public incentivesLimitPct;

    constructor(address _factory) {
        factory = _factory;
        incentivesLimitPct = 1;
    }

    function changeIncentivesLimitPct(uint256 newLimit) external override {
        require(msg.sender == IvPairFactory(factory).admin(), 'Admin only');
        require(newLimit <= 100, 'Invalid limit');
        incentivesLimitPct = newLimit;
        emit NewIncentivesLimit(newLimit);
    }

    function vFlashSwapCallback(
        address tokenIn,
        address tokenOut,
        uint256 requiredBackAmount,
        bytes calldata data
    ) external override {
        ExchangeReserveCallbackParams memory decodedData = abi.decode(
            data,
            (ExchangeReserveCallbackParams)
        );

        (address jk0, address jk1) = IvPair(decodedData.jkPair1).getTokens();
        require(
            msg.sender == PoolAddress.computeAddress(factory, jk0, jk1),
            'IC'
        );

        (address _leftoverToken, uint256 _leftoverAmount) = IvPair(
            decodedData.jkPair2
        ).swapNativeToReserve(
                requiredBackAmount,
                decodedData.ikPair2,
                decodedData.jkPair1,
                incentivesLimitPct,
                new bytes(0)
            );

        if (_leftoverAmount > 0)
            SafeERC20.safeTransfer(
                IERC20(_leftoverToken),
                decodedData.caller,
                _leftoverAmount
            );

        emit ReservesExchanged(
            decodedData.jkPair1,
            decodedData.ikPair1,
            decodedData.jkPair2,
            decodedData.ikPair2,
            requiredBackAmount,
            decodedData.flashAmountOut,
            _leftoverToken,
            _leftoverAmount
        );
    }

    function exchange(
        address jkPair1,
        address ikPair1,
        address jkPair2,
        address ikPair2,
        uint256 flashAmountOut
    ) external override {
        address _jkToken0;
        address _jkToken1;
        (_jkToken0, _jkToken1) = IvPair(jkPair1).getTokens();
        require(
            IvPairFactory(factory).pairs(_jkToken0, _jkToken1) != address(0),
            'IJKP1'
        );
        (_jkToken0, _jkToken1) = IvPair(jkPair2).getTokens();
        require(
            IvPairFactory(factory).pairs(_jkToken0, _jkToken1) != address(0),
            'IJKP2'
        );

        IvPair(jkPair1).swapNativeToReserve(
            flashAmountOut,
            ikPair1,
            jkPair2,
            incentivesLimitPct,
            abi.encode(
                ExchangeReserveCallbackParams({
                    jkPair1: jkPair1,
                    ikPair1: ikPair1,
                    jkPair2: jkPair2,
                    ikPair2: ikPair2,
                    flashAmountOut: flashAmountOut,
                    caller: msg.sender
                })
            )
        );
    }
}
