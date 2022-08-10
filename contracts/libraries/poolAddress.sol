// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.0;

import "../interfaces/IvPairFactory.sol";

/// @title Provides functions for deriving a pool address from the factory and token
library PoolAddress {
    //use in PROD
    bytes32 public constant POOL_INIT_CODE_HASH =
        0x274415a0a543b74138c7613ae562922b86e830ed6f5b8a9f0f674d09b80af7c1;

    function orderAddresses(address tokenA, address tokenB)
        internal
        pure
        returns (address token0, address token1)
    {
        return (tokenA < tokenB ? (tokenA, tokenB) : (tokenB, tokenA));
    }

    function getSalt(address tokenA, address tokenB)
        internal
        pure
        returns (bytes32 salt)
    {
        (address token0, address token1) = orderAddresses(tokenA, tokenB);
        salt = keccak256(abi.encode(token0, token1));
    }

    function computeAddress(
        address factory,
        address token0,
        address token1
    ) public pure returns (address pool) {
        bytes32 _salt = getSalt(token0, token1);

        pool = address(
            uint160(
                uint256(
                    keccak256(
                        abi.encodePacked(
                            bytes1(0xff),
                            factory,
                            _salt,
                            POOL_INIT_CODE_HASH
                        )
                    )
                )
            )
        );
    }
}
