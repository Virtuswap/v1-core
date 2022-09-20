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
    tokenA: "0x55ACcc9147D6E57de6eaa214034B86843ea1461D",
    tokenB: "0x14b911FD053c8E9d5d222845Cd87A8ba54f0eF51",
    balance0: "1000000000000000000000000",
    balance1: "797300000000000000000000",
  },
  {
    //MATIC/USDC
    tokenA: "0x55ACcc9147D6E57de6eaa214034B86843ea1461D",
    tokenB: "0x6D36eeA552D73e5249B3Ee99DdC52379a14C62Ef",
    balance0: "1000000000000000000000000",
    balance1: "828200000000000000000000",
  },
  {
    //MATIC/WETH
    tokenA: "0x55ACcc9147D6E57de6eaa214034B86843ea1461D",
    tokenB: "0x112f88f4272DDd74946bF5ee046f1C8C3b5F15E7",
    balance0: "1000000000000000000000000",
    balance1: "514140000000000000000",
  },
  {
    //MATIC/LINK
    tokenA: "0x55ACcc9147D6E57de6eaa214034B86843ea1461D",
    tokenB: "0x85A6A6c87fe052AD57C634CaE89BfA29f4cfAC13",
    balance0: "1000000000000000000000000",
    balance1: "123800000000000000000000",
  },
  {
    //MATIC/USDT
    tokenA: "0x55ACcc9147D6E57de6eaa214034B86843ea1461D",
    tokenB: "0xCbaB50C22D08298c17235ECE60830A60AA63850A",
    balance0: "1000000000000000000000000",
    balance1: "828200000000000000000000",
  },
  {
    //USDC/ETH
    tokenA: "0x6D36eeA552D73e5249B3Ee99DdC52379a14C62Ef",
    tokenB: "0x112f88f4272DDd74946bF5ee046f1C8C3b5F15E7",
    balance0: "1000000000000000000000000",
    balance1: "632911300000000000000",
  },
  {
    //USDC/WBTC
    tokenA: "0x6D36eeA552D73e5249B3Ee99DdC52379a14C62Ef",
    tokenB: "0x51C6A9440d9DCcDc815bf2a307D416Efad16668b",
    balance0: "1000000000000000000000000",
    balance1: "52820000000000000000",
  },
  {
    //USDC/CRV
    tokenA: "0x6D36eeA552D73e5249B3Ee99DdC52379a14C62Ef",
    tokenB: "0x14b911FD053c8E9d5d222845Cd87A8ba54f0eF51",
    balance0: "1000000000000000000000000",
    balance1: "967300000000000000000000",
  },
  {
    //USDC/USDT
    tokenA: "0x6D36eeA552D73e5249B3Ee99DdC52379a14C62Ef",
    tokenB: "0xCbaB50C22D08298c17235ECE60830A60AA63850A",
    balance0: "1000000000000000000000000",
    balance1: "1000000000000000000000000",
  },
  {
    //USDC/DAI
    tokenA: "0x6D36eeA552D73e5249B3Ee99DdC52379a14C62Ef",
    tokenB: "0x72ddA542EDC69bA5996AB4710a86F6E6d5dd5417",
    balance0: "1000000000000000000000000",
    balance1: "1000000000000000000000000",
  },
  {
    //WETH/DAI
    tokenA: "0xEc7aF77e0b3D37688Db0f75ee72BCbFbcC5B5B8E",
    tokenB: "0x72ddA542EDC69bA5996AB4710a86F6E6d5dd5417",
    balance0: "632911300000000000000",
    balance1: "1000000000000000000000000",
  },
  {
    //WETH/CRV
    tokenA: "0x112f88f4272DDd74946bF5ee046f1C8C3b5F15E7",
    tokenB: "0x14b911FD053c8E9d5d222845Cd87A8ba54f0eF51",
    balance0: "653594770000000000000",
    balance1: "1000000000000000000000000",
  },
  {
    //WETH/USDT
    tokenA: "0x112f88f4272DDd74946bF5ee046f1C8C3b5F15E7",
    tokenB: "0xCbaB50C22D08298c17235ECE60830A60AA63850A",
    balance0: "632911300000000000000",
    balance1: "1000000000000000000000000",
  },
  {
    //WETH/WBTC
    tokenA: "0x112f88f4272DDd74946bF5ee046f1C8C3b5F15E7",
    tokenB: "0x51C6A9440d9DCcDc815bf2a307D416Efad16668b",
    balance0: "1000000000000000000000000",
    balance1: "83367",
  },
  {
    //DAI/USDT
    tokenA: "0x72ddA542EDC69bA5996AB4710a86F6E6d5dd5417",
    tokenB: "0xCbaB50C22D08298c17235ECE60830A60AA63850A",
    balance0: "1000000000000000000000000",
    balance1: "1000000000000000000000000",
  },
  {
    //LINK/WETH
    tokenA: "0x85A6A6c87fe052AD57C634CaE89BfA29f4cfAC13",
    tokenB: "0x112f88f4272DDd74946bF5ee046f1C8C3b5F15E7",
    balance0: "1000000000000000000000000",
    balance1: "4239000000000000000000",
  },
  {
    //LINK/USDC
    tokenA: "0x85A6A6c87fe052AD57C634CaE89BfA29f4cfAC13",
    tokenB: "0x6D36eeA552D73e5249B3Ee99DdC52379a14C62Ef",
    balance0: "149191",
    balance1: "1000000000000000000000000",
  },
];

polygonWeb3.eth.getAccounts().then(async (accounts) => {
  let router = "0x42F648c57C3afef57D094319fc1C5518fc89a46c";
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
