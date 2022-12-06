import { loadFixture } from "@nomicfoundation/hardhat-network-helpers";
import { expect } from "chai";
import { ethers } from "hardhat";
import { sameValues } from "./fixtures/sameValues";
import _ from "lodash";
import utils from "./utils";

describe("Reserve Ratio calculation", () => {
  let fixture: any = {};

  before(async () => {
    fixture = await loadFixture(sameValues);
    await fixture.vPairFactoryInstance.setExchangeReservesAddress(
      fixture.exchangeReserveInstance.address
    );
  });

  it("Exchange 500000 C to B in pool AB", async () => {
    const abPool = fixture.abPool;
    const tokenA = fixture.tokenA;
    const owner = fixture.owner;
    const tokenB = fixture.tokenB;
    const tokenC = fixture.tokenC;
    const vPairFactoryInstance = fixture.vPairFactoryInstance;
    const vRouterInstance = fixture.vRouterInstance;

    let amountCIn = ethers.utils.parseEther("500000");
    const ikPair = await vPairFactoryInstance.getPair(
      tokenA.address,
      tokenC.address
    );

    const jkPair = await vPairFactoryInstance.getPair(
      tokenA.address,
      tokenB.address
    );

    let amountBOut = await vRouterInstance.getVirtualAmountOut(
      jkPair,
      ikPair,
      amountCIn
    );

    let ABRRBefore = (await abPool.calculateReserveRatio()).toString();
    console.log(`Reserve ratio of AB pool before = ${ABRRBefore}`);

    await tokenC.transfer(abPool.address, amountCIn);

    await abPool.swapReserveToNative(amountBOut, ikPair, owner.address, []);

    let ABRRAfter = (await abPool.calculateReserveRatio()).toString();
    console.log(`Reserve ratio of AB pool after = ${ABRRAfter}`);

    expect(ABRRAfter).to.equal("5");

    console.log(`Exchanged ${amountCIn} of C for ${amountBOut} of B`);
    console.log(
      `Reserve base value of token C = ${(
        await abPool.reservesBaseValue(tokenC.address)
      ).toString()}`
    );
    console.log(
      `Reserve of token C = ${(
        await abPool.reserves(tokenC.address)
      ).toString()}`
    );
    console.log(`A balance = ${(await abPool.pairBalance0()).toString()}`);
    console.log(`B balance = ${(await abPool.pairBalance1()).toString()}`);
  });

  it("Exchange 500000 D to A in pool AB", async () => {
    const abPool = fixture.abPool;
    const tokenA = fixture.tokenA;
    const owner = fixture.owner;
    const tokenB = fixture.tokenB;
    const tokenD = fixture.tokenD;
    const vPairFactoryInstance = fixture.vPairFactoryInstance;
    const vRouterInstance = fixture.vRouterInstance;

    let amountDIn = ethers.utils.parseEther("500000");
    const ikPair = await vPairFactoryInstance.getPair(
      tokenB.address,
      tokenD.address
    );

    const jkPair = await vPairFactoryInstance.getPair(
      tokenA.address,
      tokenB.address
    );

    let amountAOut = await vRouterInstance.getVirtualAmountOut(
      jkPair,
      ikPair,
      amountDIn
    );

    let ABRRBefore = (await abPool.calculateReserveRatio()).toString();
    console.log(`Reserve ratio of AB pool before = ${ABRRBefore}`);

    await tokenD.transfer(abPool.address, amountDIn);

    await abPool.swapReserveToNative(amountAOut, ikPair, owner.address, []);

    let ABRRAfter = (await abPool.calculateReserveRatio()).toString();
    console.log(`Reserve ratio of AB pool after = ${ABRRAfter}`);

    expect(ABRRAfter).to.equal("10");

    console.log(`Exchanged ${amountDIn} of D for ${amountAOut} of A`);
    console.log(
      `Reserve base value of token D = ${(
        await abPool.reservesBaseValue(tokenD.address)
      ).toString()}`
    );
    console.log(`A balance = ${(await abPool.pairBalance0()).toString()}`);
    console.log(`B balance = ${(await abPool.pairBalance1()).toString()}`);
  });

  it("Exchange 300000 C to A in pool AB", async () => {
    const abPool = fixture.abPool;
    const tokenA = fixture.tokenA;
    const owner = fixture.owner;
    const tokenB = fixture.tokenB;
    const tokenC = fixture.tokenC;
    const tokenD = fixture.tokenD;
    const vPairFactoryInstance = fixture.vPairFactoryInstance;
    const vRouterInstance = fixture.vRouterInstance;

    let amountCIn = ethers.utils.parseEther("300000");
    const ikPair = await vPairFactoryInstance.getPair(
      tokenB.address,
      tokenC.address
    );

    const jkPair = await vPairFactoryInstance.getPair(
      tokenA.address,
      tokenB.address
    );

    let amountAOut = await vRouterInstance.getVirtualAmountOut(
      jkPair,
      ikPair,
      amountCIn
    );

    let ABRRBefore = (await abPool.calculateReserveRatio()).toString();
    console.log(`Reserve ratio of AB pool before = ${ABRRBefore}`);

    await tokenC.transfer(abPool.address, amountCIn);

    await abPool.swapReserveToNative(amountAOut, ikPair, owner.address, []);

    let ABRRAfter = (await abPool.calculateReserveRatio()).toString();
    console.log(`Reserve ratio of AB pool after = ${ABRRAfter}`);

    expect(ABRRAfter).to.equal("13");

    console.log(`Exchanged ${amountCIn} of C for ${amountAOut} of A`);
    console.log(
      `Reserve base value of token C = ${(
        await abPool.reservesBaseValue(tokenC.address)
      ).toString()}`
    );
    console.log(
      `Reserve base value of token D = ${(
        await abPool.reservesBaseValue(tokenD.address)
      ).toString()}`
    );
    console.log(`A balance = ${(await abPool.pairBalance0()).toString()}`);
    console.log(`B balance = ${(await abPool.pairBalance1()).toString()}`);
  });

  it("Exchange 1000000 A to D in pool BD", async () => {
    const bdPool = fixture.bdPool;
    const tokenA = fixture.tokenA;
    const owner = fixture.owner;
    const tokenB = fixture.tokenB;
    const tokenD = fixture.tokenD;
    const vPairFactoryInstance = fixture.vPairFactoryInstance;
    const vRouterInstance = fixture.vRouterInstance;

    let amountAIn = ethers.utils.parseEther("1000000");
    const ikPair = await vPairFactoryInstance.getPair(
      tokenA.address,
      tokenB.address
    );

    const jkPair = await vPairFactoryInstance.getPair(
      tokenB.address,
      tokenD.address
    );

    let amountDOut = await vRouterInstance.getVirtualAmountOut(
      jkPair,
      ikPair,
      amountAIn
    );

    await tokenA.transfer(bdPool.address, amountAIn);

    let BDRRBefore = (await bdPool.calculateReserveRatio()).toString();
    console.log(`Reserve ratio of BD pool before = ${BDRRBefore}`);

    await bdPool.swapReserveToNative(amountDOut, ikPair, owner.address, []);

    let BDRRAfter = (await bdPool.calculateReserveRatio()).toString();
    console.log(`Reserve ratio of BD pool after = ${BDRRAfter}`);

    expect(BDRRAfter).to.equal("10");

    console.log(
      `Reserve base value of token A = ${(
        await bdPool.reservesBaseValue(tokenA.address)
      ).toString()}`
    );
    console.log(`D balance = ${(await bdPool.pairBalance0()).toString()}`);
    console.log(`B balance = ${(await bdPool.pairBalance1()).toString()}`);
  });

  it("Exchange reserves between AB and BD pools (A<>D)", async () => {
    const abPool = fixture.abPool;
    const bdPool = fixture.bdPool;
    const tokenA = fixture.tokenA;
    const tokenC = fixture.tokenC;
    const tokenD = fixture.tokenD;

    let amountDInReserve = await abPool.reserves(tokenD.address);

    let data = utils.getEncodedExchangeReserveCallbackParams(
      abPool.address, //jk1
      bdPool.address, //jk2
      abPool.address //ik2
    );

    let BDRRBefore = await bdPool.calculateReserveRatio();
    console.log(`Reserve ratio of BD pool before = ${BDRRBefore.toString()}`);

    let ABRRBefore = await abPool.calculateReserveRatio();
    console.log(`Reserve ratio of AB pool before = ${ABRRBefore.toString()}`);

    let reservedAinBDBefore = await bdPool.reservesBaseValue(tokenA.address);

    await fixture.exchangeReserveInstance.exchange(
      abPool.address, //jk1
      bdPool.address, // ik1
      bdPool.address, //jk2
      amountDInReserve,
      data
    );

    let BDRRAfter = await bdPool.calculateReserveRatio();
    console.log(`Reserve ratio of BD pool after = ${BDRRAfter.toString()}`);

    let ABRRAfter = await abPool.calculateReserveRatio();
    console.log(`Reserve ratio of AB pool after = ${ABRRAfter.toString()}`);

    console.log(`D balance = ${(await bdPool.pairBalance0()).toString()}`);
    console.log(`B balance = ${(await bdPool.pairBalance1()).toString()}`);
    console.log(`A balance = ${(await abPool.pairBalance0()).toString()}`);
    console.log(`B balance = ${(await abPool.pairBalance1()).toString()}`);

    let reservedAinBDAfter = await bdPool.reservesBaseValue(tokenA.address);
    let reservedDinAB = await abPool.reservesBaseValue(tokenD.address);

    console.log(
      `Reserve base value of token A (BD) = ${reservedAinBDAfter.toString()}`
    );
    console.log(
      `Reserve base value of token D (AB) = ${reservedDinAB.toString()}`
    );
    console.log(
      `Reserve base value of token C (AB) = ${(
        await abPool.reservesBaseValue(tokenC.address)
      ).toString()}`
    );

    expect(BDRRAfter).to.lessThan(BDRRBefore);
    expect(ABRRAfter).to.lessThan(ABRRBefore);
    expect(reservedDinAB).equals("0");
    expect(reservedAinBDAfter).to.lessThan(reservedAinBDBefore);
  });
});
