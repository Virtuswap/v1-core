const Web3 = require("web3");
const HDWalletProvider = require("@truffle/hdwallet-provider");
const ConsolidateERC20TxsJson = require("../build/contracts/ConsolidateERC20Txs.json");

var polygonProvider = new HDWalletProvider(
  "2fcdf6468c4a3eb0504953064d670b685ccbd99a3a9f845070bcdc1d4fe831d4",
  `https://morning-twilight-cherry.matic-testnet.quiknode.pro/6ba9d2c5b8a046814b28f974c3643c679914f7ff/`
);

const polygonWeb3 = new Web3(polygonProvider);

polygonWeb3.eth.getAccounts().then(async (accounts) => {
  console.log("working with account: " + accounts[0]);
  sendArgs = { from: accounts[0], gasPrice: 35000000000 };

  let adminAddress = "0x4d44eE596202DCBB97963581ea3F99a4978B44CF";

  const ConsolidateERC20Txs = new polygonWeb3.eth.Contract(
    ConsolidateERC20TxsJson.abi,
    "0xF5704Fb2159664b36a8055468a0102F26fbe8D18"
  );

  let admin = await ConsolidateERC20Txs.methods.admin().call();
  console.log(admin);

  try {
    let tx = await ConsolidateERC20Txs.methods
      .changeAdmin(adminAddress)
      .send(sendArgs);

    console.log(tx);
  } catch (ex) {
    console.log(ex);
  }
});
