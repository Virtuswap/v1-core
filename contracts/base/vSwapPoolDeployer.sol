pragma solidity ^0.8.0;

import "../interfaces/IvSwapPoolDeployer.sol";
import "../types.sol";
import "../vPair.sol";
import "../libraries/PoolAddress.sol";

contract vSwapPoolDeployer is IvSwapPoolDeployer {

    PairCreationParams public override parameters;

    /// @dev Deploys a pool with the given parameters by transiently setting the parameters storage slot and then
    /// clearing it after deploying the pool.
    /// @param factory The contract address of the Uniswap V3 factory
    /// @param token0 The first token of the pool by address sort order
    /// @param token1 The second token of the pool by address sort order
    /// @param fee The fee collected upon every swap in the pool, denominated in hundredths of a bip
    function deployPair(
        address factory,
        address token0,
        address token1,
        uint24 fee,
        uint24 vFee,
        uint24 _max_whitelist_count,
        uint256 _max_reserve_ratio
    ) internal returns (address pool) {
        parameters = PairCreationParams({
            factory: factory,
            token0: token0,
            token1: token1,
            fee: fee,
            vFee: vFee,
            max_whitelist_count: _max_whitelist_count,
            max_reserve_ratio: _max_reserve_ratio
        });
        bytes32 _salt = PoolAddress.getSalt(token0, token1);
        pool = address(new vPair{salt: _salt}());

        delete parameters;
    }
}
