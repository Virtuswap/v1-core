// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.0;
import "../vPair.sol";

/// @title Provides functions for deriving a pool address from the factory and token
library PoolAddress {
    //PROD: change to internal TBD
    bytes32 public constant POOL_INIT_CODE_HASH =
        0xc18176db34939b37d4c2907e67433f5fcd650051ba203f7dc3fb39ccf338723d;

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

    function getInitCodeHash() public pure returns (bytes32) {
        return keccak256(abi.encode(type(vPair).creationCode));
    }

    function getBytecodeHash() public pure returns (bytes32 hash) {
        bytes memory bytecode = getBytecode();
        hash = keccak256(bytecode);
    }

    function _computeAddress(
        address factory,
        address token0,
        address token1
    ) public pure returns (bytes32 h) {
        bytes32 _salt = getSalt(token0, token1);
        bytes memory bytecode = getBytecode();

        h = keccak256(bytecode); //POOL_INIT_CODE_HASH
    }

    function computeAddress(
        address factory,
        address token0,
        address token1
    ) public pure returns (address pool) {
        bytes32 _salt = getSalt(token0, token1);
        bytes memory bytecode = getBytecode();

        pool = address(
            uint160(
                uint256(
                    keccak256(
                        abi.encodePacked(
                            bytes1(0xff),
                            factory,
                            _salt,
                            keccak256(bytecode) //POOL_INIT_CODE_HASH
                        )
                    )
                )
            )
        );
    }

    function computeAddress2(
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

    function computeAddress3(
        address factory,
        address tokenA,
        address tokenB
    ) public pure returns (address pool) {
        (address token0, address token1) = tokenA < tokenB
            ? (tokenA, tokenB)
            : (tokenB, tokenA);

        pool = address(
            uint160(
                uint256(
                    keccak256(
                        abi.encodePacked(
                            bytes1(0xff),
                            factory,
                            keccak256(abi.encode(token0, token1)),
                            POOL_INIT_CODE_HASH
                        )
                    )
                )
            )
        );
    }

    function computeAddress4(
        address factory,
        address tokenA,
        address tokenB
    ) public pure returns (address pool) {
        (address token0, address token1) = tokenA < tokenB
            ? (tokenA, tokenB)
            : (tokenB, tokenA);

        bytes memory bytecode = getBytecode();

        pool = address(
            uint160(
                uint256(
                    keccak256(
                        abi.encodePacked(
                            bytes1(0xff),
                            factory,
                            keccak256(abi.encode(token0, token1)),
                            keccak256(bytecode) //POOL_INIT_CODE_HASH
                        )
                    )
                )
            )
        );
    }

    // get the ByteCode of the contract
    function getBytecode() public pure returns (bytes memory) {
        bytes memory bytecode = type(vPair).creationCode;
        return abi.encode(bytecode);
    }
}
