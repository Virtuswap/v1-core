const { solidity } = require("ethereum-waffle");
const chai = require("chai");
const vPair = artifacts.require("vPair");
const vRouter = artifacts.require("vRouter");
const vSwapMath = artifacts.require("vSwapMath");
const vPairFactory = artifacts.require("vPairFactory");
const ERC20 = artifacts.require("ERC20PresetFixedSupply");
const { toDecimalUnits, toBn } = require("./utils");

chai.use(solidity);
const { expect } = chai;

const ZERO_ADDRESS = "0x0000000000000000000000000000000000000000";

contract("vRouter", (accounts) => {
  let tokenA, tokenB, tokenC, WETH;
  let vRouterInstance, vPairInstance, vPairFactoryInstance, vSwapMathInstance;
  const wallet = accounts[0];
  beforeEach(async () => {
    tokenA = await ERC20.new(
      "tokenA",
      "A",
      toDecimalUnits(18, 1000000),
      wallet
    );
    tokenB = await ERC20.new(
      "tokenB",
      "B",
      toDecimalUnits(18, 1000000),
      wallet
    );
    tokenC = await ERC20.new(
      "tokenC",
      "C",
      toDecimalUnits(18, 1000000),
      wallet
    );
    WETH = await ERC20.new("WETH", "WETH", toDecimalUnits(18, 1000000), wallet);
    tokenA.approve(wallet, toDecimalUnits(18, 1000000));
    tokenB.approve(wallet, toDecimalUnits(18, 1000000));
    tokenC.approve(wallet, toDecimalUnits(18, 1000000));
    WETH.approve(wallet, toDecimalUnits(18, 1000000));
    vPairFactoryInstance = await vPairFactory.deployed();
    vRouterInstance = await vRouter.deployed();
    vSwapMathInstance = await vSwapMath.deployed();

    await vPairFactoryInstance.createPair(tokenA.address, tokenB.address);
    await vPairFactoryInstance.createPair(tokenA.address, tokenC.address);
    await vPairFactoryInstance.createPair(tokenB.address, tokenC.address);

    await tokenA.approve(vRouterInstance.address, toDecimalUnits(18, 100000));
    await tokenB.approve(vRouterInstance.address, toDecimalUnits(18, 100000));
    await tokenC.approve(vRouterInstance.address, toDecimalUnits(18, 100000));

    await vRouterInstance.addLiquidity(
      tokenA.address,
      tokenB.address,
      toDecimalUnits(18, 10),
      toDecimalUnits(18, 100),
      toDecimalUnits(18, 10),
      toDecimalUnits(18, 100),
      wallet,
      new Date().getTime() + 1000 * 60 * 60
    );
    await vRouterInstance.addLiquidity(
      tokenA.address,
      tokenC.address,
      toDecimalUnits(18, 10000),
      toDecimalUnits(18, 100),
      toDecimalUnits(18, 10000),
      toDecimalUnits(18, 100),
      wallet,
      new Date().getTime() + 1000 * 60 * 60
    );
    await vRouterInstance.addLiquidity(
      tokenB.address,
      tokenC.address,
      toDecimalUnits(18, 10000),
      toDecimalUnits(18, 10),
      toDecimalUnits(18, 10000),
      toDecimalUnits(18, 10),
      wallet,
      new Date().getTime() + 1000 * 60 * 60
    );
  });

  //   it("adds Liquidity", async () => {
  //     if (
  //       (await vPairFactoryInstance.getPair(tokenA.address, tokenB.address)) ===
  //       ZERO_ADDRESS
  //     ) {
  //       await vPairFactoryInstance.createPair(tokenA.address, tokenB.address);
  //     }

  //     let amountADesired = toDecimalUnits(18, 1);
  //     let amountBDesired = toDecimalUnits(18, 10);
  //     const pool = await vPair.at(
  //       await vPairFactoryInstance.getPair(tokenA.address, tokenB.address)
  //     );

  //     let balanceBefore = await pool.balanceOf(wallet);
  //     await vRouterInstance.addLiquidity(
  //       tokenA.address,
  //       tokenB.address,
  //       amountADesired,
  //       amountBDesired,
  //       1,
  //       1,
  //       wallet,
  //       new Date().getTime() + 1000 * 60 * 60
  //     );
  //     let balanceAfter = await pool.balanceOf(wallet);
  //     //basic check
  //     expect(Number(balanceBefore.toString())).to.lessThan(
  //       Number(balanceAfter.toString())
  //     );
  //   });

  // LOGICAL ISSUE
  // it("removes Liquidity", async () => {
  //   // wip

  //   const wallet = accounts[3];

  //   let amountADesired = toBn(18, 1);
  //   let amountBDesired = toBn(18, 10);

  //   console.log(1);
  //   const pool = await vPair.at(
  //     await vPairFactoryInstance.getPair(tokenA.address, tokenB.address)
  //   );
  //   console.log(2);

  //   const liquidityBefore = await pool.balanceOf(wallet);
  //   console.log("liquidityBefore >>>>>>>>>>>>>>>>>>>>>>", liquidityBefore.toNumber());

  //   let balanceBefore = await pool.balanceOf(wallet);
  //   await vRouterInstance.addLiquidity(
  //     tokenA.address,
  //     tokenB.address,
  //     amountADesired,
  //     amountBDesired,
  //     10,
  //     10,
  //     wallet,
  //     new Date().getTime() + 1000 * 60 * 60
  //   );

  //   const liquidityAfter = await pool.balanceOf(wallet);
  //   console.log("liquidityAfter >>>>>>>>>>>>>>>>>>>>>>", liquidityAfter.toString());
  //   console.log("POol liquidity",  await pool.balanceOf(pool.address))
  //   console.log(3);
  //   let balanceAfter = await pool.balanceOf(wallet);
  //   await pool.approve(vRouterInstance.address, toDecimalUnits(18, 100000));

  //   await vRouterInstance.removeLiquidity(
  //     tokenA.address,
  //     tokenB.address,
  //     1,
  //     1,
  //     balanceAfter.sub(balanceBefore),
  //     wallet,
  //     new Date().getTime() + 1000 * 60 * 60
  //   );

  //   // // balance should be equal to initial balance
  //   // expect(balanceBefore.toString()).to.equal((await pool.balanceOf(wallet)).toString())
  // });

  it("Should swaps A for B in pool A/B without IKS", async () => {
    const vPairFactoryInstance = await vPairFactory.deployed();
    if (
      (await vPairFactoryInstance.getPair(tokenA.address, tokenB.address)) ===
      ZERO_ADDRESS
    ) {
      await vPairFactoryInstance.createPair(tokenA.address, tokenB.address);
    }

    const vRouterInstance = await vRouter.deployed(
      vPairFactoryInstance.address,
      WETH
    );

    const pool = await vPairFactoryInstance.getPair(
      tokenA.address,
      tokenB.address
    );

    let amountIn = 100000;
    let amountOut = 100000;
    const zeroAddress = "0x0000000000000000000000000000000000000000";
    
    const BalanceABefore = (await tokenA.balanceOf(wallet)).toString();
    const BalanceAPoolBefore = (await tokenA.balanceOf(pool)).toString();
    const BalanceBBefore = (await tokenB.balanceOf(wallet)).toString();
    const BalanceBPoolBefore = (await tokenB.balanceOf(pool)).toString();

    await vRouterInstance.swap(
      [pool],
      [amountIn],
      [amountOut],
      [zeroAddress],
      tokenA.address,
      tokenB.address,
      wallet,
      new Date().getTime() + 1000 * 60 * 60
    );
    const BalanceAAfter = (await tokenA.balanceOf(wallet)).sub(toBn(1, 10000)).toString();
    const BalanceAPoolAfter = (await tokenA.balanceOf(pool)).add(toBn(1, 10000)).toString();
    const BalanceBAfter = (await tokenB.balanceOf(wallet)).sub(toBn(1, 10000)).toString();
    const BalanceBPoolAfter = (await tokenB.balanceOf(pool)).add(toBn(1, 10000)).toString();

    console.log(BalanceABefore, BalanceAAfter);
    console.log(BalanceAPoolBefore, BalanceAPoolAfter);
    console.log(BalanceBBefore, BalanceBAfter);
    console.log(BalanceBPoolBefore, BalanceBPoolAfter);

      expect(BalanceABefore).to.equal(BalanceAAfter);
      expect(BalanceAPoolBefore).to.equal(BalanceAPoolAfter);
      expect(BalanceBBefore).to.equal(BalanceBAfter);
      expect(BalanceBPoolBefore).to.equal(BalanceBPoolAfter);
  });

  // it("Swaps A for B in pool A/B with IKS", async () => {
  //   // WIP
  //   const vPairFactoryInstance = await vPairFactory.deployed();
  //   if (
  //     (await vPairFactoryInstance.getPair(tokenA.address, tokenB.address)) ===
  //     ZERO_ADDRESS
  //   ) {
  //     await vPairFactoryInstance.createPair(tokenA.address, tokenB.address);
  //   }

  //   const vRouterInstance = await vRouter.deployed(
  //     vPairFactoryInstance.address,
  //     WETH
  //   );
  //   // wip
  //   const pool = await vPairFactoryInstance.getPair(
  //     tokenA.address,
  //     tokenB.address
  //   );
  //   let amountIn = 100000;
  //   let amountOut = 100000;
  //   const zeroAddress = "0x0000000000000000000000000000000000000000";

  //   console.log(pool);
  //   console.log("Balance A", (await tokenA.balanceOf(wallet)).toString());
  //   console.log("Balance A Pool", (await tokenA.balanceOf(pool)).toString());
  //   console.log("Balance B", (await tokenB.balanceOf(wallet)).toString());
  //   console.log("Balance B Pool", (await tokenB.balanceOf(pool)).toString());
  //   await vRouterInstance.swap(
  //     [pool],
  //     [amountIn],
  //     [amountOut],
  //     [zeroAddress],
  //     tokenA.address,
  //     tokenB.address,
  //     wallet,
  //     new Date().getTime() + 1000 * 60 * 60
  //   );
  //   console.log("Balance A", (await tokenA.balanceOf(wallet)).toString());
  //   console.log("Balance A Pool", (await tokenA.balanceOf(pool)).toString());
  //   console.log("Balance B", (await tokenB.balanceOf(wallet)).toString());
  //   console.log("Balance B Pool", (await tokenB.balanceOf(pool)).toString());
  // });

  //   it("Swaps C for B in pool A/B, Swaps B for A in pool A/C then exchanges", async () => {
  //     const vPairFactoryInstance = await vPairFactory.deployed();

  //     const wallet = accounts[3];

  //     if (
  //       (await vPairFactoryInstance.getPair(tokenA.address, tokenB.address)) ===
  //       ZERO_ADDRESS
  //     ) {
  //       await vPairFactoryInstance.createPair(tokenA.address, tokenB.address);
  //     }
  //     if (
  //       (await vPairFactoryInstance.getPair(tokenA.address, tokenC.address)) ===
  //       ZERO_ADDRESS
  //     ) {
  //       await vPairFactoryInstance.createPair(tokenA.address, tokenC.address);
  //     }

  //     const vRouterInstance = await vRouter.deployed(
  //       vPairFactoryInstance.address,
  //       WETH
  //     );
  //     const pool = await vPairFactoryInstance.getPair(
  //       tokenA.address,
  //       tokenB.address
  //     );
  //     // wip
  //   });
});
