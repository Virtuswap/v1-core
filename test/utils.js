const utils = {
  getEncodedSwapData: function (payer, tokenIn, token0, token1, tokenInMax) {
    return web3.eth.abi.encodeParameter(
      {
        SwapCallbackData: {
          payer: "address",
          tokenIn: "address",
          token0: "address",
          token1: "address",
          tokenInMax: "uint256",
        },
      },
      {
        payer,
        tokenIn,
        token0,
        token1,
        tokenInMax,
      }
    );
  },
};

module.exports = utils;
