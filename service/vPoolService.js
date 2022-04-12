const contractArtifact = require("../build/contracts/vPoolsManager.json");
const Web3 = require("web3");
const HDWalletProvider = require("@truffle/hdwallet-provider");

const network_id = Object.keys(contractArtifact.networks)[0];
// const provider = new Web3.providers.WebsocketProvider("http://127.0.0.1:8545");

// const contractAddress = contractArtifact.networks[network_id].address; //dev
// const contractAddress = "0x98Af25a2D8e8c0C9c0BA60008cC2b19A79f33f72";
const contractAddress = "0x6C293FeFD5E68e0bCf5EA7714878A4053951E5B7"; // testnet
const provider = new HDWalletProvider(
  "1769b8f5eac17e903baa453df47524a2d08996333d39e326f119f28cc77da56b",
  `https://rpc-mumbai.matic.today`
);

const web3 = new Web3(provider);

const vPool = new web3.eth.Contract(contractArtifact.abi, contractAddress); //local dev

let _eventEmitter = {};

let sendArgs = { gas: "6721975", gasPrice: "30000000" };

let sendArgsAccount = {};

class vPoolsService {
  eventHandler(err, ev) {
    if (!err) {
      let msg = "";

      ev.returnValues["1"] = web3.utils.fromWei(ev.returnValues["1"], "ether");

      if (ev.returnValues.hasOwnProperty("message")) {
        msg = ev.returnValues.message;
      } else {
        let keys = Object.keys(ev.returnValues);
        for (let i = 0; i < keys.length; i++) {
          msg += ev.returnValues[keys[i]] + " ";
        }
      }

      _eventEmitter.emit("scEvent", msg);
      console.log(ev.returnValues);
    }
  }

  constructor(eventEmitter) {
    _eventEmitter = eventEmitter;

    // console.log("working with contract: " + contractAddress);

    // const debugEvent = vPool.events.Debug({}, this.eventHandler);
    // const udebugEvent = vPool.events.UDebug({}, this.eventHandler);
    // const adebugEvent = vPool.events.ADebug({}, this.eventHandler);
    // const debugEvent1 = vPool.events.LogUint({}, this.eventHandler);
    // const debugEvent2 = vPool.events.LogInt({}, this.eventHandler);
    // const debugEvent3 = vPool.events.LogAddress({}, this.eventHandler);
    // const debugEvent4 = vPool.events.LogBool({}, this.eventHandler);
    // const debugEvent5 = vPool.events.LogStr({}, this.eventHandler);

    web3.eth.getAccounts().then((accounts) => {
      console.log("working with account: " + accounts[0]);
      sendArgs = { from: accounts[0], gas: "6721975", gasPrice: "30000000" };
      sendArgsAccount = { from: accounts[0] };
    });
  }

  registerCallback(callbackFunction) {
    this.callback = callbackFunction;
  }

  async getTokens() {
    const poolTokens = await vPool.methods.getTokens().call();
    return poolTokens;
  }

  async getContractAddress() {
    return contractAddress;
  }

  async getAccount() {
    return sendArgs.from;
  }

  async getAccountBalance() {
    let weiValue = await web3.eth.getBalance(sendArgs.from);
    return web3.utils.fromWei(weiValue, "ether");
  }

  async initPools() {
    const initPoolsTx = await vPool.methods._initPools().send(sendArgsAccount);
    return initPoolsTx;
  }

  async exchageReserves() {
    const exchangeReservesTx = await vPool.methods
      .exchageReserves()
      .send(sendArgs);
    return exchangeReservesTx;
  }

  async poolsCount() {
    let poolsCount = await vPool.methods.getPoolsCount().call();
    return poolsCount;
  }

  async getRPools() {
    const rPools = await vPool.methods.getRPools().call();
    return rPools;
  }

  async getVPools() {
    const vPools = await vPool.methods.getVPools().call();
    return vPools;
  }

  async getTotalsPool() {
    const tPools = await vPool.methods.getTPools().call();
    return tPools;
  }

  async getPoolsCount() {
    const poolsCount = await vPool.methods.getPoolsCount().call();
    return poolsCount;
  }

  async calculateReserveRatio() {
    const reserveRatioTx = await vPool.methods._calculateReserveRatio().call();
    return reserveRatioTx;
  }

  async calculateBelowThreshold() {
    const belowThresholdTx = await vPool.methods
      ._calculateBelowThreshold()
      .send(sendArgs);
    return belowThresholdTx;
  }

  async calculateBelowThreshold() {
    const belowThresholdTx = await vPool.methods
      ._calculateBelowThreshold()
      .call();
    return belowThresholdTx;
  }

  async calculateVirtualPools(rPoolIndex, ks, js) {
    const virtualPoolsTx = await vPool.methods
      ._calculateVirtualPool(rPoolIndex, ks, js)
      .call(sendArgs);

    return virtualPoolsTx;
  }

  async getPoolsInitialized() {
    const poolsInitialized = await vPool.methods.getPoolsInitialized().call();
    return poolsInitialized;
  }
  async testNums() {
    const testNums = await vPool.methods.testNums().send(sendArgs);
    return testNums;
  }

  async quote(inTokenAddress, outTokenAddress, amount) {
    const quoteRes = await vPool.methods
      .quote(inTokenAddress, outTokenAddress, amount)
      .call();
    return quoteRes;
  }

  async quoteVswapTrading(tokenAAddress, tokenBAddress, amount) {
    const quoteRes = await vPool.methods
      .quoteVirtuswap(tokenAAddress, tokenBAddress, amount)
      .send(sendArgs);
    return quoteRes;
  }

  async costUniswapIndirect() {
    const quoteRes = await vPool.methods
      .costUniswapIndirect(
        "0x28aA2245b0B9c94f6E2181618f1D66166D0d2068",
        "0x71eb04E6989f47D9f62899be5a9F235A4cA2Fe47",
        "1000000000000000000"
      )
      .send(sendArgs);
    return quoteRes;
  }

  async costUniswapdirect() {
    const quoteRes = await vPool.methods
      .costUniswapDirect(
        "0x28aA2245b0B9c94f6E2181618f1D66166D0d2068",
        "0x71eb04E6989f47D9f62899be5a9F235A4cA2Fe47",
        "1000000000000000000"
      )
      .call();
    return quoteRes;
  }

  async virtuswapCost() {
    const quoteRes = await vPool.methods
      .costVirtuswap(
        "0x28aA2245b0B9c94f6E2181618f1D66166D0d2068",
        "0x71eb04E6989f47D9f62899be5a9F235A4cA2Fe47",
        "1000000000000000000"
      )
      .call();
    return quoteRes;
  }

  async swap(inTokenAddress, outTokenAddress, amount) {
    const estimateGas = await vPool.methods
      .swap(inTokenAddress, outTokenAddress, amount)
      .estimateGas(sendArgsAccount);
    sendArgs.gas = estimateGas;
    const swapTx = await vPool.methods
      .swap(inTokenAddress, outTokenAddress, amount)
      .send(sendArgs);
    return swapTx;
  }

  async getPoolReserves(tokenAAddress, tokenBAddress) {
    const poolReserves = await vPool.methods
      .getPoolReserve(tokenAAddress, tokenBAddress)
      .call();
    return poolReserves;
  }
}

module.exports = vPoolsService;
