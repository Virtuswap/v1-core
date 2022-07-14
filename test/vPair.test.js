const { sqrt } = require("bn-sqrt");
const { toDecimalUnits, toBn } = require("./utils");
const { solidity } = require("ethereum-waffle");
const chai = require("chai");

const vPair = artifacts.require("vPair");
const ERC20 = artifacts.require("ERC20PresetFixedSupply");
const vPairFactory = artifacts.require("vPairFactory");
const vSwapMathFactory = artifacts.require("vSwapMath");
chai.use(solidity);
const { expect } = chai;

contract("vPair", (accounts) => {
  let tokenA, tokenB;
  let vPairFactoryInstance, vPairInstance, vSwapMathInstance;
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

    vPairFactoryInstance = await vPairFactory.new();

    await vPairFactoryInstance.createPair(tokenA.address, tokenB.address);
    let createdPair = await vPairFactoryInstance.getPair(
      tokenA.address,
      tokenB.address
    );

    vPairInstance = await vPair.at(createdPair);

    vSwapMathInstance = await vSwapMathFactory.new();

    await tokenA.approve(wallet, toDecimalUnits(18, 1000000));
    await tokenB.approve(wallet, toDecimalUnits(18, 1000000));

    await tokenA.transferFrom(
      wallet,
      vPairInstance.address,
      toDecimalUnits(18, 100)
    );
    await tokenB.transferFrom(
      wallet,
      vPairInstance.address,
      toDecimalUnits(18, 300)
    );
  });

  it("Should set whitelist", async () => {
    await vPairInstance.setWhitelist(accounts.slice(1, 5), {
      from: wallet,
    });
    const response1 = await vPairInstance.whitelistAllowance(accounts[1]);
    const response2 = await vPairInstance.whitelistAllowance(accounts[2]);
    const response3 = await vPairInstance.whitelistAllowance(accounts[3]);
    const response4 = await vPairInstance.whitelistAllowance(accounts[4]);

    expect(response1).to.be.true;
    expect(response2).to.be.true;
    expect(response3).to.be.true;
    expect(response4).to.be.true;
  });

  it("Should not set whitelist if list is longer then 8", async () => {
    await expect(
      vPairInstance.setWhitelist(accounts.slice(1, 10), {
        from: accounts[2],
      })
    ).to.revertedWith("");

    const response1 = await vPairInstance.whitelistAllowance(accounts[1]);
    const response2 = await vPairInstance.whitelistAllowance(accounts[2]);
    const response3 = await vPairInstance.whitelistAllowance(accounts[3]);
    const response4 = await vPairInstance.whitelistAllowance(accounts[4]);
    const response5 = await vPairInstance.whitelistAllowance(accounts[5]);
    const response6 = await vPairInstance.whitelistAllowance(accounts[6]);
    const response7 = await vPairInstance.whitelistAllowance(accounts[7]);
    const response8 = await vPairInstance.whitelistAllowance(accounts[8]);
    const response9 = await vPairInstance.whitelistAllowance(accounts[9]);

    expect(response1).to.be.false;
    expect(response2).to.be.false;
    expect(response3).to.be.false;
    expect(response4).to.be.false;
    expect(response5).to.be.false;
    expect(response6).to.be.false;
    expect(response7).to.be.false;
    expect(response8).to.be.false;
    expect(response9).to.be.false;
  });

  it("Should not set whitelist if not admin", async () => {
    await expect(
      vPairInstance.setWhitelist(accounts.slice(1, 5), {
        from: accounts[2],
      })
    ).to.revertedWith("");

    const response1 = await vPairInstance.whitelistAllowance(accounts[1]);
    const response2 = await vPairInstance.whitelistAllowance(accounts[2]);
    const response3 = await vPairInstance.whitelistAllowance(accounts[3]);
    const response4 = await vPairInstance.whitelistAllowance(accounts[4]);

    expect(response1).to.be.false;
    expect(response2).to.be.false;
    expect(response3).to.be.false;
    expect(response4).to.be.false;
  });

  it("Should set factory", async () => {
    vPairFactoryInstance2 = await vPairFactory.new({
      from: accounts[1],
    });

    await vPairInstance.setFactory(vPairFactoryInstance2.address);

    const factoryAddress = await vPairInstance.factory();

    expect(factoryAddress).to.be.equal(vPairFactoryInstance2.address);
  });

  it("Should not set factory if not admin", async () => {
    vPairFactoryInstance2 = await vPairFactory.new({
      from: accounts[1],
    });

    await expect(
      vPairInstance.setFactory(vPairFactoryInstance2.address, {
        from: accounts[1],
      })
    ).to.revertedWith("");

    const factoryAddress = await vPairInstance.factory();

    expect(factoryAddress).to.be.not.equal(vPairFactoryInstance2.address);
  });

  it("Should set fee", async () => {
    const feeChange = 1000;
    const vFeeChange = 2000;
    await vPairInstance.setFee(feeChange, vFeeChange);

    const fee = await vPairInstance.fee();
    const vFee = await vPairInstance.vFee();

    expect(fee.toNumber()).to.be.equal(feeChange);
    expect(vFee.toNumber()).to.be.equal(vFeeChange);
  });

  it("Should not set fee if not admin", async () => {
    const feeChange = 1000;
    const vFeeChange = 2000;

    await expect(
      vPairInstance.vPairInstance.setFee(feeChange, vFeeChange, {
        from: accounts[1],
      })
    ).to.revertedWith("");

    const fee = await vPairInstance.fee();
    const vFee = await vPairInstance.vFee();

    expect(fee.toNumber()).to.be.not.equal(feeChange);
    expect(vFee.toNumber()).to.be.not.equal(vFeeChange);
  });

  it("Should set max reserve threshold", async () => {
    let reverted = false;
    const thresholdChange = 2000;
    try {
      await vPairInstance.setMaxReserveThreshold(thresholdChange);
    } catch (err) {
      reverted = true;
    }

    expect(reverted).to.be.false;
  });

  it("Should not set max reserve threshold if not admin", async () => {
    const thresholdChange = 2000;

    await expect(
      vPairInstance.setMaxReserveThreshold(feeChange, vFeeChange, {
        from: accounts[1],
      })
    ).to.revertedWith("");
  });

  it("Should mint", async () => {
    await vPairInstance.mint(wallet);
    const liquidity = await vPairInstance.balanceOf(wallet);

    let liquidityCalculated = toBn(18, 100);
    liquidityCalculated = liquidityCalculated.mul(toBn(18, 300));
    liquidityCalculated = sqrt(liquidityCalculated);
    liquidityCalculated = liquidityCalculated.sub(toBn(0, 10000));

    expect(liquidity.toString()).to.be.equal(liquidityCalculated.toString());
  });

  it("Should not mint if liquidity is not greater than 0 after deducting reserve ratio from liquidity", async () => {
    await vPairInstance.mint(wallet);
    const liquidity = await vPairInstance.balanceOf(wallet);

    let liquidityCalculated = toBn(18, 100);
    liquidityCalculated = liquidityCalculated.mul(toBn(18, 300));
    liquidityCalculated = sqrt(liquidityCalculated);
    liquidityCalculated = liquidityCalculated.sub(toBn(0, 10000));

    expect(liquidity.toString()).to.be.equal(liquidityCalculated.toString());
  });

  it("Should burn", async () => {
    await vPairInstance.mint(wallet);
    const liquidityWallet = await vPairInstance.balanceOf(wallet);

    await vPairInstance.transfer(vPairInstance.address, liquidityWallet);
    const liquidity = await vPairInstance.balanceOf(vPairInstance.address);
    const totalSupply = await vPairInstance.totalSupply();

    const aBalancePoolBefore = await tokenA.balanceOf(vPairInstance.address);
    let aBalancePoolShouldLeft = aBalancePoolBefore.mul(liquidity);
    aBalancePoolShouldLeft = aBalancePoolShouldLeft.div(totalSupply);
    const bBalancePoolBefore = await tokenB.balanceOf(vPairInstance.address);
    let bBalancePoolShouldLeft = bBalancePoolBefore.mul(liquidity);
    bBalancePoolShouldLeft = bBalancePoolShouldLeft.div(totalSupply);
    const aBalanceWalletBefore = await tokenA.balanceOf(wallet);
    const bBalanceWalletBefore = await tokenB.balanceOf(wallet);

    await vPairInstance.burn(wallet);
    const aBalancePoolAfter = await tokenA.balanceOf(vPairInstance.address);
    const bBalancePoolAfter = await tokenB.balanceOf(vPairInstance.address);
    const aBalanceWalletAfter = await tokenA.balanceOf(wallet);
    const bBalanceWalletAfter = await tokenB.balanceOf(wallet);

    expect(aBalancePoolAfter.lt(aBalancePoolBefore)).to.be.true;
    expect(bBalancePoolAfter.lt(bBalancePoolBefore)).to.be.true;
    expect(aBalanceWalletBefore.lt(aBalanceWalletAfter)).to.be.true;
    expect(bBalanceWalletBefore.lt(bBalanceWalletAfter)).to.be.true;

    expect(
      aBalancePoolAfter.add(aBalancePoolShouldLeft).toString()
    ).to.be.equal(aBalancePoolBefore.toString());
    expect(
      bBalancePoolAfter.add(bBalancePoolShouldLeft).toString()
    ).to.be.equal(bBalancePoolBefore.toString());

    expect(
      aBalanceWalletAfter.sub(aBalanceWalletBefore).toString()
    ).to.be.equal(aBalancePoolBefore.sub(aBalancePoolAfter).toString());
    expect(
      bBalanceWalletAfter.sub(bBalanceWalletBefore).toString()
    ).to.be.equal(bBalancePoolBefore.sub(bBalancePoolAfter).toString());
  });

  it("Should not burn if liquidity was not transferred", async () => {
    await vPairInstance.mint(wallet);

    await expect(vPairInstance.burn(wallet)).to.revertedWith("ILB.");
  });

  it("Should not burn if balance of one token is 0", async () => {
    await vPairInstance.mint(wallet);

    const removal = await tokenA.balanceOf(vPairInstance.address);
    await tokenA.transfer(wallet, removal);

    await expect(vPairInstance.burn(wallet)).to.revertedWith("ILB.");
  });
  // WIP

  // it("Should swap reserves", async () => {
  //   await vPairInstance.mint(wallet);
  //   const liquidity = await vPairInstance(wallet);
  // });

  // it("Should not swap reserves if calculate reserve ratio is more than max allowed", async () => {});

  // it("Should not swap reserves if not validated with factory", async () => {});

  // it("Should not swap reserves if ik0 is not whitelisted", async () => {});

  // it("Should calculate reserve ratio", async () => {
  //   await vPairInstance.setWhitelist([tokenA.address], {
  //     from: wallet,
  //   });

  //   const res1 = await vPairInstance.calculateReserveRatio();

  //   await vPairInstance.mint(wallet);

  //   const res2 = await vPairInstance.calculateReserveRatio();

  //   expect((await vPairInstance.balanceOf(wallet)).eq(toDecimalUnits(18, 10000))).to.equal(true)
  // });

  it("Should swap native", async () => {
    await vPairInstance.mint(wallet);

    const aBalancePoolBefore = await tokenA.balanceOf(vPairInstance.address);
    const bBalancePoolBefore = await tokenB.balanceOf(vPairInstance.address);
    const aBalanceWalletBefore = await tokenA.balanceOf(wallet);
    const bBalanceWalletBefore = await tokenB.balanceOf(wallet);

    await tokenB.transfer(vPairInstance.address, toBn(18, 50));

    await vPairInstance.swapNative(toBn(18, 1), tokenA.address, wallet, []);

    const aBalancePoolAfter = await tokenA.balanceOf(vPairInstance.address);
    const bBalancePoolAfter = await tokenB.balanceOf(vPairInstance.address);
    const aBalanceWalletAfter = await tokenA.balanceOf(wallet);
    const bBalanceWalletAfter = await tokenB.balanceOf(wallet);

    expect(aBalancePoolBefore.toString()).to.be.equal(
      aBalancePoolAfter.add(toBn(18, 1)).toString()
    );
    expect(bBalancePoolAfter.toString()).to.be.equal(
      bBalancePoolBefore.add(toBn(18, 50)).toString()
    );
    expect(aBalanceWalletAfter.toString()).to.be.equal(
      aBalanceWalletBefore.add(toBn(18, 1)).toString()
    );
    expect(bBalanceWalletBefore.toString()).to.be.equal(
      bBalanceWalletAfter.add(toBn(18, 50)).toString()
    );
  });

  it("Should not swap native if address is 0", async () => {
    const zeroAddress = "0x0000000000000000000000000000000000000000";
    await vPairInstance.mint(wallet);

    await tokenB.transfer(vPairInstance.address, toBn(18, 50));

    await expect(
      vPairInstance.swapNative(toBn(18, 1), tokenA.address, zeroAddress, [])
    ).to.revertedWith("IT");
  });

  it("Should not swap native if amount exceeds balance", async () => {
    await vPairInstance.mint(wallet);

    await tokenB.transfer(vPairInstance.address, toBn(18, 50));

    await expect(
      vPairInstance.swapNative(toBn(21, 1), tokenA.address, wallet, [])
    ).to.revertedWith("transfer amount exceeds balance");
  });

  it("Should not swap native if amount exceeds balance", async () => {
    await vPairInstance.mint(wallet);

    await tokenB.transfer(vPairInstance.address, toBn(18, 50));

    await expect(
      vPairInstance.swapNative(toBn(19, 6), tokenA.address, wallet, [])
    ).to.revertedWith("IIA");
  });
});
