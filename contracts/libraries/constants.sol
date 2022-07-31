pragma solidity ^0.8.0;

library Constants {
    uint24 internal constant BASE_FACTOR = 10**3;
    uint24 internal constant MINIMUM_LIQUIDITY = BASE_FACTOR;
    uint24 internal constant RESERVE_RATIO_FACTOR = BASE_FACTOR;
    uint24 internal constant PRICE_FEE_FACTOR = BASE_FACTOR;
    uint256 internal constant RESERVE_RATIO_WHOLE =
        RESERVE_RATIO_FACTOR * 100 * 1e18;
}
