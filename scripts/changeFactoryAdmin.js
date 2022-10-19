const Web3 = require("web3");
const HDWalletProvider = require("@truffle/hdwallet-provider");
const vPairFactoryJson = require("../build/contracts/vPairFactory.json");
const TestnetERC20Json = require("../build/contracts/TestnetERC20.json");

var polygonProvider = new HDWalletProvider(
  "2fcdf6468c4a3eb0504953064d670b685ccbd99a3a9f845070bcdc1d4fe831d4",
  `https://morning-twilight-cherry.matic-testnet.quiknode.pro/6ba9d2c5b8a046814b28f974c3643c679914f7ff/`
);

let tokens = [
  {
    name: "Wrapped Matic - VirtuSwap Test",
    sym: "WMATIC",
    address: "0xe565073F251f536a55d6f95Bcb9e1456168dFB24",
  },
  {
    name: "USD Coin - VirtuSwap Test",
    sym: "USDC",
    address: "0x3C85C4546991cb520C7E024b69A0a428F0293c3E",
  },
  {
    name: "Wrapped Ether - VirtuSwap Test",
    sym: "WETH",
    address: "0xEc7aF77e0b3D37688Db0f75ee72BCbFbcC5B5B8E",
  },
  {
    name: "Wrapped BTC - VirtuSwap Test",
    sym: "WBTC",
    address: "0xFd2D968FD97Ee7557C9D9073C0226997ecdEdA59",
  },
  {
    name: "Aavegotchi GHST - VirtuSwap Test",
    sym: "GHST",
    address: "0x64948F5eEE610056D29e6da5f7f17FA7A7EA459C",
  },
  {
    name: "Quickswap - VirtuSwap Test",
    sym: "QUICK",
    address: "0x5d1368Dda3AB7e991a562D65F7c650f3747b0F84",
  },
  {
    name: "USD Tether - VirtuSwap Test",
    sym: "USDT",
    address: "0x870C00B3f20E7529EC6aaD77F7bfB62ed6FcC0fd",
  },
  {
    name: "Dai Stablecoin - VirtuSwap Test",
    sym: "DAI",
    address: "0x5bE6F0D141D226b3C21685be1a047f59CeE7e36C",
  },
  {
    name: "SushiToken - VirtuSwap Test",
    sym: "SUSHI",
    address: "0x0111D757B20E4c527c0FD58Cc19D4FC117Debb49",
  },
  {
    name: "Chainlink Token - VirtuSwap Test",
    sym: "LINK",
    address: "0xAC3A40ea0c693419d5a105FbF930320761A71303",
  },
  {
    name: "CRV - VirtuSwap Test",
    sym: "CRV",
    address: "0x52d75181c30B63Ca04A8615BD00Bb7F7b89802E9",
  },
  {
    name: "Carpool Life Economy - VirtuSwap Test",
    sym: "CPLE",
    address: "0xECaDF69184F04b4AF67e73D82e9D6eF4c190037E",
  },
  {
    name: "BLOK - VirtuSwap Test",
    sym: "BLOK",
    address: "0x0ADe2F6413535B43A3864a4B1cfF58234C787286",
  },
  {
    name: "Polygen - VirtuSwap Test",
    sym: "PGEN",
    address: "0x9690DCdb099baDbb143926Be877fD7DF2B80686C",
  },
  {
    name: "Radio Token - VirtuSwap Test",
    sym: "RADIO",
    address: "0x500b21d6348104588e678B4A2178496AE9210e25",
  },
];

const polygonWeb3 = new Web3(polygonProvider);

polygonWeb3.eth.getAccounts().then(async (accounts) => {
  console.log("working with account: " + accounts[0]);
  sendArgs = { from: accounts[0], gasPrice: 35000000000 };

  let adminAddress = "0x5eA409399e47F0Df9FAC47488A4010bfD04718a4";

  const vPairFactory = new polygonWeb3.eth.Contract(
    vPairFactoryJson.abi,
    "0x64F43876f8473154b8b6b44C940FCc4093515f34"
  );

  // for (let i = 0; i < tokens.length; i++) {
  //   try {
  //     const tokenInstance = new polygonWeb3.eth.Contract(
  //       TestnetERC20Json.abi,
  //       tokens[i].address
  //     );
  //     let changeTx = await tokenInstance.methods
  //       .changeAdmin(adminAddress)
  //       .send(sendArgs);
  //   } catch {}
  //   console.log(changeTx);
  // }
  try {
    let tx = await vPairFactory.methods
      .changeAdmin(adminAddress)
      .send(sendArgs);

    console.log(tx);
  } catch (ex) {
    console.log(ex);
  }
});
