const Web3 = require("web3");
const HDWalletProvider = require("@truffle/hdwallet-provider");
const vRouterJson = require("../build/contracts/vRouter.json");
const TestnetERC20Json = require("../build/contracts/TestnetERC20.json");

var polygonProvider = new HDWalletProvider(
  "4cd4d069ecb10b4a5ff6e194976b6cdbd04e307d670e6bf4f455556497b4a63b",
  `https://morning-twilight-cherry.matic-testnet.quiknode.pro/6ba9d2c5b8a046814b28f974c3643c679914f7ff/`
);

const polygonWeb3 = new Web3(polygonProvider);

async function getFutureBlockTimestamp() {
  const blockNumber = await polygonWeb3.eth.getBlockNumber();
  const block = await polygonWeb3.eth.getBlock(blockNumber);
  return block.timestamp + 1000000;
}

let pools = [
  {
    //MATIC/CRV
    tokenA: "0xe565073F251f536a55d6f95Bcb9e1456168dFB24",
    tokenB: "0x52d75181c30B63Ca04A8615BD00Bb7F7b89802E9",
    balance0: "1000000000000000000000000",
    balance1: "797300000000000000000000",
  },
  {
    //MATIC/USDC
    tokenA: "0xe565073F251f536a55d6f95Bcb9e1456168dFB24",
    tokenB: "0x3C85C4546991cb520C7E024b69A0a428F0293c3E",
    balance0: "1000000000000000000000000",
    balance1: "828200000000000000000000",
  },
  {
    //MATIC/WETH
    tokenA: "0xe565073F251f536a55d6f95Bcb9e1456168dFB24",
    tokenB: "0xEc7aF77e0b3D37688Db0f75ee72BCbFbcC5B5B8E",
    balance0: "1000000000000000000000000",
    balance1: "514140000000000000000",
  },
  {
    //MATIC/LINK
    tokenA: "0xe565073F251f536a55d6f95Bcb9e1456168dFB24",
    tokenB: "0xAC3A40ea0c693419d5a105FbF930320761A71303",
    balance0: "1000000000000000000000000",
    balance1: "123800000000000000000000",
  },
  {
    //MATIC/USDT
    tokenA: "0xe565073F251f536a55d6f95Bcb9e1456168dFB24",
    tokenB: "0x870C00B3f20E7529EC6aaD77F7bfB62ed6FcC0fd",
    balance0: "1000000000000000000000000",
    balance1: "828200000000000000000000",
  },
  {
    //USDC/ETH
    tokenA: "0x3C85C4546991cb520C7E024b69A0a428F0293c3E",
    tokenB: "0xEc7aF77e0b3D37688Db0f75ee72BCbFbcC5B5B8E",
    balance0: "1000000000000000000000000",
    balance1: "632911300000000000000",
  },
  {
    //USDC/WBTC
    tokenA: "0x3C85C4546991cb520C7E024b69A0a428F0293c3E",
    tokenB: "0xFd2D968FD97Ee7557C9D9073C0226997ecdEdA59",
    balance0: "1000000000000000000000000",
    balance1: "52820000000000000000",
  },
  {
    //USDC/CRV
    tokenA: "0x3C85C4546991cb520C7E024b69A0a428F0293c3E",
    tokenB: "0x52d75181c30B63Ca04A8615BD00Bb7F7b89802E9",
    balance0: "1000000000000000000000000",
    balance1: "967300000000000000000000",
  },
  {
    //USDC/USDT
    tokenA: "0x3C85C4546991cb520C7E024b69A0a428F0293c3E",
    tokenB: "0x870C00B3f20E7529EC6aaD77F7bfB62ed6FcC0fd",
    balance0: "1000000000000000000000000",
    balance1: "1000000000000000000000000",
  },
  {
    //USDC/DAI
    tokenA: "0x3C85C4546991cb520C7E024b69A0a428F0293c3E",
    tokenB: "0x5bE6F0D141D226b3C21685be1a047f59CeE7e36C",
    balance0: "1000000000000000000000000",
    balance1: "1000000000000000000000000",
  },
  {
    //WETH/DAI
    tokenA: "0xEc7aF77e0b3D37688Db0f75ee72BCbFbcC5B5B8E",
    tokenB: "0x5bE6F0D141D226b3C21685be1a047f59CeE7e36C",
    balance0: "632911300000000000000",
    balance1: "1000000000000000000000000",
  },
  {
    //WETH/CRV
    tokenA: "0xEc7aF77e0b3D37688Db0f75ee72BCbFbcC5B5B8E",
    tokenB: "0x52d75181c30B63Ca04A8615BD00Bb7F7b89802E9",
    balance0: "653594770000000000000",
    balance1: "1000000000000000000000000",
  },
  {
    //WETH/USDT
    tokenA: "0xEc7aF77e0b3D37688Db0f75ee72BCbFbcC5B5B8E",
    tokenB: "0x870C00B3f20E7529EC6aaD77F7bfB62ed6FcC0fd",
    balance0: "632911300000000000000",
    balance1: "1000000000000000000000000",
  },
  {
    //WETH/WBTC
    tokenA: "0xEc7aF77e0b3D37688Db0f75ee72BCbFbcC5B5B8E",
    tokenB: "0xFd2D968FD97Ee7557C9D9073C0226997ecdEdA59",
    balance0: "1000000000000000000000000",
    balance1: "83367",
  },
  {
    //DAI/USDT
    tokenA: "0x5bE6F0D141D226b3C21685be1a047f59CeE7e36C",
    tokenB: "0x870C00B3f20E7529EC6aaD77F7bfB62ed6FcC0fd",
    balance0: "1000000000000000000000000",
    balance1: "1000000000000000000000000",
  },
  {
    //LINK/WETH
    tokenA: "0xAC3A40ea0c693419d5a105FbF930320761A71303",
    tokenB: "0xEc7aF77e0b3D37688Db0f75ee72BCbFbcC5B5B8E",
    balance0: "1000000000000000000000000",
    balance1: "4239000000000000000000",
  },
  {
    //LINK/USDC
    tokenA: "0xAC3A40ea0c693419d5a105FbF930320761A71303",
    tokenB: "0x3C85C4546991cb520C7E024b69A0a428F0293c3E",
    balance0: "149191",
    balance1: "1000000000000000000000000",
  },
];

