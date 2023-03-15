// SPDX-License-Identifier: Apache-2.0

pragma solidity 0.8.2;

import './types.sol';
import './libraries/vSwapLibrary.sol';
import './interfaces/IvPairFactory.sol';
import './interfaces/IvPair.sol';
import './interfaces/IvPoolManager.sol';

contract vPoolManager is IvPoolManager {
    struct VirtualPoolWithBlock {
        VirtualPoolModel vPool;
        uint256 blockLastUpdated;
    }

    mapping(address => mapping(address => VirtualPoolWithBlock)) vPoolsCache;

    address public immutable pairFactory;

    constructor(address _pairFactory) {
        pairFactory = _pairFactory;
    }

    function getVirtualPool(
        address jkPair,
        address ikPair
    ) public view override returns (VirtualPoolModel memory vPool) {
        VirtualPoolWithBlock memory vPoolWithBlock = vPoolsCache[jkPair][
            ikPair
        ];
        if (block.number == vPoolWithBlock.blockLastUpdated) {
            vPool = vPoolWithBlock.vPool;
            _reduceBalances(vPool);
        } else {
            vPool = vSwapLibrary.getVirtualPool(jkPair, ikPair);
        }
    }

    function getVirtualPools(
        address token0,
        address token1
    ) external view override returns (VirtualPoolModel[] memory vPools) {
        uint256 allPairsLength = IvPairFactory(pairFactory).allPairsLength();
        uint256 vPoolsNumber;
        address jk0;
        address jk1;
        address jkPair;
        for (uint256 i = 0; i < allPairsLength; ++i) {
            jkPair = IvPairFactory(pairFactory).allPairs(i);
            (jk0, jk1) = IvPair(jkPair).getTokens();
            if (
                (jk0 == token1 || jk1 == token1) &&
                jk0 != token0 &&
                jk1 != token0 &&
                IvPair(jkPair).allowListMap(token0) &&
                IvPairFactory(pairFactory).getPair(
                    token0,
                    jk0 == token1 ? jk1 : jk0
                ) !=
                address(0)
            ) {
                ++vPoolsNumber;
            }
        }
        vPools = new VirtualPoolModel[](vPoolsNumber);
        address ikPair;
        for (uint256 i = 0; i < allPairsLength; ++i) {
            jkPair = IvPairFactory(pairFactory).allPairs(i);
            (jk0, jk1) = IvPair(jkPair).getTokens();
            if (
                (jk0 == token1 || jk1 == token1) &&
                jk0 != token0 &&
                jk1 != token0 &&
                IvPair(jkPair).allowListMap(token0)
            ) {
                ikPair = IvPairFactory(pairFactory).getPair(
                    token0,
                    jk0 == token1 ? jk1 : jk0
                );
                if (ikPair != address(0)) {
                    vPools[--vPoolsNumber] = getVirtualPool(jkPair, ikPair);
                }
            }
        }
    }

    function updateVirtualPoolBalances(
        VirtualPoolModel memory vPool,
        uint256 balance0,
        uint256 balance1
    ) external override {
        require(
            msg.sender ==
                IvPairFactory(pairFactory).getPair(
                    vPool.commonToken,
                    vPool.token0
                ) ||
                msg.sender ==
                IvPairFactory(pairFactory).getPair(
                    vPool.commonToken,
                    vPool.token1
                ),
            'Only pools'
        );
        vPool.balance0 = balance0;
        vPool.balance1 = balance1;
        vPoolsCache[vPool.jkPair][vPool.ikPair] = VirtualPoolWithBlock(
            vPool,
            block.number
        );
    }

    function _reduceBalances(VirtualPoolModel memory vPool) private view {
        (uint256 ikBalance0, uint256 ikBalance1) = IvPair(vPool.ikPair)
            .getBalances();

        if (
            vPool.token0 == IvPair(vPool.ikPair).token1() &&
            ikBalance0 != ikBalance1
        ) {
            // swap
            ikBalance0 ^= ikBalance1;
            ikBalance1 ^= ikBalance0;
            ikBalance0 ^= ikBalance1;
        }

        (uint256 jkBalance0, uint256 jkBalance1) = IvPair(vPool.jkPair)
            .getBalances();

        if (
            vPool.token1 == IvPair(vPool.jkPair).token1() &&
            jkBalance0 != jkBalance1
        ) {
            // swap
            jkBalance0 ^= jkBalance1;
            jkBalance1 ^= jkBalance0;
            jkBalance0 ^= jkBalance1;
        }

        // Make sure vPool balances are less or equal than real pool balances
        if (vPool.balance0 >= ikBalance0) {
            vPool.balance1 = (vPool.balance1 * ikBalance0) / vPool.balance0;
            vPool.balance0 = ikBalance0;
        }
        if (vPool.balance1 >= jkBalance0) {
            vPool.balance0 = (vPool.balance0 * jkBalance0) / vPool.balance1;
            vPool.balance1 = jkBalance0;
        }
    }
}
