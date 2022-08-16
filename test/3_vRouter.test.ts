import { loadFixture } from "@nomicfoundation/hardhat-network-helpers";
import { expect } from "chai";
import { ethers } from "hardhat";
import { deployPools } from "../fixtures/deployPools";
import { time } from "@nomicfoundation/hardhat-network-helpers";

import {
  IERC20Metadata__factory,
  VPair__factory,
  VRouter__factory,
} from "../typechain-types/index";
import _ from "lodash";
import utils from "./utils";

describe("vRouter", () => {
  let fixture: any = {};

  async function getFutureBlockTimestamp() {
    return (await time.latest()) + 1000000;
  }

  before(async function () {
    fixture = await loadFixture(deployPools);
  });

  it("Should quote A to B", async () => {
    const abPool = fixture.abPool;
    const tokenA = fixture.tokenA;
    const tokenB = fixture.tokenB;
    const vRouterInstance = fixture.vRouterInstance;

    let input = ethers.utils.parseEther("14");

    let quote = await vRouterInstance.quote(
      tokenA.address,
      tokenB.address,
      input
    );

    const token0 = await abPool.token0();

    const reserves = await abPool.getReserves();

    let tokenAReserve = 0;
    let tokenBReserve = 0;

    if (token0 == tokenA.address) {
      tokenAReserve = reserves._reserve0;
      tokenBReserve = reserves._reserve1;
    } else {
      tokenAReserve = reserves._reserve1;
      tokenBReserve = reserves._reserve0;
    }

    tokenAReserve = parseFloat(ethers.utils.formatEther(tokenAReserve));
    tokenBReserve = parseFloat(ethers.utils.formatEther(tokenBReserve));

    const ratio = tokenAReserve / tokenBReserve;

    quote = parseFloat(ethers.utils.formatEther(quote));

    expect(quote * ratio).to.equal(parseFloat(ethers.utils.formatEther(input)));
    expect(quote).to.equal(42);
  });

  it("Should (amountIn(amountOut(x)) = x)", async () => {
    const tokenA = fixture.tokenA;
    const tokenB = fixture.tokenB;
    const vRouterInstance = fixture.vRouterInstance;

    let X = ethers.utils.parseEther("395");

    const amountIn = await vRouterInstance.getAmountIn(
      tokenA.address,
      tokenB.address,
      X
    );

    const amountOut = await vRouterInstance.getAmountOut(
      tokenA.address,
      tokenB.address,
      amountIn
    );

    const amountOutEth = parseFloat(ethers.utils.formatEther(amountOut));
    expect(amountOutEth).to.equal(395);
  });

  it("Should calculate virtual pool A/C using B/C as oracle", async () => {
    const abPool = fixture.abPool;
    const bcPool = fixture.bcPool;

    const tokenA = fixture.tokenA;
    const tokenC = fixture.tokenC;
    const vRouterInstance = fixture.vRouterInstance;

    const vPool = await vRouterInstance.getVirtualPool(
      bcPool.address,
      abPool.address
    );

    expect(
      vPool.reserve0 / vPool.reserve1 == fixture.A_PRICE / fixture.C_PRICE
    );
    expect(vPool.token0 == tokenA.address && vPool.token1 == tokenC.address);
  });

  it("Should calculate virtual pool B/C using A/B as oracle", async () => {
    const abPool = fixture.abPool;
    const acPool = fixture.acPool;
    const tokenB = fixture.tokenB;
    const tokenC = fixture.tokenC;
    const vRouterInstance = fixture.vRouterInstance;

    const vPool = await vRouterInstance.getVirtualPool(
      acPool.address,
      abPool.address
    );

    expect(
      vPool.reserve0 / vPool.reserve1 == fixture.B_PRICE / fixture.C_PRICE
    );
    expect(vPool.token0 == tokenB.address && vPool.token1 == tokenC.address);
  });

  it("Should calculate virtual pool A/B using B/C as oracle", async () => {
    const abPool = fixture.abPool;
    const bcPool = fixture.bcPool;
    const tokenA = fixture.tokenA;
    const tokenB = fixture.tokenB;
    const vRouterInstance = fixture.vRouterInstance;

    const vPool = await vRouterInstance.getVirtualPool(
      bcPool.address,
      abPool.address
    );

    expect(
      vPool.reserve0 / vPool.reserve1 == fixture.A_PRICE / fixture.B_PRICE
    );
    expect(vPool.token0 == tokenA.address && vPool.token1 == tokenB.address);
  });

  it("Should calculate virtual pool B/A using B/C as oracle", async () => {
    const tokenA = fixture.tokenA;
    const acPool = fixture.acPool;
    const bcPool = fixture.bcPool;
    const tokenB = fixture.tokenB;
    const vRouterInstance = fixture.vRouterInstance;

    const vPool = await vRouterInstance.getVirtualPool(
      acPool.address,
      bcPool.address
    );

    expect(
      vPool.reserve0 / vPool.reserve1 == fixture.B_PRICE / fixture.A_PRICE
    );
    expect(vPool.token0 == tokenB.address && vPool.token1 == tokenA.address);
  });

  it("Should getVirtualAmountIn for buying 10 B in virtual pool A/B", async () => {
    const vRouterInstance = fixture.vRouterInstance;

    const amountOut = ethers.utils.parseEther("10");

    const amountIn = await vRouterInstance.getVirtualAmountIn(
      fixture.bcPool.address,
      fixture.acPool.address,
      amountOut
    );

    expect(
      parseFloat(parseFloat(ethers.utils.formatEther(amountIn)).toFixed(3))
    ).to.equal(3.344);
  });

  it("Should getVirtualAmountOut", async () => {
    const vRouterInstance = fixture.vRouterInstance;

    const amountIn = ethers.utils.parseEther("10");

    const amountOut = await vRouterInstance.getVirtualAmountOut(
      fixture.bcPool.address,
      fixture.abPool.address,
      amountIn
    );
    expect(amountOut > 0);
  });

  it("Should getVirtualAmountIn(getVirtualAmountOut(x)) = x", async () => {
    const vRouterInstance = fixture.vRouterInstance;

    const _amountOut = ethers.utils.parseEther("10");

    const amountIn = await vRouterInstance.getVirtualAmountIn(
      fixture.bcPool.address,
      fixture.abPool.address,
      _amountOut
    );

    const amountOut = await vRouterInstance.getVirtualAmountOut(
      fixture.bcPool.address,
      fixture.abPool.address,
      amountIn
    );

    expect(_amountOut == amountOut);
  });

  it("Should swap C to A on pool A/C", async () => {
    const tokenA = fixture.tokenA;
    const tokenC = fixture.tokenC;
    const owner = fixture.owner;

    const vRouterInstance = fixture.vRouterInstance;

    const tokenABalanceBefore = await tokenA.balanceOf(owner.address);
    const tokenCBalanceBefore = await tokenC.balanceOf(owner.address);

    const amountOut = ethers.utils.parseEther("10");

    let amountIn = await vRouterInstance.getAmountIn(
      tokenC.address,
      tokenA.address,
      amountOut
    );
    const futureTs = await getFutureBlockTimestamp();

    let data = utils.getEncodedSwapData(
      owner.address,
      tokenC.address,
      tokenA.address,
      tokenC.address,
      amountIn
    );
    await vRouterInstance.swapToExactNative(
      tokenC.address,
      tokenA.address,
      amountOut,
      owner.address,
      data,
      futureTs
    );
    const tokenABalanceAfter = await tokenA.balanceOf(owner.address);
    const tokenCBalanceAfter = await tokenC.balanceOf(owner.address);
    expect(tokenCBalanceAfter).to.be.lessThan(tokenCBalanceBefore);

    expect(tokenABalanceAfter).to.above(tokenABalanceBefore);
  });

  it("Should swap A to C on pool A/C", async () => {
    const tokenA = fixture.tokenA;
    const tokenC = fixture.tokenC;
    const owner = fixture.owner;

    const vRouterInstance = fixture.vRouterInstance;

    const tokenABalanceBefore = await tokenA.balanceOf(owner.address);
    const tokenCBalanceBefore = await tokenC.balanceOf(owner.address);

    const amountIn = ethers.utils.parseEther("10");

    const amountOut = await vRouterInstance.getAmountOut(
      tokenA.address,
      tokenC.address,
      amountIn
    );
    let data = utils.getEncodedSwapData(
      owner.address,
      tokenA.address,
      tokenA.address,
      tokenC.address,
      amountIn
    );
    const futureTs = await getFutureBlockTimestamp();

    let multiData = [];

    let str = await VRouter__factory.getInterface(
      VRouter__factory.abi
    ).encodeFunctionData("swapToExactNative", [
      tokenA.address,
      tokenC.address,
      amountOut,
      owner.address,
      data,
      futureTs,
    ]);

    multiData.push(str);

    await vRouterInstance.multicall(multiData, false);
    const tokenABalanceAfter = await tokenA.balanceOf(owner.address);
    const tokenCBalanceAfter = await tokenC.balanceOf(owner.address);
    expect(tokenCBalanceAfter).to.be.above(tokenCBalanceBefore);

    expect(tokenABalanceAfter).to.lessThan(tokenABalanceBefore);
  });

  let amountInTokenC: any;

  it("Should swap C to A on pool A/B", async () => {
    const tokenA = fixture.tokenA;
    const tokenB = fixture.tokenB;
    const tokenC = fixture.tokenC;
    const owner = fixture.owner;
    const bcPool = fixture.bcPool;

    const vRouterInstance = fixture.vRouterInstance;

    const amountOut = ethers.utils.parseEther("100");

    let amountIn = await vRouterInstance.getVirtualAmountIn(
      fixture.abPool.address,
      fixture.bcPool.address,
      amountOut
    );

    amountInTokenC = amountIn;

    let data = utils.getEncodedSwapData(
      owner.address,
      tokenC.address,
      tokenB.address,
      tokenA.address,
      amountIn
    );

    const futureTs = await getFutureBlockTimestamp();

    await vRouterInstance.swapReserveToExactNative(
      tokenA.address,
      tokenB.address,
      bcPool.address,
      amountOut,
      owner.address,
      data,
      futureTs
    );
  });

  it("Should swap A to C on pool B/C", async () => {
    const abPool = fixture.abPool;
    const bcPool = fixture.bcPool;

    const tokenA = fixture.tokenA;
    const tokenB = fixture.tokenB;
    const owner = fixture.owner;

    const tokenC = fixture.tokenC;
    const vRouterInstance = fixture.vRouterInstance;

    let amountIn = await vRouterInstance.getVirtualAmountIn(
      bcPool.address,
      abPool.address,
      amountInTokenC
    );

    let data = utils.getEncodedSwapData(
      owner.address,
      tokenA.address,
      tokenB.address,
      tokenC.address,
      amountIn
    );

    const futureTs = await getFutureBlockTimestamp();
    await vRouterInstance.swapReserveToExactNative(
      tokenB.address,
      tokenC.address,
      abPool.address,
      amountInTokenC,
      owner.address,
      data,
      futureTs
    );
  });

  it("Should Total Pool swap -> 1. C to A on pool A/C   2. C to A on pool A/B", async () => {
    const tokenA = fixture.tokenA;
    const tokenB = fixture.tokenB;
    const tokenC = fixture.tokenC;
    const abPool = fixture.abPool;
    const owner = fixture.owner;

    const bcPool = fixture.bcPool;
    const vRouterInstance = fixture.vRouterInstance;

    const _amountOut = ethers.utils.parseEther("10");

    let realAmountIn = await vRouterInstance.getAmountIn(
      tokenC.address,
      tokenA.address,
      _amountOut
    );

    let virtualIn = await vRouterInstance.getVirtualAmountIn(
      abPool.address,
      bcPool.address,
      _amountOut
    );

    let data = utils.getEncodedSwapData(
      owner.address,
      tokenC.address,
      tokenA.address,
      tokenC.address,
      realAmountIn
    );

    const futureTs = await getFutureBlockTimestamp();
    let multiData = [];

    let str = await VRouter__factory.getInterface(
      VRouter__factory.abi
    ).encodeFunctionData("swapToExactNative", [
      tokenC.address,
      tokenA.address,
      _amountOut,
      owner.address,
      data,
      futureTs,
    ]);

    multiData.push(str);

    let data2 = utils.getEncodedSwapData(
      owner.address,
      tokenC.address,
      tokenA.address,
      tokenB.address,
      virtualIn
    );

    str = await VRouter__factory.getInterface(
      VRouter__factory.abi
    ).encodeFunctionData("swapReserveToExactNative", [
      tokenA.address,
      tokenB.address,
      bcPool.address,
      _amountOut,
      owner.address,
      data2,
      futureTs,
    ]);

    multiData.push(str);

    await vRouterInstance.multicall(multiData, false);
  });

  it("Should revert on swap A to C on pool A/C with insuficient input amount", async () => {
    const tokenA = fixture.tokenA;
    const tokenC = fixture.tokenC;
    const owner = fixture.owner;

    const vRouterInstance = fixture.vRouterInstance;

    let pools = [fixture.acPool.address];
    let amountsIn = ethers.utils.parseEther("10");

    const amountOut = await vRouterInstance.getAmountOut(
      tokenA.address,
      tokenC.address,
      amountsIn
    );

    amountsIn = ethers.utils.parseEther("8");

    const futureTs = await getFutureBlockTimestamp();
    let reverted = false;
    try {
      await vRouterInstance.swap(
        pools,
        [amountsIn],
        [amountOut],
        ["0x0000000000000000000000000000000000000000"],
        tokenA.address,
        tokenC.address,
        owner.address,
        futureTs
      );
    } catch {
      reverted = true;
    }

    expect(reverted);
  });

  it("Should remove 1/4 liquidity", async () => {
    const abPool = fixture.abPool;
    const tokenA = fixture.tokenA;
    const tokenB = fixture.tokenB;
    const owner = fixture.owner;

    const vRouterInstance = fixture.vRouterInstance;

    let lpBalanceBefore = await abPool.balanceOf(owner.address);

    let reserve0 = await abPool.reserve0();
    let reserve1 = await abPool.reserve1();
    reserve0 = reserve0;
    reserve1 = reserve1;

    const withdrawAmount = lpBalanceBefore.div(4);

    await abPool.approve(vRouterInstance.address, lpBalanceBefore);
    //get account0 balance before
    let tokenABalanceBefore = await tokenA.balanceOf(owner.address);
    let tokenBBalanceBefore = await tokenB.balanceOf(owner.address);
    const tokenAMin = reserve0.mul(999).div(1000).div(4);
    const tokenBMin = reserve1.mul(999).div(1000).div(4);

    const futureTs = await getFutureBlockTimestamp();
    await vRouterInstance.removeLiquidity(
      tokenA.address,
      tokenB.address,
      withdrawAmount,
      tokenAMin,
      tokenBMin,
      owner.address,
      futureTs
    );
    //get account0 balance before
    let tokenABalanceAfter = await tokenA.balanceOf(owner.address);
    let tokenBBalanceAfter = await tokenB.balanceOf(owner.address);

    let reserve0After = await abPool.reserve0();
    let reserve1After = await abPool.reserve1();

    reserve0After = reserve0After;
    reserve1After = reserve1After;

    expect(tokenABalanceAfter).to.be.above(tokenABalanceBefore);
    expect(tokenBBalanceAfter).to.be.above(tokenBBalanceBefore);
  });

  it("Should add liquidity", async () => {
    const tokenA = fixture.tokenA;
    const tokenB = fixture.tokenB;
    const abPool = fixture.abPool;
    const owner = fixture.owner;

    const vRouterInstance = fixture.vRouterInstance;

    let amountADesired = ethers.utils.parseEther("1");

    const amountBDesired = await vRouterInstance.quote(
      tokenA.address,
      tokenB.address,
      amountADesired
    );

    let reserve0 = await abPool.reserve0();
    let reserve1 = await abPool.reserve1();

    let totalBalanceBefore0 = reserve0;
    let totalBalanceBefore1 = reserve1;

    const futureTs = await getFutureBlockTimestamp();

    await vRouterInstance.addLiquidity(
      tokenA.address,
      tokenB.address,
      amountADesired,
      amountBDesired,
      amountADesired,
      amountBDesired,
      owner.address,
      futureTs
    );

    lpBalance = await abPool.balanceOf(owner.address);

    reserve0 = await abPool.reserve0();
    reserve1 = await abPool.reserve1();

    let totalBalanceAfter0 = reserve0;
    let totalBalanceAfter1 = reserve1;

    expect(Number(totalBalanceBefore0.toString())).to.lessThan(
      Number(totalBalanceAfter0.toString())
    );

    expect(Number(totalBalanceBefore1.toString())).to.lessThan(
      Number(totalBalanceAfter1.toString())
    );
  });

  it("Should revert when trying to provide unbalanced A amount", async function () {
    const tokenA = fixture.tokenA;
    const owner = fixture.owner;

    const tokenB = fixture.tokenB;
    const vRouterInstance = fixture.vRouterInstance;

    const amountADesired = ethers.utils.parseEther("12");

    const amountBDesired = ethers.utils.parseEther("8");
    const futureTs = await getFutureBlockTimestamp();
    expect(
      vRouterInstance.addLiquidity(
        tokenA.address,
        tokenB.address,
        amountADesired,
        amountBDesired,
        amountADesired,
        amountBDesired,
        owner.address,
        futureTs
      )
    ).to.revertedWithoutReason();
  });

  it("Should revert when trying to provide unbalanced B amount", async function () {
    const owner = fixture.owner;

    const tokenA = fixture.tokenA;
    const tokenB = fixture.tokenB;
    const vRouterInstance = fixture.vRouterInstance;

    const amountADesired = ethers.utils.parseEther("1");

    const amountBDesired = ethers.utils.parseEther("4");

    const futureTs = await getFutureBlockTimestamp();
    expect(
      vRouterInstance.addLiquidity(
        tokenA.address,
        tokenB.address,
        amountADesired,
        amountBDesired,
        amountADesired,
        amountBDesired,
        owner.address,
        futureTs
      )
    ).to.revertedWithoutReason();
  });

  it("Should remove all pool liquidity", async () => {
    const owner = fixture.owner;

    const abPool = fixture.abPool;
    const tokenA = fixture.tokenA;
    const tokenB = fixture.tokenB;
    const tokenC = fixture.tokenC;
    const vRouterInstance = fixture.vRouterInstance;

    let lpBalance = await abPool.balanceOf(owner.address);

    let tokenABalanceBefore = await tokenA.balanceOf(owner.address);
    let tokenBBalanceBefore = await tokenB.balanceOf(owner.address);

    let token0 = await abPool.token0();
    let token1 = await abPool.token1();
    let amountADesired = await abPool.reserve0();

    let amountBDesired = await vRouterInstance.quote(
      token0,
      token1,
      amountADesired
    );

    amountADesired = amountADesired.mul(999).div(1000);
    amountBDesired = amountBDesired.mul(999).div(1000);

    const cResrveRatio = await abPool.reservesBaseValue(tokenC.address);
    const userTokenCBalance = await tokenC.balanceOf(owner.address);

    let reserve0 = await abPool.reserve0();
    let reserve1 = await abPool.reserve1();

    await abPool.approve(vRouterInstance.address, lpBalance);

    const futureTs = await getFutureBlockTimestamp();
    await vRouterInstance.removeLiquidity(
      tokenA.address,
      tokenB.address,
      lpBalance,
      amountADesired,
      amountBDesired,
      owner.address,
      futureTs
    );

    const cResrveRatioAfter = await abPool.reservesBaseValue(tokenC.address);

    let lpBalanceAfter = await abPool.balanceOf(owner.address);
    lpBalanceAfter = lpBalanceAfter;

    let tokenABalanceAfter = await tokenA.balanceOf(owner.address);
    let tokenBBalanceAfter = await tokenB.balanceOf(owner.address);

    tokenABalanceAfter = tokenABalanceAfter;
    tokenBBalanceAfter = tokenBBalanceAfter;

    let reserve0After = await abPool.reserve0();
    let reserve1After = await abPool.reserve1();

    const userTokenCBalanceAfter = await tokenC.balanceOf(owner.address);

    expect(lpBalanceAfter).to.equal(0);
    expect(tokenABalanceBefore).to.lessThan(tokenABalanceAfter);
    expect(tokenBBalanceBefore).to.lessThan(tokenBBalanceAfter);

    expect(reserve0After).to.lessThan(reserve0);
    expect(reserve1After).to.lessThan(reserve1);

    expect(userTokenCBalance).to.lessThan(userTokenCBalanceAfter);

    // check C reserve was updated in pool
    expect(cResrveRatioAfter).to.lessThan(cResrveRatio);
  });

  it("Should re-add liquidity", async () => {
    const abPool = fixture.abPool;
    const tokenA = fixture.tokenA;
    const tokenB = fixture.tokenB;
    const owner = fixture.owner;

    const vRouterInstance = fixture.vRouterInstance;

    let reserve0 = await abPool.reserve0();
    let reserve1 = await abPool.reserve1();

    const amountADesired = ethers.utils.parseEther("100");

    const amountBDesired = await vRouterInstance.quote(
      tokenA.address,
      tokenB.address,
      amountADesired
    );

    const futureTs = await getFutureBlockTimestamp();

    await vRouterInstance.addLiquidity(
      tokenA.address,
      tokenB.address,
      amountADesired,
      amountBDesired,
      amountADesired,
      amountBDesired,
      owner.address,
      futureTs
    );

    let reserve0After = await abPool.reserve0();
    let reserve1After = await abPool.reserve1();

    let reserve0Eth, reserve1Eth, reserve0AfterEth, reserve1AfterEth;

    reserve0Eth = reserve0;
    reserve1Eth = reserve1;
    reserve0AfterEth = reserve0After;
    reserve1AfterEth = reserve1After;

    expect(reserve0Eth).to.lessThan(reserve0AfterEth);
    expect(reserve1Eth).to.lessThan(reserve1AfterEth);
  });

  it("Should change factory", async () => {
    const tokenA = fixture.tokenA;
    const vRouterInstance = fixture.vRouterInstance;

    const currentFactory = await vRouterInstance.factory();
    await vRouterInstance.changeFactory(tokenA.address);
    const newFactory = await vRouterInstance.factory();

    expect(currentFactory != tokenA.address && newFactory == tokenA.address);
  });
});
