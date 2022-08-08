const vRouter = artifacts.require("vRouter");
const vPair = artifacts.require("vPair");
const vPairFactory = artifacts.require("vPairFactory");
const vSwapLibrary = artifacts.require("vSwapLibrary");
const ERC20 = artifacts.require("ERC20PresetFixedSupply");
const { getEncodedSwapData } = require("./utils");


contract("ReserveRatio", (accounts) => {
  function fromWeiToNumber(number) {
    return (
      parseFloat(web3.utils.fromWei(number.toString(), "ether")).toFixed(6) * 1
    );
  }

  async function getFutureBlockTimestamp() {
    const blockNumber = await web3.eth.getBlockNumber();
    const block = await web3.eth.getBlock(blockNumber);
    return block.timestamp + 1000000;
  }

  const A_PRICE = 1;
  const B_PRICE = 2;
  const C_PRICE = 6;
  const D_PRICE = 10;

  let tokenA, tokenB, tokenC, tokenD;

  const issueAmount = web3.utils.toWei("100000000000000", "ether");

  let vPairFactoryInstance, vRouterInstance, vSwapLibraryInstance;

  before(async () => {
    tokenA = await ERC20.new("tokenA", "A", issueAmount, accounts[0]);

    tokenB = await ERC20.new("tokenB", "B", issueAmount, accounts[0]);

    tokenC = await ERC20.new("tokenC", "C", issueAmount, accounts[0]);

    tokenD = await ERC20.new("tokenD", "D", issueAmount, accounts[0]);

    vPairFactoryInstance = await vPairFactory.deployed();
    vRouterInstance = await vRouter.deployed();
    vSwapLibraryInstance = await vSwapLibrary.deployed();

    await tokenA.approve(vRouterInstance.address, issueAmount);
    await tokenB.approve(vRouterInstance.address, issueAmount);
    await tokenC.approve(vRouterInstance.address, issueAmount);
    await tokenD.approve(vRouterInstance.address, issueAmount);

    const futureTs = await getFutureBlockTimestamp();

    //create pool A/B with 10,000 A and equivalent B
    let AInput = 100 * A_PRICE;
    let BInput = (B_PRICE / A_PRICE) * AInput;

    await vRouterInstance.addLiquidity(
      tokenA.address,
      tokenB.address,
      web3.utils.toWei(AInput.toString(), "ether"),
      web3.utils.toWei(BInput.toString(), "ether"),
      web3.utils.toWei(AInput.toString(), "ether"),
      web3.utils.toWei(BInput.toString(), "ether"),
      accounts[0],
      futureTs
    );

    //create pool A/C
    //create pool A/B with 10,000 A and equivalent C

    let CInput = (C_PRICE / A_PRICE) * AInput;
    await vRouterInstance.addLiquidity(
      tokenA.address,
      tokenC.address,
      web3.utils.toWei(AInput.toString(), "ether"),
      web3.utils.toWei(CInput.toString(), "ether"),
      web3.utils.toWei(AInput.toString(), "ether"),
      web3.utils.toWei(CInput.toString(), "ether"),
      accounts[0],
      futureTs
    );

    //create pool B/C
    //create pool B/C with 10,000 B and equivalent C
    BInput = 20000 * B_PRICE;
    CInput = (C_PRICE / B_PRICE) * BInput;
    await vRouterInstance.addLiquidity(
      tokenB.address,
      tokenC.address,
      web3.utils.toWei(BInput.toString(), "ether"),
      web3.utils.toWei(CInput.toString(), "ether"),
      web3.utils.toWei(BInput.toString(), "ether"),
      web3.utils.toWei(CInput.toString(), "ether"),
      accounts[0],
      futureTs
    );

    //create pool B/D
    //create pool B/D with 10,000 B and equivalent C
    BInput = 50000 * B_PRICE;
    let DInput = (D_PRICE / B_PRICE) * BInput;
    await vRouterInstance.addLiquidity(
      tokenB.address,
      tokenD.address,
      web3.utils.toWei(BInput.toString(), "ether"),
      web3.utils.toWei(DInput.toString(), "ether"),
      web3.utils.toWei(BInput.toString(), "ether"),
      web3.utils.toWei(DInput.toString(), "ether"),
      accounts[0],
      futureTs
    );

    //whitelist tokens in pools

    //pool 1
    const address = await vPairFactoryInstance.getPair(
      tokenA.address,
      tokenB.address
    );
    const pool = await vPair.at(address);

    //whitelist token C
    await pool.setWhitelist([tokenC.address, tokenD.address]);

    let reserve0 = await pool.reserve0();
    let reserve1 = await pool.reserve1();

    reserve0 = fromWeiToNumber(reserve0);
    reserve1 = fromWeiToNumber(reserve1);

    // console.log("pool1: A/B: " + reserve0 + "/" + reserve1);

    //pool 2
    const address2 = await vPairFactoryInstance.getPair(
      tokenA.address,
      tokenC.address
    );
    const pool2 = await vPair.at(address2);

    //whitelist token B
    await pool2.setWhitelist([tokenB.address, tokenD.address]);

    let reserve0Pool2 = await pool2.reserve0();
    let reserve1Pool2 = await pool2.reserve1();

    reserve0Pool2 = fromWeiToNumber(reserve0Pool2);
    reserve1Pool2 = fromWeiToNumber(reserve1Pool2);

    // console.log("pool2: A/C: " + reserve0Pool2 + "/" + reserve1Pool2);

    //pool 3
    const address3 = await vPairFactoryInstance.getPair(
      tokenB.address,
      tokenC.address
    );
    const pool3 = await vPair.at(address3);

    //whitelist token A
    await pool3.setWhitelist([tokenA.address, tokenD.address]);

    let reserve0Pool3 = await pool3.reserve0();
    let reserve1Pool3 = await pool3.reserve1();

    reserve0Pool3 = fromWeiToNumber(reserve0Pool3);
    reserve1Pool3 = fromWeiToNumber(reserve1Pool3);

    // console.log("pool3: B/C: " + reserve0Pool3 + "/" + reserve1Pool3);

    //pool 4
    const address4 = await vPairFactoryInstance.getPair(
      tokenB.address,
      tokenD.address
    );
    const pool4 = await vPair.at(address4);

    //whitelist token A
    await pool4.setWhitelist([tokenA.address, tokenC.address]);

    let reserve0Pool4 = await pool4.reserve0();
    let reserve1Pool4 = await pool4.reserve1();

    reserve0Pool4 = fromWeiToNumber(reserve0Pool4);
    reserve1Pool4 = fromWeiToNumber(reserve1Pool4);

    // console.log("pool4: B/D: " + reserve0Pool4 + "/" + reserve1Pool4);
  });

  it("Should increase reserveRatio and reservesBaseValue of C after adding C to pool A/B", async () => {
    const ikPair = await vPairFactoryInstance.getPair(
      tokenC.address,
      tokenB.address
    );

    const jkPair = await vPairFactoryInstance.getPair(
      tokenB.address,
      tokenA.address
    );

    const pool = await vPair.at(jkPair);

    let amountOut = web3.utils.toWei("1", "ether");

    let amountIn = await vRouterInstance.getVirtualAmountIn(
      jkPair,
      ikPair,
      amountOut
    );

    let amountCInBalance = await tokenC.balanceOf(pool.address);
    let amountCInReserve = await pool.reserves(tokenC.address);
    let amountCInReserveBaseValue = await pool.reservesBaseValue(
      tokenC.address
    );

    let reserveRatioBefore = await pool.calculateReserveRatio();
    let tokenCReserve = await pool.reservesBaseValue(tokenC.address);

    //Conversion errors of weiToNumber
    amountIn = web3.utils.toWei(
      (fromWeiToNumber(amountIn.toString()) * 1.001).toFixed(5),
      "ether"
    );

    let data = getEncodedSwapData(
      accounts[0],
      tokenC.address,
      tokenA.address,
      tokenB.address,
      amountIn
    );

    const futureTs = await getFutureBlockTimestamp();

    await vRouterInstance.swapReserveToExactNative(
      tokenA.address,
      tokenB.address,
      ikPair,
      amountOut,
      accounts[0],
      data,
      futureTs
    );

    let amountCInBalanceAfter = await tokenC.balanceOf(pool.address);
    let amountCInReserveAfter = await pool.reserves(tokenC.address);
    let amountCInReserveBaseValueAfter = await pool.reservesBaseValue(
      tokenC.address
    );

    // console.log("amountCInReserve " + amountCInReserve);
    // console.log("amountCInReserveAfter " + amountCInReserveAfter);

    // console.log("amountCInReserveBaseValue " + amountCInReserveBaseValue);
    // console.log(
    //   "amountCInReserveBaseValueAfter " + amountCInReserveBaseValueAfter
    // );

    let reserveRatioAfter = await pool.calculateReserveRatio();

    expect(fromWeiToNumber(reserveRatioBefore)).to.lessThan(
      fromWeiToNumber(reserveRatioAfter)
    );

    let tokenCReserveAfter = await pool.reservesBaseValue(tokenC.address);
    expect(fromWeiToNumber(tokenCReserve)).to.lessThan(
      fromWeiToNumber(tokenCReserveAfter)
    );
  });

  it("Should increase reserveRatio and reservesBaseValue of C after adding C for A on pool A/B #2", async () => {
    const ikPair = await vPairFactoryInstance.getPair(
      tokenC.address,
      tokenB.address
    );

    const jkPair = await vPairFactoryInstance.getPair(
      tokenB.address,
      tokenA.address
    );

    const pool = await vPair.at(jkPair);

    let amountOut = web3.utils.toWei("1", "ether");

    let amountIn = await vRouterInstance.getVirtualAmountIn(
      jkPair,
      ikPair,
      amountOut
    );

    let amountCInBalance = await tokenC.balanceOf(pool.address);
    let amountCInReserve = await pool.reserves(tokenC.address);
    let amountCInReserveBaseValue = await pool.reservesBaseValue(
      tokenC.address
    );

    let reserveRatioBefore = await pool.calculateReserveRatio();
    let tokenCReserve = await pool.reservesBaseValue(tokenC.address);
    //Conversion errors of weiToNumber
    amountIn = web3.utils.toWei(
      (fromWeiToNumber(amountIn.toString()) * 1.001).toFixed(5),
      "ether"
    );

    let data = getEncodedSwapData(
      accounts[0],
      tokenC.address,
      tokenA.address,
      tokenB.address,
      amountIn
    );

    const futureTs = await getFutureBlockTimestamp();

    await vRouterInstance.swapReserveToExactNative(
      tokenA.address,
      tokenB.address,
      ikPair,
      amountOut,
      accounts[0],
      data,
      futureTs
    );

    let amountCInBalanceAfter = await tokenC.balanceOf(pool.address);
    let amountCInReserveAfter = await pool.reserves(tokenC.address);
    let amountCInReserveBaseValueAfter = await pool.reservesBaseValue(
      tokenC.address
    );
    let reserveRatioAfter = await pool.calculateReserveRatio();

    expect(fromWeiToNumber(reserveRatioBefore)).to.lessThan(
      fromWeiToNumber(reserveRatioAfter)
    );

    let tokenCReserveAfter = await pool.reservesBaseValue(tokenC.address);
    expect(fromWeiToNumber(tokenCReserve)).to.lessThan(
      fromWeiToNumber(tokenCReserveAfter)
    );
  });

  it("Should increase reserveRatio and reservesBaseValue of C after adding C for B on pool A/B", async () => {
    const ikPair = await vPairFactoryInstance.getPair(
      tokenC.address,
      tokenA.address
    );

    const jkPair = await vPairFactoryInstance.getPair(
      tokenB.address,
      tokenA.address
    );

    const pool = await vPair.at(jkPair);

    let amountOut = web3.utils.toWei("1", "ether");

    let amountIn = await vRouterInstance.getVirtualAmountIn(
      jkPair,
      ikPair,
      amountOut
    );

    let amountCInBalance = await tokenC.balanceOf(pool.address);
    let amountCInReserve = await pool.reserves(tokenC.address);
    let amountCInReserveBaseValue = await pool.reservesBaseValue(
      tokenC.address
    );

    let reserveRatioBefore = await pool.calculateReserveRatio();
    let tokenCReserve = await pool.reservesBaseValue(tokenC.address);
    amountIn = web3.utils.toWei(
      (fromWeiToNumber(amountIn.toString()) * 1.001).toFixed(5),
      "ether"
    );

    let data = getEncodedSwapData(
      accounts[0],
      tokenC.address,
      tokenA.address,
      tokenB.address,
      amountIn
    );

    const futureTs = await getFutureBlockTimestamp();

    await vRouterInstance.swapReserveToExactNative(
      tokenA.address,
      tokenB.address,
      ikPair,
      amountOut,
      accounts[0],
      data,
      futureTs
    );

    let amountCInBalanceAfter = await tokenC.balanceOf(pool.address);
    let amountCInReserveAfter = await pool.reserves(tokenC.address);
    let amountCInReserveBaseValueAfter = await pool.reservesBaseValue(
      tokenC.address
    );
    let reserveRatioAfter = await pool.calculateReserveRatio();

    expect(fromWeiToNumber(reserveRatioBefore)).to.lessThan(
      fromWeiToNumber(reserveRatioAfter)
    );

    let tokenCReserveAfter = await pool.reservesBaseValue(tokenC.address);
    expect(fromWeiToNumber(tokenCReserve)).to.lessThan(
      fromWeiToNumber(tokenCReserveAfter)
    );
  });

  // it("Should update price after a 50% drop in price of C in pool A/B", async () => {
  //   const ikPair = await vPairFactoryInstance.getPair(
  //     tokenC.address,
  //     tokenB.address
  //   );

  //   const jkPair = await vPairFactoryInstance.getPair(
  //     tokenB.address,
  //     tokenA.address
  //   );

  //   let amountIn = web3.utils.toWei("120000", "ether");

  //   const pool = await vPair.at(jkPair);
  //   const ikpool = await vPair.at(ikPair);

  //   //
  //   let reserves = await ikpool.getReserves();

  //   console.log("Pool B/C - reserves 0 " + fromWeiToNumber(reserves["0"]));
  //   console.log("Pool B/C - reserves 1 " + fromWeiToNumber(reserves["1"]));

  //   //get quote
  //   let amountOutOne = await vRouterInstance.getAmountOut(
  //     tokenC.address,
  //     tokenB.address,
  //     web3.utils.toWei("1", "ether")
  //   );

  //   console.log(
  //     "Pool B/C - for 1C gets " + fromWeiToNumber(amountOutOne) + "B"
  //   );

  //   //get quote
  //   let amountOut = await vRouterInstance.getAmountOut(
  //     tokenC.address,
  //     tokenB.address,
  //     amountIn
  //   );

  //   console.log(
  //     "Pool B/C - for " +
  //       fromWeiToNumber(amountIn) +
  //       "C gets " +
  //       fromWeiToNumber(amountOut) +
  //       "B"
  //   );

  //   //reserve of C in pool JK
  //   let reserveBaseBalance = await pool.reservesBaseValue(tokenC.address);
  //   let reserveBalance = await pool.reserves(tokenC.address);

  //   console.log(
  //     "Pool A/B - C reserve balance: " + fromWeiToNumber(reserveBalance)
  //   );
  //   console.log(
  //     "Pool A/B - C reserve balance in token0: " +
  //       fromWeiToNumber(reserveBaseBalance)
  //   );

  //   console.log(
  //     "-------------------\nPool B/C - swapping " +
  //       fromWeiToNumber(amountIn) +
  //       "C for " +
  //       fromWeiToNumber(amountOut) +
  //       "B"
  //   );

  //   let data = getEncodedSwapData(
  //     accounts[0],
  //     tokenC.address,
  //     tokenA.address,
  //     tokenB.address,
  //     amountIn
  //   );

  //   const futureTs = await getFutureBlockTimestamp();

  //   await vRouterInstance.swapToExactNative(
  //     tokenA.address,
  //     tokenB.address,
  //     amountOut,
  //     accounts[0],
  //     data,
  //     futureTs
  //   );

  //   let reservesAfterSwap = await ikpool.getReserves();

  //   console.log(
  //     "Pool B/C - reserves 0 " + fromWeiToNumber(reservesAfterSwap["0"])
  //   );
  //   console.log(
  //     "Pool B/C - reserves 1 " + fromWeiToNumber(reservesAfterSwap["1"])
  //   );

  //   //get quote
  //   let amountOutOneAfter = await vRouterInstance.getAmountOut(
  //     tokenC.address,
  //     tokenB.address,
  //     web3.utils.toWei("1", "ether")
  //   );

  //   console.log(
  //     "Pool B/C - for 1C gets " + fromWeiToNumber(amountOutOneAfter) + "B"
  //   );

  //   console.log("-------------------\nSwap C for A in vPool A/C ");

  //   let amountOutA = web3.utils.toWei("1", "ether");

  //   const ikPair2 = await vPairFactoryInstance.getPair(
  //     tokenC.address,
  //     tokenB.address
  //   );

  //   const jkPair2 = await vPairFactoryInstance.getPair(
  //     tokenB.address,
  //     tokenA.address
  //   );

  //   //get amountIn
  //   let amountInC = await vRouterInstance.getVirtualAmountIn(
  //     jkPair2,
  //     ikPair2,
  //     amountOutA
  //   );

  //   console.log(
  //     "vPool A/C - for " +
  //       fromWeiToNumber(amountInC) +
  //       "C gets " +
  //       fromWeiToNumber(amountOutA) +
  //       "A"
  //   );

  //   //add C and get B from pool AB
  //   await vRouterInstance.swap(
  //     [jkPair2],
  //     [amountInC],
  //     [amountOutA],
  //     [ikPair2],
  //     tokenC.address,
  //     tokenA.address,
  //     accounts[0],
  //     futureTs
  //   );

  //   //reserve of C in pool JK
  //   let reserveBaseBalanceAfter = await pool.reservesBaseValue(tokenC.address);
  //   let reserveBalanceAfter = await pool.reserves(tokenC.address);

  //   console.log(
  //     "Pool A/B - C reserve balance: " + fromWeiToNumber(reserveBalanceAfter)
  //   );
  //   console.log(
  //     "Pool A/B - C reserve balance in token0: " +
  //       fromWeiToNumber(reserveBaseBalanceAfter)
  //   );
  // });

  // it("Should increase reserveRatio and reservesBaseValue of D after adding D to pool A/B", async () => {
  //   const ikPair = await vPairFactoryInstance.getPair(
  //     tokenD.address,
  //     tokenB.address
  //   );

  //   const jkPair = await vPairFactoryInstance.getPair(
  //     tokenB.address,
  //     tokenA.address
  //   );

  //   let amountOut = web3.utils.toWei("2", "ether");

  //   const amountIn = await vRouterInstance.getVirtualAmountIn(
  //     jkPair,
  //     ikPair,
  //     amountOut
  //   );

  //   const pool = await vPair.at(jkPair);

  //   const futureTs = await getFutureBlockTimestamp();

  //   let reserveRatioBefore = await pool.calculateReserveRatio();

  //   let tokenDReserve = await pool.reservesBaseValue(tokenD.address);

  //   await vRouterInstance.swap(
  //     [jkPair],
  //     [amountIn],
  //     [amountOut],
  //     [ikPair],
  //     tokenD.address,
  //     tokenA.address,
  //     accounts[0],
  //     futureTs
  //   );

  //   let tokenDReserveAfter = await pool.reservesBaseValue(tokenD.address);
  //   let reserveRatioAfter = await pool.calculateReserveRatio();

  //   expect(fromWeiToNumber(reserveRatioBefore)).to.lessThan(
  //     fromWeiToNumber(reserveRatioAfter)
  //   );

  //   expect(fromWeiToNumber(tokenDReserve)).to.lessThan(
  //     fromWeiToNumber(tokenDReserveAfter)
  //   );
  // });

  it("Assert pool A/B calculateReserveRatio is correct ", async () => {
    const jkPair = await vPairFactoryInstance.getPair(
      tokenB.address,
      tokenA.address
    );

    let pool = await vPair.at(jkPair);
    let poolReserveRatio = await pool.calculateReserveRatio();

    let poolCReserves = await pool.reservesBaseValue(tokenC.address);
    let poolDReserves = await pool.reservesBaseValue(tokenD.address);

    poolCReserves = fromWeiToNumber(poolCReserves);
    poolDReserves = fromWeiToNumber(poolDReserves);

    let totalReserves = poolCReserves + poolDReserves;

    console.log("totalReserves " + totalReserves);

    let reserve0 = await pool.reserve0();
    reserve0 = fromWeiToNumber(reserve0);
    let poolLiquidity = reserve0 * 2;

    let reserveRatioPCT =
      ((totalReserves / poolLiquidity) * 100).toFixed(3) * 1;

    poolReserveRatio = fromWeiToNumber(poolReserveRatio);

    let maxReserveRatio = await pool.max_reserve_ratio();

    assert.equal(
      parseInt(poolReserveRatio),
      reserveRatioPCT * 1000,
      "Pool reserve ratio is not equal to calculated in test"
    );
  });

  it("Should revert swap that goes beyond reserve ratio", async () => {
    const ikPair = await vPairFactoryInstance.getPair(
      tokenD.address,
      tokenB.address
    );

    const jkPair = await vPairFactoryInstance.getPair(
      tokenB.address,
      tokenA.address
    );

    let amountOut = web3.utils.toWei("40", "ether");

    const amountIn = await vRouterInstance.getVirtualAmountIn(
      jkPair,
      ikPair,
      amountOut
    );

    const futureTs = await getFutureBlockTimestamp();

    let reverted = false;
    try {
      await vRouterInstance.swap(
        [jkPair],
        [amountIn],
        [amountOut],
        [ikPair],
        tokenD.address,
        tokenA.address,
        accounts[0],
        futureTs
      );
    } catch {
      reverted = true;
    }

    assert(reverted, "EXPECTED SWAP TO REVERT");
  });

  it("Withdrawal from pool A/B and check reserves and reserveRatio", async () => {
    const poolAddress = await vPairFactoryInstance.getPair(
      tokenB.address,
      tokenA.address
    );
    const pool = await vPair.at(poolAddress);

    let balance = await pool.balanceOf(accounts[0]);

    //get 30% of balance out
    let balanceOut = fromWeiToNumber(balance) * 0.3;

    await pool.approve(
      vRouterInstance.address,
      web3.utils.toWei(balanceOut.toString())
    );

    let reserves = await pool.getReserves();

    let amountADesired = fromWeiToNumber(reserves["0"]) * 0.29;
    let amountBDesired = fromWeiToNumber(reserves["1"]) * 0.29;

    let amountCInBalance = await tokenC.balanceOf(pool.address);
    let amountCInReserve = await pool.reserves(tokenC.address);
    let amountCInReserveBaseValue = await pool.reservesBaseValue(
      tokenC.address
    );

    const futureTs = await getFutureBlockTimestamp();
    await vRouterInstance.removeLiquidity(
      tokenA.address,
      tokenB.address,
      web3.utils.toWei(balanceOut.toString()),
      web3.utils.toWei(amountADesired.toString()),
      web3.utils.toWei(amountBDesired.toString()),
      accounts[0],
      futureTs
    );

    let amountCInBalanceAfter = await tokenC.balanceOf(pool.address);
    let amountCInReserveAfter = await pool.reserves(tokenC.address);
    let amountCInReserveBaseValueAfter = await pool.reservesBaseValue(
      tokenC.address
    );
  });
});
