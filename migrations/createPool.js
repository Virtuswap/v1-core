const Web3 = require("web3");
const HDWalletProvider = require("@truffle/hdwallet-provider");
const vRouterJson = require("../build/contracts/vRouter.json");
const ERC20Json = require("../build/contracts/ERC20.json");

var polygonProvider = new HDWalletProvider(
  "68bbb193208e193b6598e165685e40bde543898b0f7b195abb7173b0671b7b0b",
  `https://morning-twilight-cherry.matic-testnet.quiknode.pro/6ba9d2c5b8a046814b28f974c3643c679914f7ff/`
);

const web3 = new Web3(polygonProvider);

async function getFutureBlockTimestamp() {
  const blockNumber = await web3.eth.getBlockNumber();
  const block = await web3.eth.getBlock(blockNumber);
  return block.timestamp + 1000000;
}

web3.eth.getAccounts().then(async (accounts) => {
  console.log("working with account: " + accounts[0]);
  sendArgs = { from: accounts[0], gasPrice: 35000000000 };

  const vRouterInstance = new web3.eth.Contract(
    vRouterJson.abi,
    "0xe6d9a7a70Df56FE2FeeCCb6Ec33C543cb79c7B91"
  );

  const USDTInstance = new web3.eth.Contract(
    ERC20Json.abi,
    "0x82EDb0100BbBE6Eb17444b8cB20990D08e9FfE91"
  );

  const USDCInstance = new web3.eth.Contract(
    ERC20Json.abi,
    "0xe8E192264540F056A64498386e4835Aa5670D49c"
  );

  await USDCInstance.methods
    .approve(
      "0xe6d9a7a70Df56FE2FeeCCb6Ec33C543cb79c7B91",
      web3.utils.toWei("999999999999999999999999999999", "ether")
    )
    .send(sendArgs);

  await USDTInstance.methods
    .approve(
      "0xe6d9a7a70Df56FE2FeeCCb6Ec33C543cb79c7B91",
      web3.utils.toWei("999999999999999999999999999999", "ether")
    )
    .send(sendArgs);

  let futureTs = await getFutureBlockTimestamp();

  let tx = await vRouterInstance.methods
    .addLiquidity(
      "0xe8E192264540F056A64498386e4835Aa5670D49c",
      "0x82EDb0100BbBE6Eb17444b8cB20990D08e9FfE91",
      web3.utils.toWei("500000", "ether"),
      web3.utils.toWei("500000", "ether"),
      web3.utils.toWei("500000", "ether"),
      web3.utils.toWei("500000", "ether"),
      accounts[0],
      futureTs
    )
    .send(sendArgs);

  console.log(tx);
});
