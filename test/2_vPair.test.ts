import { loadFixture } from "@nomicfoundation/hardhat-network-helpers";
import { expect } from "chai";
import { ethers } from "hardhat";
import { deployPools } from "../fixtures/deployPools";
import {
  IERC20Metadata__factory,
  VPair__factory,
} from "../typechain-types/index";
import _ from "lodash";

describe("vPair", () => {
  let accounts: any = [];
  let fixture: any = {};

  before(async function () {
    fixture = await loadFixture(deployPools);
  });

  it("Should swap native A to B on pool A/B", async () => {
    accounts = _.map(fixture.accounts, "address");
    const abPool = fixture.abPool;
    const tokenA = fixture.tokenA;
    const owner = fixture.owner;
    const tokenB = fixture.tokenB;

    const aBalancePoolBefore = await tokenB.balanceOf(abPool.address);
    const bBalancePoolBefore = await tokenA.balanceOf(abPool.address);
    const aBalanceWalletBefore = await tokenB.balanceOf(owner.address);
    const bBalanceWalletBefore = await tokenA.balanceOf(owner.address);
    let aAmountOut = ethers.utils.parseEther("10");

    let amountIn = await fixture.vRouterInstance.getAmountIn(
      tokenA.address,
      tokenB.address,
      aAmountOut
    );

    await tokenA.transfer(abPool.address, amountIn);

    await abPool.swapNative(aAmountOut, tokenB.address, owner.address, []);

    const aBalancePoolAfter = await tokenB.balanceOf(abPool.address);
    const bBalancePoolAfter = await tokenA.balanceOf(abPool.address);
    const aBalanceWalletAfter = await tokenB.balanceOf(owner.address);
    const bBalanceWalletAfter = await tokenA.balanceOf(owner.address);

    expect(aBalancePoolBefore).to.be.above(aBalancePoolAfter);
    expect(bBalancePoolBefore).to.be.lessThan(bBalancePoolAfter);

    expect(aBalanceWalletBefore).to.be.lessThan(aBalanceWalletAfter);
    expect(bBalanceWalletBefore).to.be.above(bBalanceWalletAfter);
  });

  it("Should swap native B to A on pool A/B", async () => {
    const abPool = fixture.abPool;
    const tokenA = fixture.tokenA;
    const owner = fixture.owner;
    const tokenB = fixture.tokenB;

    const aBalancePoolBefore = await tokenA.balanceOf(abPool.address);
    const bBalancePoolBefore = await tokenB.balanceOf(abPool.address);
    const aBalanceWalletBefore = await tokenA.balanceOf(owner.address);
    const bBalanceWalletBefore = await tokenB.balanceOf(owner.address);

    let aAmountOut = ethers.utils.parseEther("10");

    let amountIn = await fixture.vRouterInstance.getAmountIn(
      tokenB.address,
      tokenA.address,
      aAmountOut
    );

    await tokenB.transfer(abPool.address, amountIn);

    await abPool.swapNative(aAmountOut, tokenA.address, owner.address, []);

    const aBalancePoolAfter = await tokenA.balanceOf(abPool.address);
    const bBalancePoolAfter = await tokenB.balanceOf(abPool.address);
    const aBalanceWalletAfter = await tokenA.balanceOf(owner.address);
    const bBalanceWalletAfter = await tokenB.balanceOf(owner.address);

    expect(aBalancePoolBefore).to.be.above(aBalancePoolAfter);
    expect(bBalancePoolBefore).to.be.lessThan(bBalancePoolAfter);
    expect(aBalanceWalletBefore).to.be.lessThan(aBalanceWalletAfter);
    expect(bBalanceWalletBefore).to.be.above(bBalanceWalletAfter);
  });

  it("Should swap reserve-to-native C to A on pool A/B", async () => {
    const abPool = fixture.abPool;
    const tokenA = fixture.tokenA;
    const owner = fixture.owner;
    const tokenB = fixture.tokenB;
    const tokenC = fixture.tokenC;
    const vPairFactoryInstance = fixture.vPairFactoryInstance;
    const vRouterInstance = fixture.vRouterInstance;

    const aBalancePoolBefore = await tokenA.balanceOf(abPool.address);
    const bBalancePoolBefore = await tokenC.balanceOf(abPool.address);
    const aBalanceWalletBefore = await tokenA.balanceOf(owner.address);
    const bBalanceWalletBefore = await tokenC.balanceOf(owner.address);

    let aAmountOut = ethers.utils.parseEther("10");

    let jkAddress = await vPairFactoryInstance.getPair(
      tokenB.address,
      tokenA.address
    );

    let ikAddress = await vPairFactoryInstance.getPair(
      tokenB.address,
      tokenC.address
    );

    let amountIn = await vRouterInstance.getVirtualAmountIn(
      jkAddress,
      ikAddress,
      aAmountOut
    );

    await tokenC.transfer(abPool.address, amountIn);

    await abPool.swapReserveToNative(aAmountOut, ikAddress, owner.address, []);

    const aBalancePoolAfter = await tokenA.balanceOf(abPool.address);
    const bBalancePoolAfter = await tokenC.balanceOf(abPool.address);
    const aBalanceWalletAfter = await tokenA.balanceOf(owner.address);
    const bBalanceWalletAfter = await tokenC.balanceOf(owner.address);

    expect(aBalancePoolBefore).to.be.above(aBalancePoolAfter);
    expect(bBalancePoolBefore).to.be.lessThan(bBalancePoolAfter);
    expect(aBalanceWalletBefore).to.be.lessThan(aBalanceWalletAfter);
    expect(bBalanceWalletBefore).to.be.above(bBalanceWalletAfter);

    let amountOut = await abPool.reserves(tokenC.address);
  });

  it("Should swap native-to-reserve A to C on pool A/B", async () => {
    const abPool = fixture.abPool;
    const bcPool = fixture.bcPool;

    const tokenA = fixture.tokenA;
    const owner = fixture.owner;
    const tokenC = fixture.tokenC;
    const vPairFactoryInstance = fixture.vPairFactoryInstance;
    const vRouterInstance = fixture.vRouterInstance;

    await vPairFactoryInstance.setExchangeReservesAddress(owner.address);

    let amountOut = await abPool.reserves(tokenC.address);

    let amountIn = await vRouterInstance.getVirtualAmountIn(
      bcPool.address,
      abPool.address,
      amountOut
    );

    let reserveRatioBefore = await abPool.calculateReserveRatio();
    let tokenAReserve = await abPool.reservesBaseValue(tokenC.address);

    await tokenA.transfer(abPool.address, amountIn);

    await abPool.swapNativeToReserve(
      amountOut,
      bcPool.address,
      owner.address,
      []
    );

    let reserveRatioAfter = await abPool.calculateReserveRatio();

    expect(reserveRatioAfter).to.lessThan(reserveRatioBefore);

    let tokenAReserveAfter = await abPool.reservesBaseValue(tokenC.address);
    expect(tokenAReserveAfter).to.lessThan(tokenAReserve);
  });

  it("Should set max whitelist count", async () => {
    const abPool = fixture.abPool;

    const maxWhitelist = await abPool.max_whitelist_count();

    await abPool.setMaxWhitelistCount(maxWhitelist - 1);

    const maxWhitelistAfter = await abPool.max_whitelist_count();

    expect(maxWhitelist - 1).to.equal(maxWhitelistAfter);
  });

  it("Should set whitelist", async () => {
    const abPool = fixture.abPool;
    const owner = fixture.owner;

    await abPool.setWhitelist(accounts.slice(1, 4), {
      from: owner.address,
    });
    const response1 = await abPool.whitelistAllowance(accounts[1]);
    const response2 = await abPool.whitelistAllowance(accounts[2]);
    const response3 = await abPool.whitelistAllowance(accounts[3]);

    expect(response1).to.be.true;
    expect(response2).to.be.true;
    expect(response3).to.be.true;
  });

  it("Should assert old whitelist is obsolete after re-setting", async () => {
    const abPool = fixture.abPool;
    const owner = fixture.owner;

    await abPool.setWhitelist(accounts.slice(1, 5));

    let response1 = await abPool.whitelistAllowance(accounts[1]);
    let response2 = await abPool.whitelistAllowance(accounts[2]);
    let response3 = await abPool.whitelistAllowance(accounts[3]);
    let response4 = await abPool.whitelistAllowance(accounts[4]);
    let response5 = await abPool.whitelistAllowance(accounts[5]);
    let response6 = await abPool.whitelistAllowance(accounts[6]);
    let response7 = await abPool.whitelistAllowance(accounts[7]);
    let response8 = await abPool.whitelistAllowance(accounts[8]);

    expect(response1).to.be.true;
    expect(response2).to.be.true;
    expect(response3).to.be.true;
    expect(response4).to.be.true;
    expect(response5).to.be.false;
    expect(response6).to.be.false;
    expect(response7).to.be.false;
    expect(response8).to.be.false;

    await abPool.setWhitelist(accounts.slice(5, 9), {
      from: owner.address,
    });

    response1 = await abPool.whitelistAllowance(accounts[1]);
    response2 = await abPool.whitelistAllowance(accounts[2]);
    response3 = await abPool.whitelistAllowance(accounts[3]);
    response4 = await abPool.whitelistAllowance(accounts[4]);
    response5 = await abPool.whitelistAllowance(accounts[5]);
    response6 = await abPool.whitelistAllowance(accounts[6]);
    response7 = await abPool.whitelistAllowance(accounts[7]);
    response8 = await abPool.whitelistAllowance(accounts[8]);

    expect(response1).to.be.false;
    expect(response2).to.be.false;
    expect(response3).to.be.false;
    expect(response4).to.be.false;

    expect(response5).to.be.true;
    expect(response6).to.be.true;
    expect(response7).to.be.true;
    expect(response8).to.be.true;
  });

  it("Should not set whitelist if list is longer then max_whitelist", async () => {
    const abPool = fixture.abPool;

    await expect(abPool.setWhitelist(accounts.slice(1, 9))).to.revertedWith(
      "MW"
    );
  });

  it("Should not set whitelist if not admin", async () => {
    const abPool = fixture.abPool;
    const abPoolSigner2 = VPair__factory.connect(
      abPool.address,
      fixture.accounts[2]
    );

    await expect(
      abPoolSigner2.setWhitelist(accounts.slice(1, 5))
    ).to.revertedWith("OA");
  });

  it("Should set fee", async () => {
    const abPool = fixture.abPool;

    const feeChange = 1000;
    const vFeeChange = 2000;
    await abPool.setFee(feeChange, vFeeChange);

    const fee = await abPool.fee();
    const vFee = await abPool.vFee();

    expect(fee).to.be.equal(feeChange);
    expect(vFee).to.be.equal(vFeeChange);
  });

  it("Should set max reserve threshold", async () => {
    const abPool = fixture.abPool;
    const thresholdChange = 2000;
    await abPool.setMaxReserveThreshold(thresholdChange);
  });

  it("Should burn", async () => {
    const abPool = fixture.abPool;
    const owner = fixture.owner;

    //get LP balance
    const lpBalance = await abPool.balanceOf(owner.address);
    //transfer LP tokens to pool
    let erc20 = IERC20Metadata__factory.connect(abPool.address, owner);
    await erc20.transfer(abPool.address, lpBalance);
    //call burn function
    await abPool.burn(owner.address);

    const lpBalanceAfter = await abPool.balanceOf(owner.address);
    const reservesAfter = await abPool.getReserves();

    expect(lpBalanceAfter).to.equal(0);

    let reservesAfter0 = reservesAfter._reserve0;
    let reservesAfter1 = reservesAfter._reserve1;

    expect(reservesAfter0).to.equal(577); // 578 = MINIUMUM LOCKED LIQUIDITY
    expect(reservesAfter1).to.equal(1734); // 1733 = MINIUMUM LOCKED LIQUIDITY
  });

  it("Should set factory", async () => {
    const abPool = fixture.abPool;

    await abPool.setFactory(accounts[1]);

    const factoryAddress = await abPool.factory();

    expect(factoryAddress).to.be.equal(accounts[1]);
  });

  ////////////////////////////////////////////////////////////////

  // });
  // // WIP

  // it("Should mint", async () => {
  //   await vPairInstance.mint(wallet);
  //   const liquidity = await vPairInstance.balanceOf(wallet);

  //   let liquidityCalculated = toBn(18, 100);
  //   liquidityCalculated = liquidityCalculated.mul(toBn(18, 300));
  //   liquidityCalculated = sqrt(liquidityCalculated);
  //   liquidityCalculated = liquidityCalculated.sub(toBn(0, 10000));

  //   expect(liquidity.toString()).to.be.equal(liquidityCalculated.toString());
  // });

  // it("Should not mint if liquidity is not greater than 0 after deducting reserve ratio from liquidity", async () => {
  //   await vPairInstance.mint(wallet);
  //   const liquidity = await vPairInstance.balanceOf(wallet);

  //   let liquidityCalculated = toBn(18, 100);
  //   liquidityCalculated = liquidityCalculated.mul(toBn(18, 300));
  //   liquidityCalculated = sqrt(liquidityCalculated);
  //   liquidityCalculated = liquidityCalculated.sub(toBn(0, 10000));

  //   expect(liquidity.toString()).to.be.equal(liquidityCalculated.toString());
  // });

  // // it("Should not swap reserves if calculate reserve ratio is more than max allowed", async () => {});

  // // it("Should not swap reserves if not validated with factory", async () => {});

  // // it("Should not swap reserves if ik0 is not whitelisted", async () => {});

  // // it("Should calculate reserve ratio", async () => {
  // //   await vPairInstance.setWhitelist([tokenA.address], {
  // //     from: wallet,
  // //   });

  // //   const res1 = await vPairInstance.calculateReserveRatio();

  // //   await vPairInstance.mint(wallet);

  // //   const res2 = await vPairInstance.calculateReserveRatio();

  // //   expect((await vPairInstance.balanceOf(wallet)).eq(toDecimalUnits(18, 10000))).to.equal(true)
  // // });

  // it("Should not swap native if address is 0", async () => {
  //   const zeroAddress = "0x0000000000000000000000000000000000000000";
  //   await vPairInstance.mint(wallet);

  //   await tokenB.transfer(vPairInstance.address, toBn(18, 50));

  //   await expect(
  //     vPairInstance.swapNative(toBn(18, 1), tokenA.address, zeroAddress, [])
  //   ).to.revertedWith("IT");
  // });

  // it("Should not swap native if amount exceeds balance", async () => {
  //   await vPairInstance.mint(wallet);

  //   await tokenB.transfer(vPairInstance.address, toBn(18, 50));

  //   await expect(
  //     vPairInstance.swapNative(toBn(21, 1), tokenA.address, wallet, [])
  //   ).to.revertedWith("transfer amount exceeds balance");
  // });

  // it("Should not swap native if amount exceeds balance", async () => {
  //   await vPairInstance.mint(wallet);

  //   await tokenB.transfer(vPairInstance.address, toBn(18, 50));

  //   await expect(
  //     vPairInstance.swapNative(toBn(19, 6), tokenA.address, wallet, [])
  //   ).to.revertedWith("IIA");
  // });
});
