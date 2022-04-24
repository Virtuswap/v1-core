// SPDX-License-Identifier: MIT
pragma solidity >=0.4.22 <0.9.0;

import "./Types256.sol";
import "./ERC20/IERC20.sol";
import "./ERC20/ERC20.sol";
import "./libraries/vSwapMath.sol";
import "./interfaces/IvPair.sol";
import "./interfaces/IvPairFactory.sol";

contract vPool {
    address owner;
    address _factory;

    uint256 constant EPSILON = 1 wei;

    modifier onlyOwner() {
        require(msg.sender == owner);
        _;
    }

    constructor(address factory) {
        owner = msg.sender;
        _factory = factory;
    }

    function calculateVirtualPool(address[] memory ks, address[] memory js)
        public
        view
        returns (VirtualPool memory vPool)
    {
        vPool.fee = 0.003 ether;

        for (uint256 i = 0; i < ks.length; i++) {
            uint256 belowReserveIK = IvPair(ks[i]).getBelowReserve();
            uint256 belowReserveJK = IvPair(js[i]).getBelowReserve();

            uint256 ikPairTokenABalance = IERC20(IvPair(ks[i]).token0())
                .balanceOf(ks[i]);

            uint256 ikPairTokenBBalance = IERC20(IvPair(ks[i]).token1())
                .balanceOf(ks[i]);

            uint256 jkPairTokenABalance = IERC20(IvPair(js[i]).token0())
                .balanceOf(js[i]);

            uint256 jkPairTokenBBalance = IERC20(IvPair(js[i]).token1())
                .balanceOf(js[i]);


            //  V(i,j,i)=V(i,j,i)+ind_below_reserve_threshold(i,k)*R(i,k,i)*min(R(i,k,k),R(j,k,k))/max(R(i,k,k),epsilon);
            vPool.tokenABalance =
                vPool.tokenABalance +
                (belowReserveIK *
                    ikPairTokenABalance *
                    Math.min(ikPairTokenBBalance, jkPairTokenBBalance)) /
                Math.max(ikPairTokenBBalance, EPSILON);

            //  V(i,j,j)=V(i,j,j)+ind_below_reserve_threshold(i,k)*R(j,k,j)*min(R(i,k,k),R(j,k,k))/max(R(j,k,k),epsilon);
            vPool.tokenBBalance =
                vPool.tokenBBalance +
                (belowReserveJK *
                    jkPairTokenABalance *
                    Math.min(ikPairTokenBBalance, jkPairTokenBBalance)) /
                Math.max(jkPairTokenBBalance, EPSILON);
        }

        return vPool;
    }

    // function calculateTotalPool(uint256[] memory ks, uint256[] memory js)
    //     public
    //     view
    //     returns (VirtualPool memory)
    // {
    //     VirtualPool memory vPool = _calculateVirtualPool(ks, js);
    //     VirtualPool memory tPool = vPoolCalculations.getTotalPool(vPool);

    //     return tPool;
    // }

    // function quote(
    //     uint256[] memory ks,
    //     uint256[] memory js,
    //     int256 amount
    // ) public view returns (int256) {
    //     VirtualPool memory tPool = getTotalPool(ks, js);
    //     return vSwapMath.quote(rPools, tPool, amount);
    // }

    // function swap(
    //     uint256[] memory ks,
    //     uint256[] memory js,
    //     int256 amount
    // ) public {
    //     VirtualPool memory tPool = getTotalPool(ks, js);

    //     require(
    //         IERC20(tPool.tokenA).transferFrom(
    //             msg.sender,
    //             address(this),
    //             uint256(amount)
    //         ),
    //         "Failed to transfer token A to contract"
    //     );

    //     int256 outBalance = vPoolCalculations.quote(rPools, tPool, amount);

    //     VirtualPool[] memory lagR = new VirtualPool[](rPools.length);

    //     // %save current values

    //     //lag_T(buy_currency,sell_currency,buy_currency)=T(buy_currency,sell_currency,buy_currency);
    //     int256 lagTTokenABalance = tPool.tokenABalance;

    //     //lag_T(buy_currency,sell_currency,sell_currency)=T(buy_currency,sell_currency,sell_currency);
    //     int256 lagTTokenBBalance = tPool.tokenBBalance;

    //     //%substract amount and add fees to amount_in
    //     //T(buy_currency,sell_currency,buy_currency)=lag_T(buy_currency,sell_currency,buy_currency)-Buy*(1-fee_T(buy_currency,sell_currency)); ****
    //     tPool.tokenABalance =
    //         lagTTokenABalance -
    //         (amount - ((tPool.fee * amount) / 1 ether));

    //     // T(buy_currency,sell_currency,sell_currency)=lag_T(buy_currency,sell_currency,buy_currency)*lag_T(buy_currency,sell_currency,sell_currency)/(lag_T(buy_currency,sell_currency,buy_currency)-Buy); // %calculate amount_out
    //     tPool.tokenBBalance = tPool.tokenBBalance =
    //         (lagTTokenABalance * lagTTokenBBalance) /
    //         (lagTTokenABalance - amount);

    //     // for k=1:number_currencies
    //     for (uint256 i = 0; i < ks.length; i++) {
    //         //lag_R(buy_currency,k,buy_currency)=R(buy_currency,k,buy_currency);
    //         lagR[ks[i]].tokenABalance = rPools[ks[i]].tokenABalance;

    //         //lag_R(buy_currency,k,sell_currency)=R(buy_currency,k,sell_currency);
    //         lagR[ks[i]].tokenBBalance = rPools[ks[i]].tokenBBalance;
    //     }

    //     // %take buy_currency proportional from real and virtual pool
    //     /*  R(buy_currency,sell_currency,buy_currency)=
    //                    lag_R(buy_currency,sell_currency,buy_currency) *
    //                    T(buy_currency,sell_currency,buy_currency)/
    //                    lag_T(buy_currency,sell_currency,buy_currency); */

    //     //lag_R(buy_currency,k,buy_currency)=R(buy_currency,k,buy_currency);
    //     lagR[tPool.rPoolIndex].tokenABalance = rPools[tPool.rPoolIndex]
    //         .tokenABalance;

    //     //lag_R(buy_currency,k,sell_currency)=R(buy_currency,k,sell_currency);
    //     lagR[tPool.rPoolIndex].tokenBBalance = rPools[tPool.rPoolIndex]
    //         .tokenBBalance;

    //     // %take sell_currency proportional from real and virtual pool

    //     if (tPool.rPoolIndex > 0) {
    //         /* R(buy_currency,sell_currency,sell_currency)=
    //         lag_R(buy_currency,sell_currency,sell_currency)*
    //         T(buy_currency,sell_currency,sell_currency)/
    //         lag_T(buy_currency,sell_currency,sell_currency);*/
    //         rPools[tPool.rPoolIndex].tokenABalance =
    //             (lagR[tPool.rPoolIndex].tokenABalance * tPool.tokenABalance) /
    //             lagTTokenABalance;

    //         rPools[tPool.rPoolIndex].tokenBBalance =
    //             (lagR[tPool.rPoolIndex].tokenBBalance * tPool.tokenBBalance) /
    //             lagTTokenBBalance;

    //         // %fill reverse
    //         // R(sell_currency,buy_currency,buy_currency)=R(buy_currency,sell_currency,buy_currency);
    //         rPools[rPools[tPool.rPoolIndex].reversePoolIndex]
    //             .tokenBBalance = rPools[tPool.rPoolIndex].tokenABalance;

    //         // R(sell_currency,buy_currency,sell_currency)=R(buy_currency,sell_currency,sell_currency);
    //         rPools[rPools[tPool.rPoolIndex].reversePoolIndex]
    //             .tokenABalance = rPools[tPool.rPoolIndex].tokenBBalance;
    //     }

    //     //% Updating of non-native pools that contribute to BC virtual pool;
    //     for (uint256 i = 0; i < ks.length; i++) {
    //         //sum lagR tokenA balance

    //         /*R(buy_currency,k,buy_currency)=
    //             //R(buy_currency,k,buy_currency)+
    //             ((T(buy_currency,sell_currency,buy_currency)-lag_T(buy_currency,sell_currency,buy_currency))-
    //             (R(buy_currency,sell_currency,buy_currency)-lag_R(buy_currency,sell_currency,buy_currency)))*
    //             lag_R(buy_currency,k,buy_currency)/
    //             (sum(lag_R(buy_currency,1:number_currencies,buy_currency))
    //             -lag_R(buy_currency,sell_currency,buy_currency));

    // */
    //         rPools[ks[i]].tokenABalance =
    //             rPools[ks[i]].tokenABalance +
    //             (((tPool.tokenABalance - lagTTokenABalance) -
    //                 (rPools[tPool.rPoolIndex].tokenABalance -
    //                     lagR[tPool.rPoolIndex].tokenABalance)) *
    //                 lagR[ks[i]].tokenABalance) /
    //             (vPoolCalculations.sumVirtualPoolsArray(lagR) -
    //                 lagR[tPool.rPoolIndex].tokenABalance);

    //         //fill reverse pool
    //         //R(k,buy_currency,buy_currency)=R(buy_currency,k,buy_currency);
    //         rPools[rPools[ks[i]].reversePoolIndex].tokenBBalance = rPools[ks[i]]
    //             .tokenABalance;
    //     }

    //     for (uint256 i = 0; i < js.length; i++) {
    //         //sum lagR tokenA balance

    //         /*R(buy_currency,k,buy_currency)=
    //             //R(buy_currency,k,buy_currency)+
    //             ((T(buy_currency,sell_currency,buy_currency)-lag_T(buy_currency,sell_currency,buy_currency))-
    //             (R(buy_currency,sell_currency,buy_currency)-lag_R(buy_currency,sell_currency,buy_currency)))*
    //             lag_R(buy_currency,k,buy_currency)/
    //             (sum(lag_R(buy_currency,1:number_currencies,buy_currency))
    //             -lag_R(buy_currency,sell_currency,buy_currency));

    // */
    //         rPools[js[i]].tokenABalance =
    //             rPools[js[i]].tokenABalance +
    //             (((tPool.tokenABalance - lagTTokenABalance) -
    //                 (rPools[tPool.rPoolIndex].tokenABalance -
    //                     lagR[tPool.rPoolIndex].tokenABalance)) *
    //                 lagR[js[i]].tokenABalance) /
    //             (vPoolCalculations.sumVirtualPoolsArray(lagR) -
    //                 lagR[tPool.rPoolIndex].tokenABalance);

    //         //fill reverse pool
    //         //R(k,buy_currency,buy_currency)=R(buy_currency,k,buy_currency);
    //         rPools[rPools[js[i]].reversePoolIndex].tokenBBalance = rPools[js[i]]
    //             .tokenABalance;
    //     }

    //     // % Updating reserves of real pools and all the subsequent calculations;
    //     // i=buy_currency;
    //     // for k=1:number_currencies
    //     //     if (k~=buy_currency & k~=sell_currency)
    //     //         R(buy_currency,k,sell_currency)=R(buy_currency,k,sell_currency)+((T(buy_currency,sell_currency,sell_currency)-lag_T(buy_currency,sell_currency,sell_currency))-(R(buy_currency,sell_currency,sell_currency)-lag_R(buy_currency,sell_currency,sell_currency)))*lag_R(buy_currency,k,buy_currency)/(sum(lag_R(buy_currency,1:number_currencies,buy_currency))-lag_R(buy_currency,sell_currency,buy_currency));
    //     //         R(k,buy_currency,sell_currency)=R(buy_currency,k,sell_currency);
    //     //     end;
    //     // end;
    //     int256 reserveBalanceTokenB = 0;

    //     for (uint256 i = 0; i < ks.length; i++) {
    //         //sum lagR tokenA balance

    //         /*R(buy_currency,k,sell_currency)=
    //             R(buy_currency,k,sell_currency)+
    //             ((T(buy_currency,sell_currency,sell_currency)-lag_T(buy_currency,sell_currency,sell_currency))-
    //             (R(buy_currency,sell_currency,sell_currency)-lag_R(buy_currency,sell_currency,sell_currency)))*
    //             lag_R(buy_currency,k,buy_currency)/(sum(lag_R(buy_currency,1:number_currencies,buy_currency))-
    //             lag_R(buy_currency,sell_currency,buy_currency));*/

    //         // rPools[ks[i]].reserveBalance[rPools[ks[i]].tokenB] =
    //         //     rPools[ks[i]].reserveBalance[rPools[ks[i]].tokenB] +
    //         //     (((tPool.tokenBBalance - lagTTokenBBalance) -
    //         //         (rPools[tPool.rPoolIndex].tokenBBalance -
    //         //             lagR[tPool.rPoolIndex].tokenBBalance)) *
    //         //         lagR[ks[i]].tokenABalance) /
    //         //     (vPoolCalculations.sumVirtualPoolsArray(lagR) -
    //         //         lagR[tPool.rPoolIndex].tokenABalance);

    //         reserveBalanceTokenB =
    //             reserveBalanceTokenB +
    //             (((tPool.tokenBBalance - lagTTokenBBalance) -
    //                 (rPools[tPool.rPoolIndex].tokenBBalance -
    //                     lagR[tPool.rPoolIndex].tokenBBalance)) *
    //                 lagR[ks[i]].tokenABalance) /
    //             (vPoolCalculations.sumVirtualPoolsArray(lagR) -
    //                 lagR[tPool.rPoolIndex].tokenABalance);
    //     }

    //     reserveManager.updateReserveBalance(
    //         tPool.rPoolIndex,
    //         rPools[ks[0]].tokenB,
    //         reserveBalanceTokenB
    //     );

    //     reserveManager.updateReserveBalance(
    //         rPools[tPool.rPoolIndex].reversePoolIndex,
    //         rPools[ks[0]].tokenB,
    //         reserveBalanceTokenB
    //     );

    //     //fill reverse pool
    //     // rPools[rPools[ks[i]].reversePoolIndex].reserveBalance[
    //     //     rPools[ks[i]].tokenB
    //     // ] = rPools[ks[i]].reserveBalance[rPools[ks[i]].tokenB];

    //     // emit ADebug("2 msg.sender", msg.sender);
    //     // emit ADebug("2 address(this)", address(this));
    //     // emit UDebug("2 amount", uint256(outBalance));

    //     require(
    //         IERC20(tPool.tokenB).transfer(msg.sender, uint256(outBalance)),
    //         "Failed to transfer out amount to user"
    //     );

    //     //calculate below threshold for rPool
    // }

    function changeFactory(address factory) public onlyOwner {
        _factory = factory;
    }
}
