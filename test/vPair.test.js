const { solidity } = require("ethereum-waffle");
const chai = require("chai");
const { assert } = require("chai");

const vRouter = artifacts.require("vRouter");
// const FlashSwapExample = artifacts.require("flashSwapExample");
const vPair = artifacts.require("vPair");
const ERC20 = artifacts.require("ERC20PresetFixedSupply");
const vPairFactory = artifacts.require("vPairFactory");
chai.use(solidity);
const { expect } = chai;

contract("vPair", (accounts) => {
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
  const B_PRICE = 3;
  const C_PRICE = 6;

  let tokenA, tokenB, tokenC, WETH;

  const issueAmount = web3.utils.toWei("100000000000000", "ether");

  let vPairFactoryInstance, vRouterInstance, vFlashSwapExample, vPairInstance;

  before(async () => {
    tokenA = await ERC20.new("tokenA", "A", issueAmount, accounts[0]);

    tokenB = await ERC20.new("tokenB", "B", issueAmount, accounts[0]);

    tokenC = await ERC20.new("tokenC", "C", issueAmount, accounts[0]);

    vPairFactoryInstance = await vPairFactory.deployed();
    vRouterInstance = await vRouter.deployed();

    await tokenA.approve(vRouterInstance.address, issueAmount);
    await tokenB.approve(vRouterInstance.address, issueAmount);
    await tokenC.approve(vRouterInstance.address, issueAmount);

    const futureTs = await getFutureBlockTimestamp();

    //create pool A/B with 10,000 A and equivalent B
    let AInput = 10000 * A_PRICE;
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

    //whitelist tokens in pools

    //pool 1
    const address = await vPairFactoryInstance.getPair(
      tokenA.address,
      tokenB.address
    );
    const pool = await vPair.at(address);

    vPairInstance = await vPair.at(address);

    //whitelist token C
    await pool.setWhitelist([tokenC.address]);

    let reserve0 = await pool.reserve0();
    let reserve1 = await pool.reserve1();

    reserve0 = fromWeiToNumber(reserve0);
    reserve1 = fromWeiToNumber(reserve1);

    // console.log(
    //   "pool1: A/B: (" + pool.address + ") " + reserve0 + "/" + reserve1
    // );

    //pool 2
    const address2 = await vPairFactoryInstance.getPair(
      tokenA.address,
      tokenC.address
    );
    const pool2 = await vPair.at(address2);

    //whitelist token B
    await pool2.setWhitelist([tokenB.address]);

    let reserve0Pool2 = await pool2.reserve0();
    let reserve1Pool2 = await pool2.reserve1();

    reserve0Pool2 = fromWeiToNumber(reserve0Pool2);
    reserve1Pool2 = fromWeiToNumber(reserve1Pool2);

    // console.log(
    //   "pool2: A/C: (" +
    //     pool2.address +
    //     ") " +
    //     reserve0Pool2 +
    //     "/" +
    //     reserve1Pool2
    // );

    //pool 3
    const address3 = await vPairFactoryInstance.getPair(
      tokenB.address,
      tokenC.address
    );
    const pool3 = await vPair.at(address3);

    //whitelist token A
    await pool3.setWhitelist([tokenA.address]);

    let reserve0Pool3 = await pool3.reserve0();
    let reserve1Pool3 = await pool3.reserve1();

    reserve0Pool3 = fromWeiToNumber(reserve0Pool3);
    reserve1Pool3 = fromWeiToNumber(reserve1Pool3);

    // console.log(
    //   "pool3: B/C: (" +
    //     pool3.address +
    //     ") " +
    //     reserve0Pool3 +
    //     "/" +
    //     reserve1Pool3
    // );

    // vFlashSwapExample = await FlashSwapExample.new(
    //   vPairFactoryInstance.address,
    //   vRouterInstance.address,
    //   tokenA.address,
    //   tokenB.address,
    //   tokenC.address
    // );

    // await tokenA.approve(vFlashSwapExample.address, issueAmount);
    // await tokenB.approve(vFlashSwapExample.address, issueAmount);
    // await tokenC.approve(vFlashSwapExample.address, issueAmount);
  });

  // it("Should flashswap buying B from A/B, swaping B (reserve) to A on pool A/C and payback loan to pool A/B", async function () {
  //   await vFlashSwapExample.testFlashswap();
  // });

  it("Should swap native A to B on pool A/B", async () => {
    const aBalancePoolBefore = await tokenB.balanceOf(vPairInstance.address);
    const bBalancePoolBefore = await tokenA.balanceOf(vPairInstance.address);
    const aBalanceWalletBefore = await tokenB.balanceOf(accounts[0]);
    const bBalanceWalletBefore = await tokenA.balanceOf(accounts[0]);

    let aAmountOut = web3.utils.toWei("10", "ether");

    let amountIn = await vRouterInstance.getAmountIn(
      tokenA.address,
      tokenB.address,
      aAmountOut
    );

    await tokenA.transfer(vPairInstance.address, amountIn);

    await vPairInstance.swapNative(aAmountOut, tokenB.address, accounts[0], []);

    const aBalancePoolAfter = await tokenB.balanceOf(vPairInstance.address);
    const bBalancePoolAfter = await tokenA.balanceOf(vPairInstance.address);
    const aBalanceWalletAfter = await tokenB.balanceOf(accounts[0]);
    const bBalanceWalletAfter = await tokenA.balanceOf(accounts[0]);

    expect(fromWeiToNumber(aBalancePoolBefore)).to.be.above(
      fromWeiToNumber(aBalancePoolAfter)
    );
    expect(fromWeiToNumber(bBalancePoolBefore)).to.be.lessThan(
      fromWeiToNumber(bBalancePoolAfter)
    );
    expect(fromWeiToNumber(aBalanceWalletBefore)).to.be.lessThan(
      fromWeiToNumber(aBalanceWalletAfter)
    );
    expect(fromWeiToNumber(bBalanceWalletBefore)).to.be.above(
      fromWeiToNumber(bBalanceWalletAfter)
    );
  });

  it("Should swap native B to A on pool A/B", async () => {
    const aBalancePoolBefore = await tokenA.balanceOf(vPairInstance.address);
    const bBalancePoolBefore = await tokenB.balanceOf(vPairInstance.address);
    const aBalanceWalletBefore = await tokenA.balanceOf(accounts[0]);
    const bBalanceWalletBefore = await tokenB.balanceOf(accounts[0]);

    let aAmountOut = web3.utils.toWei("10", "ether");

    let amountIn = await vRouterInstance.getAmountIn(
      tokenB.address,
      tokenA.address,
      aAmountOut
    );

    await tokenB.transfer(vPairInstance.address, amountIn);

    await vPairInstance.swapNative(aAmountOut, tokenA.address, accounts[0], []);

    const aBalancePoolAfter = await tokenA.balanceOf(vPairInstance.address);
    const bBalancePoolAfter = await tokenB.balanceOf(vPairInstance.address);
    const aBalanceWalletAfter = await tokenA.balanceOf(accounts[0]);
    const bBalanceWalletAfter = await tokenB.balanceOf(accounts[0]);

    expect(fromWeiToNumber(aBalancePoolBefore)).to.be.above(
      fromWeiToNumber(aBalancePoolAfter)
    );
    expect(fromWeiToNumber(bBalancePoolBefore)).to.be.lessThan(
      fromWeiToNumber(bBalancePoolAfter)
    );
    expect(fromWeiToNumber(aBalanceWalletBefore)).to.be.lessThan(
      fromWeiToNumber(aBalanceWalletAfter)
    );
    expect(fromWeiToNumber(bBalanceWalletBefore)).to.be.above(
      fromWeiToNumber(bBalanceWalletAfter)
    );
  });

  it("Should swap reserve-to-native C to A on pool A/B", async () => {
    const aBalancePoolBefore = await tokenA.balanceOf(vPairInstance.address);
    const bBalancePoolBefore = await tokenC.balanceOf(vPairInstance.address);
    const aBalanceWalletBefore = await tokenA.balanceOf(accounts[0]);
    const bBalanceWalletBefore = await tokenC.balanceOf(accounts[0]);

    let aAmountOut = web3.utils.toWei("10", "ether");

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

    await tokenC.transfer(vPairInstance.address, amountIn);

    await vPairInstance.swapReserveToNative(
      aAmountOut,
      ikAddress,
      accounts[0],
      []
    );

    const aBalancePoolAfter = await tokenA.balanceOf(vPairInstance.address);
    const bBalancePoolAfter = await tokenC.balanceOf(vPairInstance.address);
    const aBalanceWalletAfter = await tokenA.balanceOf(accounts[0]);
    const bBalanceWalletAfter = await tokenC.balanceOf(accounts[0]);

    expect(fromWeiToNumber(aBalancePoolBefore)).to.be.above(
      fromWeiToNumber(aBalancePoolAfter)
    );
    expect(fromWeiToNumber(bBalancePoolBefore)).to.be.lessThan(
      fromWeiToNumber(bBalancePoolAfter)
    );
    expect(fromWeiToNumber(aBalanceWalletBefore)).to.be.lessThan(
      fromWeiToNumber(aBalanceWalletAfter)
    );
    expect(fromWeiToNumber(bBalanceWalletBefore)).to.be.above(
      fromWeiToNumber(bBalanceWalletAfter)
    );
  });

  it("Should swap native-to-reserve A to C on pool A/B", async () => {
    const aBalancePoolBefore = await tokenA.balanceOf(vPairInstance.address);
    const bBalancePoolBefore = await tokenC.balanceOf(vPairInstance.address);
    const aBalanceWalletBefore = await tokenA.balanceOf(accounts[0]);
    const bBalanceWalletBefore = await tokenC.balanceOf(accounts[0]);

    let aAmountOut = web3.utils.toWei("10", "ether");

    let jkAddress = await vPairFactoryInstance.getPair(
      tokenB.address,
      tokenA.address
    );

    let ikAddress = await vPairFactoryInstance.getPair(
      tokenB.address,
      tokenC.address
    );

    let amountIn = await vRouterInstance.getVirtualAmountIn(
      ikAddress,
      jkAddress,
      aAmountOut
    );

    await tokenA.transfer(vPairInstance.address, amountIn);

    await vPairInstance.swapNativeToReserve(
      aAmountOut,
      ikAddress,
      accounts[0],
      []
    );

    const aBalancePoolAfter = await tokenA.balanceOf(vPairInstance.address);
    const bBalancePoolAfter = await tokenC.balanceOf(vPairInstance.address);
    const aBalanceWalletAfter = await tokenA.balanceOf(accounts[0]);
    const bBalanceWalletAfter = await tokenC.balanceOf(accounts[0]);

    expect(fromWeiToNumber(aBalancePoolAfter)).to.be.above(
      fromWeiToNumber(aBalancePoolBefore)
    );
    expect(fromWeiToNumber(bBalancePoolAfter)).to.be.lessThan(
      fromWeiToNumber(bBalancePoolBefore)
    );
    expect(fromWeiToNumber(aBalanceWalletAfter)).to.be.lessThan(
      fromWeiToNumber(aBalanceWalletBefore)
    );
    expect(fromWeiToNumber(bBalanceWalletAfter)).to.be.above(
      fromWeiToNumber(bBalanceWalletBefore)
    );
  });

  it("Should set max whitelist count", async () => {
    const maxWhitelist = await vPairInstance.max_whitelist_count();

    await vPairInstance.setMaxWhitelistCount(maxWhitelist - 1);

    const maxWhitelistAfter = await vPairInstance.max_whitelist_count();

    assert.equal(maxWhitelist - 1, maxWhitelistAfter);
  });

  it("Should set whitelist", async () => {
    await vPairInstance.setWhitelist(accounts.slice(1, 4), {
      from: accounts[0],
    });
    const response1 = await vPairInstance.whitelistAllowance(accounts[1]);
    const response2 = await vPairInstance.whitelistAllowance(accounts[2]);
    const response3 = await vPairInstance.whitelistAllowance(accounts[3]);

    expect(response1).to.be.true;
    expect(response2).to.be.true;
    expect(response3).to.be.true;
  });

  it("Should assert old whitelist is obsolete after re-setting", async () => {
    await vPairInstance.setWhitelist(accounts.slice(1, 5), {
      from: accounts[0],
    });

    let response1 = await vPairInstance.whitelistAllowance(accounts[1]);
    let response2 = await vPairInstance.whitelistAllowance(accounts[2]);
    let response3 = await vPairInstance.whitelistAllowance(accounts[3]);
    let response4 = await vPairInstance.whitelistAllowance(accounts[4]);
    let response5 = await vPairInstance.whitelistAllowance(accounts[5]);
    let response6 = await vPairInstance.whitelistAllowance(accounts[6]);
    let response7 = await vPairInstance.whitelistAllowance(accounts[7]);
    let response8 = await vPairInstance.whitelistAllowance(accounts[8]);

    expect(response1).to.be.true;
    expect(response2).to.be.true;
    expect(response3).to.be.true;
    expect(response4).to.be.true;
    expect(response5).to.be.false;
    expect(response6).to.be.false;
    expect(response7).to.be.false;
    expect(response8).to.be.false;

    await vPairInstance.setWhitelist(accounts.slice(5, 9), {
      from: accounts[0],
    });

    response1 = await vPairInstance.whitelistAllowance(accounts[1]);
    response2 = await vPairInstance.whitelistAllowance(accounts[2]);
    response3 = await vPairInstance.whitelistAllowance(accounts[3]);
    response4 = await vPairInstance.whitelistAllowance(accounts[4]);
    response5 = await vPairInstance.whitelistAllowance(accounts[5]);
    response6 = await vPairInstance.whitelistAllowance(accounts[6]);
    response7 = await vPairInstance.whitelistAllowance(accounts[7]);
    response8 = await vPairInstance.whitelistAllowance(accounts[8]);

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
    await expect(
      vPairInstance.setWhitelist(accounts.slice(1, 10), {
        from: accounts[2],
      })
    ).to.revertedWith("");
  });

  it("Should not set whitelist if not admin", async () => {
    await expect(
      vPairInstance.setWhitelist(accounts.slice(1, 5), {
        from: accounts[2],
      })
    ).to.revertedWith("");
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

  it("Should set max reserve threshold", async () => {
    let reverted = false;
    const thresholdChange = 2000;
    await vPairInstance.setMaxReserveThreshold(thresholdChange);
  });

  it("Should burn", async () => {
    //get pool AB
    const pool = await vPairFactoryInstance.getPair(
      tokenB.address,
      tokenA.address
    );

    //get LP balance
    const lpBalance = await vPairInstance.balanceOf(accounts[0]);

    //transfer LP tokens to pool
    await vPairInstance.transfer(vPairInstance.address, lpBalance);

    //call burn function
    await vPairInstance.burn(accounts[0]);

    const lpBalanceAfter = await vPairInstance.balanceOf(accounts[0]);
    const reservesAfter = await vPairInstance.getReserves();

    assert.equal(lpBalanceAfter, 0);

    let reservesAfter0 = fromWeiToNumber(reservesAfter._reserve0);
    let reservesAfter1 = fromWeiToNumber(reservesAfter._reserve1);

    assert.equal(reservesAfter0, 0);
    assert.equal(reservesAfter1, 0);
  });

  it("Should set factory", async () => {
    const originalAddress = await vPairInstance.factory();

    await vPairInstance.setFactory(accounts[1]);

    const factoryAddress = await vPairInstance.factory();

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
