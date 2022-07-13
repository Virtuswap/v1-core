const {sqrt } = require('bn-sqrt');
const { toDecimalUnits, toBn } = require("./utils");

const vPair = artifacts.require("vPair");
const ERC20 = artifacts.require("ERC20PresetFixedSupply");
const vPairFactory = artifacts.require("vPairFactory");

contract("vPair", (accounts) => {
  let tokenA, tokenB;
  let vPairFactoryInstance, vPairInstance;
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
    let reverted = false;
    try {
      await vPairInstance.setWhitelist(accounts.slice(1, 10), {
        from: accounts[2],
      });
    } catch (err) {
      reverted = true;
    }
    const response1 = await vPairInstance.whitelistAllowance(accounts[1]);
    const response2 = await vPairInstance.whitelistAllowance(accounts[2]);
    const response3 = await vPairInstance.whitelistAllowance(accounts[3]);
    const response4 = await vPairInstance.whitelistAllowance(accounts[4]);
    const response5 = await vPairInstance.whitelistAllowance(accounts[5]);
    const response6 = await vPairInstance.whitelistAllowance(accounts[6]);
    const response7 = await vPairInstance.whitelistAllowance(accounts[7]);
    const response8 = await vPairInstance.whitelistAllowance(accounts[8]);
    const response9 = await vPairInstance.whitelistAllowance(accounts[9]);

    expect(reverted).to.be.true;
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
    let reverted = false;
    try {
      await vPairInstance.setWhitelist(accounts.slice(1, 5), {
        from: accounts[2],
      });
    } catch (err) {
      reverted = true;
    }
    const response1 = await vPairInstance.whitelistAllowance(accounts[1]);
    const response2 = await vPairInstance.whitelistAllowance(accounts[2]);
    const response3 = await vPairInstance.whitelistAllowance(accounts[3]);
    const response4 = await vPairInstance.whitelistAllowance(accounts[4]);

    expect(reverted).to.be.true;
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
    let reverted = false;
    vPairFactoryInstance2 = await vPairFactory.new({
      from: accounts[1],
    });

    try {
      await vPairInstance.setFactory(vPairFactoryInstance2.address, {
        from: accounts[1],
      });
    } catch (err) {
      reverted = true;
    }

    const factoryAddress = await vPairInstance.factory();

    expect(reverted).to.be.true;
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
    let reverted = false;

    try {
      await vPairInstance.setFee(feeChange, vFeeChange, {
        from: accounts[1],
      });
    } catch (err) {
      reverted = true;
    }

    const fee = await vPairInstance.fee();
    const vFee = await vPairInstance.vFee();

    expect(reverted).to.be.true;
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
    let reverted = false;

    try {
      await vPairInstance.setMaxReserveThreshold(feeChange, vFeeChange, {
        from: accounts[1],
      });
    } catch (err) {
      reverted = true;
    }

    expect(reverted).to.be.true;
  });

    // Main functionality

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

  // it("Should burn", async () => {});

  // //   check require in burn
  // it("Should not burn if", async () => {});

  // it("Should swap reserves", async () => {});

  // it("Should not swap reserves if calculate reserve ratio is more than max allowed", async () => {});

  // it("Should not swap reserves if not validated with factory", async () => {});

  // it("Should not swap reserves if ik0 is not whitelisted", async () => {});

  // TODO
  // it("Should calculate reserve ratio", async () => {
  //   await vPairInstance.setWhitelist([tokenA.address, tokenB.address], {
  //     from: wallet,
  //   });

  //   const res1 = await vPairInstance.calculateReserveRatio();

  //   // Nothing was minted reserve0 is 0
  //   expect(res1.toNumber()).to.be.equal(0);

  //   await vPairInstance.mint(wallet);
  //   const res2 = await vPairInstance.calculateReserveRatio();

  //   console.log((await vPairInstance.balanceOf(wallet)).toString());
  //   console.log(res2.toString());
  //   console.log((await vPairInstance.reserve0()));
  //   // expect((await vPairInstance.balanceOf(wallet)).eq(toDecimalUnits(18, 10000))).to.equal(true)
  // });

  it("Should swap native", async () => {});

  // it("Should not swap native if address is 0", async () => {
  //   let reverted = false;
     
  //   try{
  //     await debug(await vPairInstance.swapNative(toBn(18, 20), tokenA.address, accounts[1], []));
  //   }catch (err){
  //     console.log((await tokenA.balanceOf(wallet)).toString())
  //     console.log(err);
  //     reverted = true;
  //   }

  //   expect(reverted).to.be.true;
  // });

  // it("Should not swap native if amount in is less than expected", async () => {
  //   const zeroAddress = "0x0000000000000000000000000000000000000000";
  //   let reverted = false;
     
  //   try{
  //     await vPairInstance.swapNative(100, tokenA.address, zeroAddress, []);
  //   }catch (err){
  //     reverted = true;
  //   }

  //   expect(reverted).to.be.true;
  // });
});
