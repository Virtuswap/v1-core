import "../Types256.sol";
import "../ERC20/IERC20.sol";
import "../ERC20/ERC20.sol";
import "../vPair.sol";

library vSwapMath {
    uint256 constant EPSILON = 1 wei;

    function _calculateVirtualPool(address[] memory ks, address[] memory js)
        public
        view
        returns (VirtualPool memory)
    {
        VirtualPool memory vPool;
        vPool.fee = 0.003 ether;

        vPool.tokenA = vPair(ks[0]).tokenA();
        vPool.tokenB = vPair(js[0]).tokenB();

        for (uint256 i = 0; i < ks.length; i++) {
            address ikIndex = ks[i];
            address jkIndex = js[i];

            uint256 belowReserveIK = vPair(ikIndex).getBelowReserve();
            uint256 belowReserveJK = vPair(jkIndex).getBelowReserve();

            uint256 ikIndexTokenABalance = IERC20(vPair(ikIndex).tokenA())
                .balanceOf(ikIndex);

            uint256 ikIndexTokenBBalance = IERC20(vPair(ikIndex).tokenB())
                .balanceOf(ikIndex);

            uint256 jkIndexTokenABalance = IERC20(vPair(jkIndex).tokenA())
                .balanceOf(ikIndex);

            uint256 jkIndexTokenBBalance = IERC20(vPair(jkIndex).tokenB())
                .balanceOf(ikIndex);

            //  V(i,j,i)=V(i,j,i)+ind_below_reserve_threshold(i,k)*R(i,k,i)*min(R(i,k,k),R(j,k,k))/max(R(i,k,k),epsilon);
            vPool.tokenABalance =
                vPool.tokenABalance +
                (belowReserveIK *
                    ikIndexTokenABalance *
                    Math.min(ikIndexTokenBBalance, jkIndexTokenBBalance)) /
                Math.min(ikIndexTokenBBalance, EPSILON);

            //  V(i,j,j)=V(i,j,j)+ind_below_reserve_threshold(i,k)*R(j,k,j)*min(R(i,k,k),R(j,k,k))/max(R(j,k,k),epsilon);
            vPool.tokenBBalance =
                vPool.tokenBBalance +
                (belowReserveJK *
                    jkIndexTokenABalance *
                    Math.min(ikIndexTokenBBalance, jkIndexTokenBBalance)) /
                Math.min(jkIndexTokenBBalance, EPSILON);
        }

        return vPool;
    }

    function calculateReserveRatio(
        uint256 reserveBalance,
        uint256 ikTokenABalance,
        uint256 ikTokenBBalance,
        uint256 jkTokenABalance,
        uint256 jkTokenBBalance,
        uint256 ijtokenABalance,
        uint256 ijtokenBBalance
    ) public pure returns (uint256) {
        return
            (reserveBalance *
                Math.max(
                    ikTokenABalance / Math.max(ikTokenBBalance, EPSILON),
                    ((jkTokenABalance / Math.max(jkTokenBBalance, EPSILON)) *
                        ijtokenABalance) / Math.max(ijtokenBBalance, EPSILON)
                )) / (2 * Math.max(ijtokenABalance, EPSILON));
    }

    function getTotalPool(Pool[] storage rPools, VirtualPool memory vPool)
        public
        view
        returns (VirtualPool memory)
    {
        VirtualPool memory tPool = vPool;

        uint256 rPoolTokenABalance = 0;
        uint256 rPoolTokenBBalance = 0;
        uint256 rPoolFee = 0;

        if (vPool.rPoolIndex > 0) {
            rPoolTokenABalance = rPools[vPool.rPoolIndex].tokenABalance;
            rPoolTokenBBalance = rPools[vPool.rPoolIndex].tokenBBalance;
            rPoolFee = rPools[vPool.rPoolIndex].fee;
        }

        tPool.tokenABalance = rPoolTokenABalance + vPool.tokenABalance;

        tPool.tokenBBalance = rPoolTokenBBalance + vPool.tokenBBalance;

        if (vPool.tokenABalance > 0) {
            tPool.fee =
                (rPoolFee *
                    rPoolTokenABalance +
                    vPool.fee *
                    vPool.tokenABalance) /
                vPool.tokenABalance;
        }

        return tPool;
    }

    // function _calculateBelowThreshold(
    //     Pool[] storage rPools,
    //     address[] memory tokens
    // ) internal view returns (int256[] memory) {
    //     int256[] memory reserveRatio = _calculateReserveRatio(rPools, tokens);

    //     int256[] memory belowThreshold = new int256[](rPools.length);

    //     for (uint256 i = 0; i < rPools.length; i++) {
    //         if (
    //             reserveRatio[i] >= rPools[i].maxReserveRatio &&
    //             belowThreshold[i] == 1
    //         ) {
    //             belowThreshold[i] = 0;
    //         } else if (reserveRatio[i] == 0) {
    //             belowThreshold[i] = 1;
    //         }
    //     }

    //     return belowThreshold;
    // }
}
