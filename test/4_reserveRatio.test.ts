import { loadFixture } from "@nomicfoundation/hardhat-network-helpers";
import { expect } from "chai";
import { ethers } from "hardhat";
import { deployPools } from "./fixtures/deployPools";
import _ from "lodash";
import utils from "./utils";

describe("ReserveRatio", () => {
  let fixture: any = {};

  before(async function () {
    fixture = await loadFixture(deployPools);
  });

  it("Should increase reserveRatio and reservesBaseValue of C after adding C for A to pool A/B", async () => {
    const abPool = fixture.abPool;
    const bcPool = fixture.bcPool;
    const tokenA = fixture.tokenA;
    const tokenB = fixture.tokenB;
    const tokenC = fixture.tokenC;
    const owner = fixture.owner;
    const vRouterInstance = fixture.vRouterInstance;

    let amountOut = ethers.utils.parseEther("1");

    let amountIn = await vRouterInstance.getVirtualAmountIn(
      abPool.address,
      bcPool.address,
      amountOut
    );

    let reserveRatioBefore = await abPool.calculateReserveRatio();
    let tokenCReserve = await abPool.reservesBaseValue(tokenC.address);

    const futureTs = await utils.getFutureBlockTimestamp();

    await vRouterInstance.swapReserveExactOutput(
      tokenA.address,
      tokenB.address,
      bcPool.address,
      amountOut,
      amountIn,
      owner.address,
      futureTs
    );

    let reserveRatioAfter = await abPool.calculateReserveRatio();

    expect(reserveRatioBefore).to.lessThan(reserveRatioAfter);

    let tokenCReserveAfter = await abPool.reservesBaseValue(tokenC.address);
    expect(tokenCReserve).to.lessThan(tokenCReserveAfter);
  });

  it("Should increase reserveRatio and reservesBaseValue of C after adding C for B to pool A/B", async () => {
    const abPool = fixture.abPool;
    const bcPool = fixture.bcPool;
    const acPool = fixture.acPool;
    const tokenA = fixture.tokenA;
    const tokenB = fixture.tokenB;
    const tokenC = fixture.tokenC;
    const owner = fixture.owner;
    const vRouterInstance = fixture.vRouterInstance;
    const vPairFactoryInstance = fixture.vPairFactoryInstance;

    let amountOut = ethers.utils.parseEther("1");

    let amountIn = await vRouterInstance.getVirtualAmountIn(
      acPool.address,
      bcPool.address,
      amountOut
    );

    let reserveRatioBefore = await abPool.calculateReserveRatio();
    let tokenCReserve = await abPool.reservesBaseValue(tokenC.address);

    const futureTs = await utils.getFutureBlockTimestamp();

    await vRouterInstance.swapReserveExactOutput(
      tokenA.address,
      tokenB.address,
      acPool.address,
      amountOut,
      amountIn,
      owner.address,
      futureTs
    );

    let reserveRatioAfter = await abPool.calculateReserveRatio();

    expect(reserveRatioBefore).to.lessThan(reserveRatioAfter);

    let tokenCReserveAfter = await abPool.reservesBaseValue(tokenC.address);
    expect(tokenCReserve).to.lessThan(tokenCReserveAfter);
  });

  it("Should increase reserveRatio and reservesBaseValue of C after adding C for A on pool A/B #2", async () => {
    const abPool = fixture.abPool;
    const bcPool = fixture.bcPool;
    const tokenA = fixture.tokenA;
    const tokenB = fixture.tokenB;
    const tokenC = fixture.tokenC;
    const owner = fixture.owner;
    const vRouterInstance = fixture.vRouterInstance;
    const vPairFactoryInstance = fixture.vPairFactoryInstance;
    const ikPair = await vPairFactoryInstance.getPair(
      tokenC.address,
      tokenB.address
    );

    const jkPair = await vPairFactoryInstance.getPair(
      tokenB.address,
      tokenA.address
    );

    let amountOut = ethers.utils.parseEther("1");

    let amountIn = await vRouterInstance.getVirtualAmountIn(
      jkPair,
      ikPair,
      amountOut
    );

    let reserveRatioBefore = await abPool.calculateReserveRatio();
    let tokenCReserve = await abPool.reservesBaseValue(tokenC.address);

    const futureTs = await utils.getFutureBlockTimestamp();

    await vRouterInstance.swapReserveExactOutput(
      tokenA.address,
      tokenB.address,
      ikPair,
      amountOut,
      amountIn,
      owner.address,
      futureTs
    );

    let reserveRatioAfter = await abPool.calculateReserveRatio();

    expect(reserveRatioBefore).to.lessThan(reserveRatioAfter);

    let tokenCReserveAfter = await abPool.reservesBaseValue(tokenC.address);
    expect(tokenCReserve).to.lessThan(tokenCReserveAfter);
  });

  it("Should increase reserveRatio and reservesBaseValue of C after adding C for B on pool A/B", async () => {
    const abPool = fixture.abPool;
    const bcPool = fixture.bcPool;
    const tokenA = fixture.tokenA;
    const tokenB = fixture.tokenB;
    const tokenC = fixture.tokenC;
    const owner = fixture.owner;
    const vRouterInstance = fixture.vRouterInstance;
    const vPairFactoryInstance = fixture.vPairFactoryInstance;
    const ikPair = await vPairFactoryInstance.getPair(
      tokenC.address,
      tokenA.address
    );

    const jkPair = await vPairFactoryInstance.getPair(
      tokenB.address,
      tokenA.address
    );

    let amountOut = ethers.utils.parseEther("1");

    let amountIn = await vRouterInstance.getVirtualAmountIn(
      jkPair,
      ikPair,
      amountOut
    );

    let reserveRatioBefore = await abPool.calculateReserveRatio();
    let tokenCReserve = await abPool.reservesBaseValue(tokenC.address);

    const futureTs = await utils.getFutureBlockTimestamp();

    await vRouterInstance.swapReserveExactOutput(
      tokenA.address,
      tokenB.address,
      ikPair,
      amountOut,
      amountIn,
      owner.address,
      futureTs
    );

    let reserveRatioAfter = await abPool.calculateReserveRatio();

    expect(reserveRatioBefore).to.lessThan(reserveRatioAfter);

    let tokenCReserveAfter = await abPool.reservesBaseValue(tokenC.address);
    expect(tokenCReserve).to.lessThan(tokenCReserveAfter);
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

  //   console.log("Pool B/C - reserves 0 " + (reserves["0"]));
  //   console.log("Pool B/C - reserves 1 " + (reserves["1"]));

  //   //get quote
  //   let amountOutOne = await vRouterInstance.getAmountOut(
  //     tokenC.address,
  //     tokenB.address,
  //     web3.utils.toWei("1", "ether")
  //   );

  //   console.log(
  //     "Pool B/C - for 1C gets " + (amountOutOne) + "B"
  //   );

  //   //get quote
  //   let amountOut = await vRouterInstance.getAmountOut(
  //     tokenC.address,
  //     tokenB.address,
  //     amountIn
  //   );

  //   console.log(
  //     "Pool B/C - for " +
  //       (amountIn) +
  //       "C gets " +
  //       (amountOut) +
  //       "B"
  //   );

  //   //reserve of C in pool JK
  //   let reserveBaseBalance = await pool.reservesBaseValue(tokenC.address);
  //   let reserveBalance = await pool.reserves(tokenC.address);

  //   console.log(
  //     "Pool A/B - C reserve balance: " + (reserveBalance)
  //   );
  //   console.log(
  //     "Pool A/B - C reserve balance in token0: " +
  //       (reserveBaseBalance)
  //   );

  //   console.log(
  //     "-------------------\nPool B/C - swapping " +
  //       (amountIn) +
  //       "C for " +
  //       (amountOut) +
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
  //     "Pool B/C - reserves 0 " + (reservesAfterSwap["0"])
  //   );
  //   console.log(
  //     "Pool B/C - reserves 1 " + (reservesAfterSwap["1"])
  //   );

  //   //get quote
  //   let amountOutOneAfter = await vRouterInstance.getAmountOut(
  //     tokenC.address,
  //     tokenB.address,
  //     web3.utils.toWei("1", "ether")
  //   );

  //   console.log(
  //     "Pool B/C - for 1C gets " + (amountOutOneAfter) + "B"
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
  //       (amountInC) +
  //       "C gets " +
  //       (amountOutA) +
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
  //     "Pool A/B - C reserve balance: " + (reserveBalanceAfter)
  //   );
  //   console.log(
  //     "Pool A/B - C reserve balance in token0: " +
  //       (reserveBaseBalanceAfter)
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

  //   expect((reserveRatioBefore)).to.lessThan(
  //     (reserveRatioAfter)
  //   );

  //   expect((tokenDReserve)).to.lessThan(
  //     (tokenDReserveAfter)
  //   );
  // });

  //   it("Assert pool A/B calculateReserveRatio is correct ", async () => {
  //     const abPool = fixture.abPool;
  //     const bcPool = fixture.bcPool;
  //     const tokenA = fixture.tokenA;
  //     const tokenB = fixture.tokenB;
  //     const tokenC = fixture.tokenC;
  //     const tokenD = fixture.tokenD;

  //     const owner = fixture.owner;
  //     const vRouterInstance = fixture.vRouterInstance;
  //     const vPairFactoryInstance = fixture.vPairFactoryInstance;

  //     const jkPair = await vPairFactoryInstance.getPair(
  //       tokenB.address,
  //       tokenA.address
  //     );

  //     let poolReserveRatio = await abPool.calculateReserveRatio();

  //     let poolCReserves = await abPool.reservesBaseValue(tokenC.address);
  //     let poolDReserves = await abPool.reservesBaseValue(tokenD.address);

  //     poolCReserves = poolCReserves;
  //     poolDReserves = poolDReserves;

  //     let totalReserves = poolCReserves.add(poolDReserves);
  //     console.log('totalReserves ' + totalReserves);

  //     let reserve0 = await abPool.reserve0();
  //     reserve0 = reserve0;
  //     let poolLiquidity = reserve0.mul(2);
  //     console.log('poolLiquidity ' + poolLiquidity);

  //     let reserveRatioPCT = totalReserves.div(poolLiquidity);
  //     console.log('reserveRatioPCT ' + reserveRatioPCT);

  //     poolReserveRatio = poolReserveRatio;

  //     let maxReserveRatio = await abPool.max_reserve_ratio();

  //     expect(parseInt(poolReserveRatio)).to.equal(reserveRatioPCT * 1000);
  //   });

  it("Should revert swap that goes beyond reserve ratio", async () => {
    const abPool = fixture.abPool;
    const bcPool = fixture.bcPool;
    const tokenA = fixture.tokenA;
    const tokenB = fixture.tokenB;
    const tokenC = fixture.tokenC;
    const tokenD = fixture.tokenD;

    const owner = fixture.owner;
    const vRouterInstance = fixture.vRouterInstance;
    const vPairFactoryInstance = fixture.vPairFactoryInstance;

    const ikPair = await vPairFactoryInstance.getPair(
      tokenD.address,
      tokenB.address
    );

    const jkPair = await vPairFactoryInstance.getPair(
      tokenB.address,
      tokenA.address
    );

    let amountOut = ethers.utils.parseEther("40");

    const amountIn = await vRouterInstance.getVirtualAmountIn(
      jkPair,
      ikPair,
      amountOut
    );

    const futureTs = await utils.getFutureBlockTimestamp();

    let reverted = false;
    try {
      await vRouterInstance.swap(
        [jkPair],
        [amountIn],
        [amountOut],
        [ikPair],
        tokenD.address,
        tokenA.address,
        owner.address,
        futureTs
      );
    } catch {
      reverted = true;
    }

    expect(reverted, "EXPECTED SWAP TO REVERT");
  });

  it("Withdrawal from pool A/B and check reserves and reserveRatio", async () => {
    const abPool = fixture.abPool;
    const bcPool = fixture.bcPool;
    const tokenA = fixture.tokenA;
    const tokenB = fixture.tokenB;
    const tokenC = fixture.tokenC;
    const owner = fixture.owner;
    const vRouterInstance = fixture.vRouterInstance;
    const vPairFactoryInstance = fixture.vPairFactoryInstance;

    const poolAddress = await vPairFactoryInstance.getPair(
      tokenB.address,
      tokenA.address
    );

    let balance = await abPool.balanceOf(owner.address);

    //get 30% of balance out
    let balanceOut = balance.div(3);

    await abPool.approve(vRouterInstance.address, balanceOut);

    let reserves = await abPool.getBalances();

    let amountADesired = reserves._balance0.mul(290).div(1000);
    let amountBDesired = reserves._balance1.mul(290).div(1000);

    let amountCInBalance = await tokenC.balanceOf(abPool.address);
    let amountCInReserve = await abPool.reserves(tokenC.address);
    let amountCInReserveBaseValue = await abPool.reservesBaseValue(
      tokenC.address
    );

    const futureTs = await utils.getFutureBlockTimestamp();
    await vRouterInstance.removeLiquidity(
      tokenA.address,
      tokenB.address,
      balanceOut,
      amountADesired,
      amountBDesired,
      owner.address,
      futureTs
    );

    let amountCInBalanceAfter = await tokenC.balanceOf(abPool.address);
    let amountCInReserveAfter = await abPool.reserves(tokenC.address);
    let amountCInReserveBaseValueAfter = await abPool.reservesBaseValue(
      tokenC.address
    );
  });
});
