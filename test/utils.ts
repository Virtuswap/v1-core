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
};
