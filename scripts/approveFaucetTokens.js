const TestnetERC20Json = require("../build/contracts/TestnetERC20.json");
const Web3 = require("web3");
const HDWalletProvider = require("@truffle/hdwallet-provider");
require("dotenv").config();
const fs = require("fs");

let tokens = [
  "0x5451A9e85a498A0De15C4eE8A5f78b93CB720Dae",
  "0x028977DB66AbEdF1C1F3dEF461cc55e02322D29a",
  "0x4E4968c01924c5B7d5F71E2648011DA92dd6503E",
  "0x5f0aB2fB11898E0A26E2047Bc28d7479D9469a5F",
];

var polygonProvider = new HDWalletProvider(
  "cb1228f06f7be4b34f31554492643fb439c4ebe27c8be1029cda1523a4745f6a",
  `https://morning-twilight-cherry.matic-testnet.quiknode.pro/6ba9d2c5b8a046814b28f974c3643c679914f7ff/`
);

const polygonWeb3 = new Web3(polygonProvider);

async function run() {
  let accounts = await polygonWeb3.eth.getAccounts();
  for (let i = 0; i < tokens.length; i++) {
    const pair = new polygonWeb3.eth.Contract(TestnetERC20Json.abi, tokens[i]);
    await pair.methods
      .approve(
        "0xF5704Fb2159664b36a8055468a0102F26fbe8D18",
        polygonWeb3.utils.toWei("10000000000000000000", "ether")
      )
      .send({ from: accounts[0] });
  }
}

run().then((a) => {
  console.log(a);
});
