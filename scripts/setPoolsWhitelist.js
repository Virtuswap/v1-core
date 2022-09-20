const Web3 = require("web3");
const HDWalletProvider = require("@truffle/hdwallet-provider");
const vRouterJson = require("../build/contracts/vRouter.json");
const vPairJson = require("../build/contracts/vPair.json");
const TestnetERC20Json = require("../build/contracts/TestnetERC20.json");

var polygonProvider = new HDWalletProvider(
  "2fcdf6468c4a3eb0504953064d670b685ccbd99a3a9f845070bcdc1d4fe831d4",
  `https://morning-twilight-cherry.matic-testnet.quiknode.pro/6ba9d2c5b8a046814b28f974c3643c679914f7ff/`
);

const polygonWeb3 = new Web3(polygonProvider);

let pools = [
  "0x41D2a6355D23544E780f06aF75E180DaD026dA82",
  "0x31Bb121b7B6DC76A22dfBD5BAC5ccB290BfB4Bd0",
  "0x15c7DB9E9620b2C62A7EA56fd25408aC1845dC71",
  "0xD3250B2970E96D3aB2633Ec412F8ddeCCe19D6ac",
  "0x0ff560ff33f4dd86dc67a4c67b51569dEa69b873",
  "0x9F09e9EA6dc615623FdefB431c5229a15bfaB2f3",
];

let tokens = [
  "0x5451A9e85a498A0De15C4eE8A5f78b93CB720Dae",
  "0x028977DB66AbEdF1C1F3dEF461cc55e02322D29a",
  "0x4E4968c01924c5B7d5F71E2648011DA92dd6503E",
  "0x5f0aB2fB11898E0A26E2047Bc28d7479D9469a5F",
];

async function run() {
  let accounts = await polygonWeb3.eth.getAccounts();
  let sendArgs = { from: accounts[0], gasPrice: 35000000000 };

  for (let i = 0; i < i < pools.length; i++) {
    const pool = new polygonWeb3.eth.Contract(vPairJson.abi, pools[i]);
    await pool.methods.setAllowList(tokens).send(sendArgs);
  }
}

run().then((a) => {
  console.log(a);
});
