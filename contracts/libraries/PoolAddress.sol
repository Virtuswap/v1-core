// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.0;

/// @title Provides functions for deriving a pool address from the factory and token
library PoolAddress {
    //PROD: change to internal TBD
    bytes32 public constant POOL_INIT_CODE_HASH =
        0x03712d1bb576d402da4439b91259edb99d87a3105c1784bff7ebf10ef9ea30e4;

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
