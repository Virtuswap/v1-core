// SPDX-License-Identifier: Apache-2.0

pragma solidity 0.8.2;

interface IvPairFactory {
    event PairCreated(
        address poolAddress,
        address factory,
        address token0,
        address token1
    );

    event ExchangeReserveAddressChanged(address newExchangeReserve);

    function createPair(address tokenA, address tokenB)
        external
        returns (address);

    function admin() external view returns (address);

    function exchangeReserves() external view returns (address);

    function getPair(address tokenA, address tokenB)
        external
        view
        returns (address);

    function setExchangeReservesAddress(address _exchangeReserves) external;
}
