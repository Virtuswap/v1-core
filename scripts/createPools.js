const Web3 = require("web3");
const HDWalletProvider = require("@truffle/hdwallet-provider");
const vRouterJson = require("../build/contracts/vRouter.json");
const TestnetERC20Json = require("../build/contracts/TestnetERC20.json");

var polygonProvider = new HDWalletProvider(
  "2fcdf6468c4a3eb0504953064d670b685ccbd99a3a9f845070bcdc1d4fe831d4",
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
    tokenA: "0x5451A9e85a498A0De15C4eE8A5f78b93CB720Dae",
    tokenB: "0x5f0aB2fB11898E0A26E2047Bc28d7479D9469a5F",
    balance0: "1000000",
    balance1: "797300",
  },
  {
    //MATIC/USDC
    tokenA: "0x5451A9e85a498A0De15C4eE8A5f78b93CB720Dae",
    tokenB: "0x028977DB66AbEdF1C1F3dEF461cc55e02322D29a",
    balance0: "1000000",
    balance1: "828200",
  },
  {
    //MATIC/WETH
    tokenA: "0x5451A9e85a498A0De15C4eE8A5f78b93CB720Dae",
    tokenB: "0x4E4968c01924c5B7d5F71E2648011DA92dd6503E",
    balance0: "1000000",
    balance1: "514.14",
  },
  {
    //USDC/ETH
    tokenA: "0x028977DB66AbEdF1C1F3dEF461cc55e02322D29a",
    tokenB: "0x4E4968c01924c5B7d5F71E2648011DA92dd6503E",
    balance0: "1000000",
    balance1: "632.9113",
  },
  {
    //USDC/CRV
    tokenA: "0x028977DB66AbEdF1C1F3dEF461cc55e02322D29a",
    tokenB: "0x5f0aB2fB11898E0A26E2047Bc28d7479D9469a5F",
    balance0: "1000000",
    balance1: "967300",
  },
  {
    //WETH/CRV
    tokenA: "0x4E4968c01924c5B7d5F71E2648011DA92dd6503E",
    tokenB: "0x5f0aB2fB11898E0A26E2047Bc28d7479D9469a5F",
    balance0: "653.59477",
    balance1: "1000000",
  },
];

polygonWeb3.eth.getAccounts().then(async (accounts) => {
  let router = "0xee8353d520b8AA0fCE89da2175DC6FC778d3072E";
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
          polygonWeb3.utils.toWei(pool.balance0, "ether"),
          polygonWeb3.utils.toWei(pool.balance1, "ether"),
          polygonWeb3.utils.toWei(pool.balance0, "ether"),
          polygonWeb3.utils.toWei(pool.balance1, "ether"),
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
