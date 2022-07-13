pragma solidity =0.8.1;
import "../types.sol";
import "../libraries/vSwapMath.sol";
import "../interfaces/IvPair.sol";
import "../interfaces/IvRouterVirtualPools.sol";

abstract contract vRouterVirtualPools is IvRouterVirtualPools {
    function getVirtualAmountIn(
        address jkPair,
        address ikPair,
        uint256 amountOut
    ) external view override returns (uint256 amountIn) {
        VirtualPoolModel memory vPool = this.getVirtualPool(jkPair, ikPair);

        return
            vSwapMath.getAmountIn(
                amountOut,
                vPool.reserve0,
                vPool.reserve1,
                IvPair(jkPair).vFee()
            );
    }

    function getVirtualPool(address jkPair, address ikPair)
        external
        view
        override
        returns (VirtualPoolModel memory vPool)
    {
        (address ik0, address ik1) = IvPair(ikPair).getTokens();

        (address jk0, address jk1) = IvPair(jkPair).getTokens();

        VirtualPoolTokens memory vPoolTokens = vSwapMath.findCommonToken(
            ik0,
            ik1,
            jk0,
            jk1
        );

        require(vPoolTokens.ik1 == vPoolTokens.jk1, "IOP");

        (uint256 ikReserve0, uint256 ikReserve1) = IvPair(ikPair).getReserves();
        (uint256 jkReserve0, uint256 jkReserve1) = IvPair(jkPair).getReserves();

        vPool = vSwapMath.calculateVPool(
            vPoolTokens.ik0 == ik0 ? ikReserve0 : ikReserve1,
            vPoolTokens.ik0 == ik0 ? ikReserve1 : ikReserve0,
            vPoolTokens.jk0 == jk0 ? jkReserve0 : jkReserve1,
            vPoolTokens.jk0 == jk0 ? jkReserve1 : jkReserve0
        );

        vPool.token0 = vPoolTokens.ik0;
        vPool.token1 = vPoolTokens.jk0;
        vPool.commonToken = vPoolTokens.ik1;
    }

    function getVirtualAmountOut(
        address jkPair,
        address ikPair,
        uint256 amountIn
    ) external view override returns (uint256 amountOut) {
        VirtualPoolModel memory vPool = this.getVirtualPool(jkPair, ikPair);

        return
            vSwapMath.getAmountOut(
                amountIn,
                vPool.reserve0,
                vPool.reserve1,
                996
            );
    }
}
