const { assert } = require("chai");

const vRouter = artifacts.require("vRouter");
const vPair = artifacts.require("vPair");
const vPairFactory = artifacts.require("vPairFactory");
const vSwapLibrary = artifacts.require("vSwapLibrary");
const PoolAddress = artifacts.require("PoolAddress");

const ERC20 = artifacts.require("ERC20PresetFixedSupply");

contract("Pool address", (accounts) => {
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
    console.log("AB address: " + address);
    const pool = await vPair.at(address);

    //whitelist token C
    await pool.setWhitelist([tokenC.address]);

    let reserve0 = await pool.reserve0();
    let reserve1 = await pool.reserve1();

    reserve0 = fromWeiToNumber(reserve0);
    reserve1 = fromWeiToNumber(reserve1);

    // console.log("pool1: A/B: " + reserve0 + "/" + reserve1);

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

    // console.log("pool2: A/C: " + reserve0Pool2 + "/" + reserve1Pool2);

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

    // console.log("pool3: B/C: " + reserve0Pool3 + "/" + reserve1Pool3);
  });

  function buildCreate2Address(creatorAddress, saltHex, byteCode) {
    return `0x${web3.utils
      .sha3(
        `0x${["ff", creatorAddress, saltHex, web3.utils.sha3(byteCode)]
          .map((x) => x.replace(/0x/, ""))
          .join("")}`
      )
      .slice(-40)}`.toLowerCase();
  }

  it("Should assure PoolAddress POOL_INIT_CODE_HASH is correct", async () => {
    let INIT_CODE_HASH = await PoolAddressInstance.POOL_INIT_CODE_HASH();
    let calculated = await vPairFactoryInstance.getInitCodeHash();

    let calculated2 = await PoolAddressInstance.getInitCodeHash();

    console.log("INIT_CODE_HASH: " + INIT_CODE_HASH);
    console.log("calculated: " + calculated);
    console.log("calculated2: " + calculated2);

    let calculated3 = await PoolAddressInstance._computeAddress(
      vPairFactoryInstance.address,
      tokenA.address,
      tokenB.address
    );

    console.log("calculated3: " + calculated3);

    assert.equal(INIT_CODE_HASH, calculated);
  });



  it("Should compute tokenA / tokenB pool address", async () => {



    let poolAddress = await vPairFactoryInstance.getPair(
      tokenA.address,
      tokenB.address
    );
    console.log("poolAddress: " + poolAddress);

    let calculated = await PoolAddressInstance.computeAddress(
      vPairFactoryInstance.address,
      tokenA.address,
      tokenB.address
    );

    console.log("calculated: " + calculated);

    let calculated2 = await PoolAddressInstance.computeAddress2(
      vPairFactoryInstance.address,
      tokenA.address,
      tokenB.address
    );

    console.log("calculated2: " + calculated2);

    let calculated3 = await PoolAddressInstance.computeAddress3(
      vPairFactoryInstance.address,
      tokenA.address,
      tokenB.address
    );

    console.log("calculated3: " + calculated3);

    let calculated4 = await PoolAddressInstance.computeAddress4(
      vPairFactoryInstance.address,
      tokenA.address,
      tokenB.address
    );

    console.log("calculated4: " + calculated4);

  });
});
