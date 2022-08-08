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

  getEncodedExchangeReserveCallbackParams: function (
    jkPair1,
    jkPair2,
    ikPair2
  ) {
    return web3.eth.abi.encodeParameter(
      {
        SwapCallbackData: {
          jkPair1: "address",
          jkPair2: "address",
          ikPair2: "address",
        },
      },
      {
        jkPair1,
        jkPair2,
        ikPair2,
      }
    );
  },
};

module.exports = utils;
