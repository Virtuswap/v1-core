const vRouter = artifacts.require("vRouter");
const vPair = artifacts.require("vPair");
const vPairFactory = artifacts.require("vPairFactory");
const vSwapMath = artifacts.require("vSwapMath");
const ERC20 = artifacts.require("ERC20PresetFixedSupply");
const ZERO_ADDRESS = "0x0000000000000000000000000000000000000000";
const { catchRevert } = require("./exceptions");

contract("vSwapMath", (accounts) => {
  let tokenA, tokenB, tokenC, WETH;

  const issueAmount = web3.utils.toWei("1000000", "ether");

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

    //create pool A/B
    await vRouterInstance.addLiquidity(
      tokenA.address,
      tokenB.address,
      web3.utils.toWei("10", "ether"),
      web3.utils.toWei("100", "ether"),
      web3.utils.toWei("10", "ether"),
      web3.utils.toWei("100", "ether"),
      accounts[0],
      new Date().getTime() + 1000 * 60 * 60
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
      new Date().getTime() + 1000 * 60 * 60
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
      new Date().getTime() + 1000 * 60 * 60
    );
  });
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

    const amountIn = await vSwapMathInstance.getAmountIn(
      X,
      reserve0,
      reserve1,
      fee
    );

    const amountOut = await vSwapMathInstance.getAmountOut(
      amountIn,
      reserve0,
      reserve1,
      fee
    );

    assert.equal(amountOut, X, "Invalid getAmountIn / getAmountOut");
  });

  it("Should find common token and assing to ik1 and jk1", async () => {
    let tokens = await vSwapMathInstance.findCommonToken(
      tokenA.address,
      tokenB.address,
      tokenC.address,
      tokenB.address
    );

    assert.equal(tokens.ik1, tokens.jk1, "ik1 not equal to jk1");

    tokens = await vSwapMathInstance.findCommonToken(
      tokenB.address,
      tokenA.address,
      tokenA.address,
      tokenC.address
    );

    assert.equal(tokens.ik1, tokens.jk1, "ik1 not equal to jk1");

    tokens = await vSwapMathInstance.findCommonToken(
      tokenC.address,
      tokenA.address,
      tokenB.address,
      tokenC.address
    );

    assert.equal(tokens.ik1, tokens.jk1, "ik1 not equal to jk1");

    tokens = await vSwapMathInstance.findCommonToken(
      tokenC.address,
      tokenA.address,
      tokenC.address,
      tokenB.address
    );

    assert.equal(tokens.ik1, tokens.jk1, "ik1 not equal to jk1");
  });
});
