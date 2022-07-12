const vRouter = artifacts.require("vRouter");
const vPair = artifacts.require("vPair");
const vPairFactory = artifacts.require("vPairFactory");
const vSwapMath = artifacts.require("vSwapMath");
const { catchRevert } = require("./exceptions");
const ERC20 = artifacts.require("ERC20PresetFixedSupply");

contract("vRouter", (accounts) => {
  let tokenA, tokenB, tokenC, WETH;

  const issueAmount = web3.utils.toWei("100000000000000", "ether");

  let vPairFactoryInstance, vRouterInstance, vSwapMathInstance;

  before(async () => {
    tokenA = await ERC20.new("tokenA", "A", issueAmount, accounts[0]);

    tokenB = await ERC20.new("tokenB", "B", issueAmount, accounts[0]);

    tokenC = await ERC20.new("tokenC", "C", issueAmount, accounts[0]);

    vPairFactoryInstance = await vPairFactory.deployed();
    vRouterInstance = await vRouter.deployed();
    vSwapMathInstance = await vSwapMath.deployed();

    await tokenA.approve(vRouterInstance.address, issueAmount);
    await tokenB.approve(vRouterInstance.address, issueAmount);
    await tokenC.approve(vRouterInstance.address, issueAmount);

    const futureTs = await getFutureBlockTimestamp();
    //create pool A/B
    await vRouterInstance.addLiquidity(
      tokenA.address,
      tokenB.address,
      web3.utils.toWei("10", "ether"),
      web3.utils.toWei("100", "ether"),
      web3.utils.toWei("10", "ether"),
      web3.utils.toWei("100", "ether"),
      accounts[0],
      futureTs
    );

    //create pool A/C
    await vRouterInstance.addLiquidity(
      tokenA.address,
      tokenC.address,
      web3.utils.toWei("1000", "ether"),
      web3.utils.toWei("1000", "ether"),
      web3.utils.toWei("1000", "ether"),
      web3.utils.toWei("1000", "ether"),
      accounts[0],
      futureTs
    );

    //create pool B/C
    await vRouterInstance.addLiquidity(
      tokenB.address,
      tokenC.address,
      web3.utils.toWei("5000", "ether"),
      web3.utils.toWei("10000", "ether"),
      web3.utils.toWei("1000", "ether"),
      web3.utils.toWei("1000", "ether"),
      accounts[0],
      futureTs
    );
  });

  it("Should quote", async () => {
    const address = await vPairFactoryInstance.getPair(
      tokenA.address,
      tokenB.address
    );
    const pool = await vPair.at(address);

    const input = web3.utils.toWei("14", "ether");

    const quote = await vRouterInstance.quote(
      tokenA.address,
      tokenB.address,
      input
    );

    const reserve0 = await pool.reserve0();
    const reserve1 = await pool.reserve1();

    const ratio = reserve0 / reserve1;
    assert.equal(quote / ratio, input, "Invalid quote");
  });

  it("Should add liquidity", async () => {
    let amountADesired = web3.utils.toWei("1", "ether");

    const amountBDesired = await vRouterInstance.quote(
      tokenA.address,
      tokenB.address,
      amountADesired
    );

    const pool = await vPair.at(
      await vPairFactoryInstance.getPair(tokenA.address, tokenB.address)
    );

    let reserve0 = await pool.reserve0();
    let reserve1 = await pool.reserve1();

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
      accounts[0],
      futureTs
    );

    reserve0 = await pool.reserve0();
    reserve1 = await pool.reserve1();

    let totalBalanceAfter0 = reserve0;
    let totalBalanceAfter1 = reserve1;

    expect(Number(totalBalanceBefore0.toString())).to.lessThan(
      Number(totalBalanceAfter0.toString())
    );

    expect(Number(totalBalanceBefore1.toString())).to.lessThan(
      Number(totalBalanceAfter1.toString())
    );
  });

  it("Should error when trying to provide unbalanced A amount", async function () {
    const amountADesired = web3.utils.toWei("12", "ether");

    const amountBDesired = web3.utils.toWei("10", "ether");
    const futureTs = await getFutureBlockTimestamp();
    await catchRevert(
      vRouterInstance.addLiquidity(
        tokenA.address,
        tokenB.address,
        amountADesired,
        amountBDesired,
        amountADesired,
        amountBDesired,
        accounts[0],
        futureTs
      )
    );
  });

  it("Should error when trying to provide unbalanced B amount", async function () {
    const amountADesired = web3.utils.toWei("1", "ether");

    const amountBDesired = web3.utils.toWei("3", "ether");
    const futureTs = await getFutureBlockTimestamp();
    await catchRevert(
      vRouterInstance.addLiquidity(
        tokenA.address,
        tokenB.address,
        amountADesired,
        amountBDesired,
        amountADesired,
        amountBDesired,
        accounts[0],
        futureTs
      )
    );
  });

  async function getFutureBlockTimestamp() {
    const blockNumber = await web3.eth.getBlockNumber();
    const block = await web3.eth.getBlock(blockNumber);
    return block.timestamp + 1000000;
  }

  it("Should (amountIn(amountOut(x)) = x)", async () => {
    const X = web3.utils.toWei("3", "ether");
    const fee = 997;

    const address = await vPairFactoryInstance.getPair(
      tokenA.address,
      tokenB.address
    );

    const pool = await vPair.at(address);

    const reserve0 = await pool.reserve0();
    const reserve1 = await pool.reserve1();

    const amountIn = await vRouterInstance.getAmountIn(
      tokenA.address,
      tokenB.address,
      tokenA.address,
      X
    );

    const amountOut = await vRouterInstance.getAmountOut(
      tokenA.address,
      tokenB.address,
      tokenA.address,
      amountIn
    );

    const amountOutEth = web3.utils.fromWei(amountOut, "ether") * 1;
    const xEth = web3.utils.fromWei(X, "ether") * 1;
    assert.equal(amountOutEth, xEth, "Invalid getAmountIn / getAmountOut");
  });

  function fromWeiToNumber(number) {
    return parseFloat(web3.utils.fromWei(number, "ether"));
  }

  it("Should remove liquidity", async () => {
    const poolAddress = await vPairFactoryInstance.getPair(
      tokenA.address,
      tokenB.address
    );
    const pool = await vPair.at(poolAddress);
    let lpBalanceBefore = await pool.balanceOf(accounts[0]);
    const tokenAInstance = await ERC20.at(tokenA.address);
    const tokenBInstance = await ERC20.at(tokenB.address);

    let tokenABalanceBefore = await tokenAInstance.balanceOf(accounts[0]);
    let tokenBBalanceBefore = await tokenBInstance.balanceOf(accounts[0]);

    const reserve0 = await pool.reserve0();
    const reserve1 = await pool.reserve1();

    await pool.approve(vRouterInstance.address, lpBalanceBefore);
    const futureTs = await getFutureBlockTimestamp();

    await vRouterInstance.removeLiquidity(
      tokenA.address,
      tokenB.address,
      lpBalanceBefore,
      reserve0,
      reserve1,
      accounts[0],
      futureTs
    );

    tokenABalanceBefore = fromWeiToNumber(tokenABalanceBefore);
    tokenBBalanceBefore = fromWeiToNumber(tokenBBalanceBefore);

    lpBalanceBefore = fromWeiToNumber(lpBalanceBefore);
    let lpBalanceAfter = await pool.balanceOf(accounts[0]);
    lpBalanceAfter = fromWeiToNumber(lpBalanceAfter);

    let tokenABalanceAfter = await tokenAInstance.balanceOf(accounts[0]);
    let tokenBBalanceAfter = await tokenBInstance.balanceOf(accounts[0]);

    tokenABalanceAfter = fromWeiToNumber(tokenABalanceAfter);
    tokenBBalanceAfter = fromWeiToNumber(tokenBBalanceAfter);

    expect(lpBalanceAfter).to.lessThan(lpBalanceBefore);
    expect(tokenABalanceBefore).to.lessThan(tokenABalanceAfter);
    expect(tokenBBalanceBefore).to.lessThan(tokenBBalanceAfter);
  });

  it("Should re-add liquidity", async () => {
    let amountADesired = web3.utils.toWei("10000", "ether");

    const amountBDesired = await vRouterInstance.quote(
      tokenA.address,
      tokenB.address,
      amountADesired
    );

    const pool = await vPair.at(
      await vPairFactoryInstance.getPair(tokenA.address, tokenB.address)
    );

    let reserve0 = await pool.reserve0();
    let reserve1 = await pool.reserve1();

    const futureTs = await getFutureBlockTimestamp();

    await vRouterInstance.addLiquidity(
      tokenA.address,
      tokenB.address,
      amountADesired,
      amountBDesired,
      amountADesired,
      amountBDesired,
      accounts[0],
      futureTs
    );

    let reserve0After = await pool.reserve0();
    let reserve1After = await pool.reserve1();

    let reserve0Eth, reserve1Eth, reserve0AfterEth, reserve1AfterEth;

    reserve0Eth = parseFloat(web3.utils.fromWei(reserve0, "ether"));
    reserve1Eth = parseFloat(web3.utils.fromWei(reserve1, "ether"));
    reserve0AfterEth = parseFloat(web3.utils.fromWei(reserve0After, "ether"));
    reserve1AfterEth = parseFloat(web3.utils.fromWei(reserve1After, "ether"));

    expect(reserve0Eth).to.lessThan(reserve0AfterEth);
    expect(reserve1Eth).to.lessThan(reserve1AfterEth);
  });

  it("Should remove 1/4 liquidity", async () => {
    const poolAddress = await vPairFactoryInstance.getPair(
      tokenA.address,
      tokenB.address
    );
    const pool = await vPair.at(poolAddress);
    let lpBalanceBefore = await pool.balanceOf(accounts[0]);
    const tokenAInstance = await ERC20.at(tokenA.address);
    const tokenBInstance = await ERC20.at(tokenB.address);

    let reserve0 = await pool.reserve0();
    let reserve1 = await pool.reserve1();

    reserve0 = fromWeiToNumber(reserve0);
    reserve1 = fromWeiToNumber(reserve1);

    const withdrawAmount = fromWeiToNumber(lpBalanceBefore) / 4;

    await pool.approve(vRouterInstance.address, lpBalanceBefore);

    //get account0 balance before
    let tokenABalanceBefore = await tokenAInstance.balanceOf(accounts[0]);
    let tokenBBalanceBefore = await tokenBInstance.balanceOf(accounts[0]);

    const tokenAMin = reserve0 / 4;
    const tokenBMin = reserve1 / 4;

    const futureTs = await getFutureBlockTimestamp();
    await vRouterInstance.removeLiquidity(
      tokenA.address,
      tokenB.address,
      web3.utils.toWei(withdrawAmount.toString(), "ether"),
      web3.utils.toWei(tokenAMin.toString(), "ether"),
      web3.utils.toWei(tokenBMin.toString(), "ether"),
      accounts[0],
      futureTs
    );

    //get account0 balance before
    let tokenABalanceAfter = await tokenAInstance.balanceOf(accounts[0]);
    let tokenBBalanceAfter = await tokenBInstance.balanceOf(accounts[0]);

    tokenABalanceBefore = fromWeiToNumber(tokenABalanceBefore);
    tokenBBalanceBefore = fromWeiToNumber(tokenBBalanceBefore);
    tokenABalanceAfter = fromWeiToNumber(tokenABalanceAfter);
    tokenBBalanceAfter = fromWeiToNumber(tokenBBalanceAfter);

    let reserve0After = await pool.reserve0();
    let reserve1After = await pool.reserve1();

    reserve0After = fromWeiToNumber(reserve0After);
    reserve1After = fromWeiToNumber(reserve1After);

    expect(tokenABalanceAfter).to.be.above(tokenABalanceBefore);
    expect(tokenBBalanceAfter).to.be.above(tokenBBalanceBefore);

    assert.equal(
      reserve0 * 0.75,
      reserve0After,
      "Pool reserve did not decrease by 1/4"
    );

    assert.equal(
      reserve1 * 0.75,
      reserve1After,
      "Pool reserve did not decrease by 1/4"
    );
  });

  it("Should swap total pool A/C with 2 transaction - 1. Real pool A/C 2. Virtual Pool (B/C , A/B)", async () => {
    const pool1 = await vPair.at(
      await vPairFactoryInstance.getPair(tokenA.address, tokenC.address) // BTC, USDC
    );
    const pool2 = await vPair.at(
      await vPairFactoryInstance.getPair(tokenB.address, tokenC.address) // ETH, USDC
    );
    const pool3 = await vPair.at(
      await vPairFactoryInstance.getPair(tokenA.address, tokenB.address) // BTC, ETH
    );
    let pools = [pool1.address, pool2.address];
    let amountsIn = ["0.043", "0.957"];
    let amountsOut = ["810.918", "20207.008"];
    let amountsInWei = [];
    let amountsOutWei = [];
    let iks = ["0x0000000000000000000000000000000000000000", pool3.address];

    for (let i = 0; i < amountsIn.length; i++) {
      amountsInWei.push(web3.utils.toWei(amountsIn[i], "ether"));
    }
    for (let i = 0; i < amountsOut.length; i++) {
      amountsOutWei.push(web3.utils.toWei(amountsOut[i], "ether"));
    }

    const futureTs = await getFutureBlockTimestamp();
    await vRouterInstance.swap(
      pools,
      amountsInWei,
      amountsOutWei,
      iks,
      tokenA.address,
      tokenC.address,
      accounts[0],
      futureTs
    );
  });
});
