const Web3 = require("web3");
const HDWalletProvider = require("@truffle/hdwallet-provider");
const vPairFactoryJson = require("../build/contracts/vPairFactory.json");

var polygonProvider = new HDWalletProvider(
  "68bbb193208e193b6598e165685e40bde543898b0f7b195abb7173b0671b7b0b",
  `https://morning-twilight-cherry.matic-testnet.quiknode.pro/6ba9d2c5b8a046814b28f974c3643c679914f7ff/`
);

const polygonWeb3 = new Web3(polygonProvider);

polygonWeb3.eth.getAccounts().then(async (accounts) => {
  console.log("working with account: " + accounts[0]);
  sendArgs = { from: accounts[0], gasPrice: 35000000000 };

  const vPairFactory = new polygonWeb3.eth.Contract(
    vPairFactoryJson.abi,
    "0xb29716D3c7C319038330725762Ed3D93f8108436"
  );
  let tx = await vPairFactory.methods
    .changeAdmin("0x5eA409399e47F0Df9FAC47488A4010bfD04718a4")
    .send(sendArgs);

  console.log(tx);
});
