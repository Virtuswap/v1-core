import { ethers } from "hardhat";
const abi = ethers.utils.defaultAbiCoder;
import { time } from "@nomicfoundation/hardhat-network-helpers";

export default {
  fromWeiToNumber: function (number: any) {
    return parseFloat(
      parseFloat(ethers.utils.formatEther(number.toString())).toFixed(6)
    );
  },
  getFutureBlockTimestamp: async function () {
    return (await time.latest()) + 1000000;
  },
  getEncodedSwapData: function (
    payer: any,
    tokenIn: any,
    token0: any,
    token1: any,
    tokenInMax: any
  ) {
    return abi.encode(
      ["address", "address", "address", "address", "uint256"],
      [payer, tokenIn, token0, token1, tokenInMax]
    );
  },

  getEncodedExchangeReserveCallbackParams: function (
    jkPair1: any,
    jkPair2: any,
    ikPair2: any
  ) {
    return abi.encode(
      ["address", "address", "address"],
      [jkPair1, jkPair2, ikPair2]
    );
  },
};