polygonWeb3.eth.getAccounts().then(async (accounts) => {
  let router = "0x67Cb6cE3fEa915ad3Bda6926A311df1F62e0aD8e";
  let sendArgs = { from: accounts[0], gasPrice: 35000000000 };

  const vRouterInstance = new polygonWeb3.eth.Contract(vRouterJson.abi, router);
  let adminAddress = "0x5eA409399e47F0Df9FAC47488A4010bfD04718a4";
  let futureTs = await getFutureBlockTimestamp();
  for (let i = 0; i < pools.length; i++) {
    let pool = pools[i];

    const tokenAInstance = new polygonWeb3.eth.Contract(
      TestnetERC20Json.abi,
      pool.tokenA
    );

    const tokenBInstance = new polygonWeb3.eth.Contract(
      TestnetERC20Json.abi,
      pool.tokenB
    );

    await tokenAInstance.methods
      .approve(
        router,
        polygonWeb3.utils.toWei("999999999999999999999999999999", "ether")
      )
      .send(sendArgs);

    await tokenBInstance.methods
      .approve(
        router,
        polygonWeb3.utils.toWei("999999999999999999999999999999", "ether")
      )
      .send(sendArgs);
    try {
      let tx = await vRouterInstance.methods
        .addLiquidity(
          pool.tokenA,
          pool.tokenB,
          pool.balance0,
          pool.balance1,
          pool.balance0,
          pool.balance1,
          adminAddress,
          futureTs
        )
        .send(sendArgs);
    } catch (ex) {
      console.log(ex);
    }

    console.log("created pool: " + i + " out of " + pools.length);
  }
});
