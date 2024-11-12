import type { BigNumber } from 'ethers';
import { ethers } from 'hardhat';
const abi = ethers.utils.defaultAbiCoder;
import { time } from '@nomicfoundation/hardhat-network-helpers';

export default {
    fromWeiToNumber: function (number: any) {
        return parseFloat(
            parseFloat(ethers.utils.formatEther(number.toString())).toFixed(6)
        );
    },
    getFutureBlockTimestamp: async function () {
        return (await time.latest()) + 1000000;
    },
    getEncodedExchangeReserveCallbackParams: function (
        jkPair1: any,
        ikPair1: any,
        jkPair2: any,
        ikPair2: any,
        caller: any,
        flashAmountOut: any
    ) {
        return abi.encode(
            ['address', 'address', 'address', 'address', 'address', 'uint256'],
            [jkPair1, ikPair1, jkPair2, ikPair2, caller, flashAmountOut]
        );
    },
    getRealRouteData: function (
        transitStartIndex: number,
        transitLength: number,
        amount: BigNumber
    ) {
        return ethers.BigNumber.from(transitStartIndex)
            .shl(192)
            .or(ethers.BigNumber.from(transitLength).shl(128))
            .or(amount);
    },
    getVirtualRouteData: function (
        transitStartIndex: number,
        amount: BigNumber
    ) {
        return ethers.BigNumber.from(transitStartIndex)
            .shl(192)
            .or(ethers.BigNumber.from(1).shl(64).sub(1).shl(128))
            .or(amount);
    },
};
