const { assert } = require("chai");

const vRouter = artifacts.require("vRouter");
const vPair = artifacts.require("vPair");
const vPairFactory = artifacts.require("vPairFactory");
const vSwapLibrary = artifacts.require("vSwapLibrary");
const PoolAddress = artifacts.require("PoolAddress");

const ERC20 = artifacts.require("ERC20PresetFixedSupply");

contract("Base", (accounts) => {
  function fromWeiToNumber(number) {
    return parseFloat(web3.utils.fromWei(number, "ether")).toFixed(6) * 1;
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

  let vPairFactoryInstance,
    vRouterInstance,
    vSwapLibraryInstance,
    PoolAddressInstance;

  before(async () => {
    tokenA = await ERC20.new("tokenA", "A", issueAmount, accounts[0]);

    tokenB = await ERC20.new("tokenB", "B", issueAmount, accounts[0]);

    tokenC = await ERC20.new("tokenC", "C", issueAmount, accounts[0]);

    tokenD = await ERC20.new("tokenD", "D", issueAmount, accounts[0]);

    vPairFactoryInstance = await vPairFactory.deployed();
    vRouterInstance = await vRouter.deployed();
    vSwapLibraryInstance = await vSwapLibrary.deployed();
    vSwapLibraryInstance = await vSwapLibrary.deployed();
    PoolAddressInstance = await PoolAddress.deployed();

    await tokenA.approve(vRouterInstance.address, issueAmount);
    await tokenB.approve(vRouterInstance.address, issueAmount);
    await tokenC.approve(vRouterInstance.address, issueAmount);
  });

  it("Should create pool vFactory", async () => {
    await vPairFactoryInstance.createPair(tokenA.address, tokenB.address);

    let pairAddress = await vPairFactoryInstance.getPair(
      tokenA.address,
      tokenB.address
    );

    assert(pairAddress > 0);
  });

  it("Should compute tokenA / tokenB pool address", async () => {
    let poolAddress = await vPairFactoryInstance.getPair(
      tokenA.address,
      tokenB.address
    );
    let calculated = await PoolAddressInstance.computeAddress(
      vPairFactoryInstance.address,
      tokenA.address,
      tokenB.address
    );

    assert.equal(poolAddress, calculated);
  });

  it("Should create pool vRouter", async () => {
    const futureTs = await getFutureBlockTimestamp();

    //create pool A/B with 10,000 A and equivalent B
    let AInput = 10000 * A_PRICE;
    let BInput = (B_PRICE / A_PRICE) * AInput;

    await vRouterInstance.addLiquidity(
      tokenB.address,
      tokenC.address,
      web3.utils.toWei(AInput.toString(), "ether"),
      web3.utils.toWei(BInput.toString(), "ether"),
      web3.utils.toWei(AInput.toString(), "ether"),
      web3.utils.toWei(BInput.toString(), "ether"),
      accounts[0],
      futureTs
    );
  });
});
