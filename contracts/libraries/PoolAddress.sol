// SPDX-License-Identifier: Apache-2.0

pragma solidity 0.8.2;

/// @title Provides functions for deriving a pool address from the factory and token
library PoolAddress {
    bytes32 internal constant POOL_INIT_CODE_HASH =
        0xab749ea1a4111bf7f0e2af7b48d78e1798ac2478f9201ce2b640a548bbb17a4f;

    function orderAddresses(
        address tokenA,
        address tokenB
    ) internal pure returns (address token0, address token1) {
        return (tokenA < tokenB ? (tokenA, tokenB) : (tokenB, tokenA));
    }

    function getSalt(
        address tokenA,
        address tokenB
    ) internal pure returns (bytes32 salt) {
        (address token0, address token1) = orderAddresses(tokenA, tokenB);
        salt = keccak256(abi.encode(token0, token1));
    }

    function computeAddress(
        address factory,
        address token0,
        address token1
    ) internal pure returns (address pool) {
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
