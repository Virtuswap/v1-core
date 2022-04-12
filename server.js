const express = require("express");
const app = express();
const port = 3000;
const expressWs = require("express-ws")(app);
const Web3 = require("web3");

const { RPoolVM, VPoolVM } = require("./VMs/rPoolVM");

var events = require("events");
var _eventEmitter = new events.EventEmitter();

const vPoolsService = require("./service/vPoolService");
const vPool = new vPoolsService(_eventEmitter);

_eventEmitter.on("scEvent", (r) => {
  expressWs.getWss().clients.forEach((client) => {
    client.send(r);
    // console.log(r);
  });
});

app.use(express.static("public"));

app.ws("/echo", function (ws, req) {
  ws.on("message", (rt) => {});
});

app.get("/api/", (req, res) => {
  res.send("Hello World!");
});

app.get("/api/status", async (req, res) => {
  let contractAddress = await vPool.getContractAddress();
  let accountAddress = await vPool.getAccount();
  let poolsCount = await vPool.getPoolsCount();
  let accountBalance = await vPool.getAccountBalance();

  res.send({
    contractAddress,
    accountAddress,
    poolsCount,
    accountBalance,
  });
});

app.get("/api/initPools", async (req, res) => {
  let initPools = await vPool.initPools();
  res.send(initPools);
});

app.get("/api/testNums", async (req, res) => {
  let testNums = await vPool.testNums();
  res.send(testNums);
});

app.get("/api/getRPools", async (req, res) => {
  let rPoolsRaw = await vPool.getRPools();
  let rPools = parseRPoolVM(rPoolsRaw);

  // let vPoolsRaw = await vPool.getVPools();
  // let vPools = parseVPoolVM(vPoolsRaw);

  // let tPoolRaw = await vPool.getTotalsPool();
  // let tPools = parseVPoolVM(tPoolRaw);

  res.send({ rPools });
});

app.get("/api/getPoolsInitialized", async (req, res) => {
  let poolsInitialized = await vPool.getPoolsInitialized();
  res.send(poolsInitialized);
});

app.get("/api/exchageReserves", async (req, res) => {
  let exchageReservesTx = await vPool.exchageReserves();
  res.send(exchageReservesTx);
});

app.get("/api/getTokens", async (req, res) => {
  let tokens = await vPool.getTokens();
  res.send(tokens);
});

app.get("/api/calculateReserve", async (req, res) => {
  let resesrveRatio = await vPool.calculateReserveRatio();
  res.send(resesrveRatio);
});

app.get("/api/getPoolReserves", async (req, res) => {
  let poolReserves = await vPool.getPoolReserves(
    req.query.tokenA,
    req.query.tokenB
  );

  for (let i = 0; i < poolReserves.length; i++) {
    if (poolReserves[i].reserveBalance) {
      poolReserves[i].reserveBalance = toEtherAdjusted(
        poolReserves[i].reserveBalance
      );
    }
  }

  res.send(poolReserves);
});

app.get("/api/calculateBelowThreshold", async (req, res) => {
  let belowThreshold = await vPool.calculateBelowThreshold();
  res.send(belowThreshold);
});

app.post("/api/calculateVpools", async (req, res) => {
  let rPoolIndex = req.body.rPoolIndex;
  let ks = req.body.ks;
  let js = req.body.js;
  let vPools = await vPool.calculateVirtualPools(rPoolIndex, ks, js);
  res.send(vPools);
});

app.get("/api/exchangeReserves", async (req, res) => {
  let vPools = await vPool.exchageReserves();
  res.send(vPools);
});

app.get("/api/costUniswapIndirect", async (req, res) => {
  let vPools = await vPool.costUniswapIndirect();
  res.send(vPools);
});

app.get("/api/virtuswapCost", async (req, res) => {
  let vPools = await vPool.virtuswapCost();
  res.send(vPools);
});

app.get("/api/costUniswapdirect", async (req, res) => {
  let vPools = await vPool.costUniswapdirect();
  res.send(vPools);
});

app.get("/api/swap", async (req, res) => {
  let inToken = req.query.tokenIn;
  let outToken = req.query.tokenOut;
  let amount = req.query.amount;

  let swapTx = await vPool.swap(
    inToken,
    outToken,
    Web3.utils.toWei(amount, "ether")
  );

  res.send(swapTx);
});

app.get("/api/quote", async (req, res) => {
  let inToken = req.query.tokenIn;
  let outToken = req.query.tokenOut;
  let amount = req.query.amount;

  let quoteRes = await vPool.quote(
    inToken,
    outToken,
    Web3.utils.toWei(amount, "ether")
  );

  res.send(quoteRes);
});

app.listen(port, () => {
  console.log(`Example app listening at http://localhost:${port}`);
});

function toEtherAdjusted(num, fixNum) {
  if (!num) return;
  if (fixNum == undefined) fixNum = 2;
  return parseFloat(Web3.utils.fromWei(num.toString(), "ether")).toFixed(
    fixNum
  );
}

function parseRPoolVM(rPools) {
  let arr = new Array();
  for (let i = 0; i < rPools.length; i++) {
    let vm = new RPoolVM();
    vm.tokenA = rPools[i].tokenA;

    vm.tokenB = rPools[i].tokenB;
    vm.fee = toEtherAdjusted(rPools[i].fee, 4) * 100;
    vm.id = rPools[i].id;

    vm.reserveRatio = rPools[i].reserveRatio;
    vm.belowReserve = rPools[i].belowReserve;
    vm.tokenABalance = toEtherAdjusted(rPools[i].tokenABalance);
    vm.tokenBBalance = toEtherAdjusted(rPools[i].tokenBBalance);
    vm.maxReserveRatio = toEtherAdjusted(rPools[i].maxReserveRatio);
    arr.push(vm);
  }

  return arr;
}

function parseVPoolVM(vPools) {
  let arr = new Array();
  for (let i = 0; i < vPools.length; i++) {
    let vm = new VPoolVM();

    vm.tokenAName = vPools[i].tokenAName;
    vm.tokenBName = vPools[i].tokenBName;
    vm.tokenABalance = toEtherAdjusted(vPools[i].tokenABalance);
    vm.tokenBBalance = toEtherAdjusted(vPools[i].tokenBBalance);
    vm.fee = toEtherAdjusted(vPools[i].fee, 4) * 100;

    arr.push(vm);
  }

  return arr;
}
