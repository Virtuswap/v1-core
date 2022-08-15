import { time, loadFixture } from "@nomicfoundation/hardhat-network-helpers";
import { expect } from "chai";
import { ethers } from "hardhat";
import {
  ERC20PresetFixedSupply__factory,
  VPairFactory__factory,
  VPair__factory,
  VRouter__factory,
} from "../typechain-types";

const ONE_GWEI = 1_000_000_000;

describe("Pool address", function () {
  // We define a fixture to reuse the same setup in every test.
  // We use loadFixture to run this setup once, snapshot that state,
  // and reset Hardhat Network to that snapshot in every test.
  async function deployPools() {
    const issueAmount = ethers.utils.parseEther(
      "100000000000000000000000000000000000"
    );

    console.log("issueAmount " + issueAmount);
    // Contracts are deployed using the first signer/account by default
    const [owner, otherAccount] = await ethers.getSigners();

    const A_PRICE = 1;
    const B_PRICE = 3;
    const C_PRICE = 6;

    const erc20ContractFactory = await new ERC20PresetFixedSupply__factory(
      owner
    );
    const tokenA = await erc20ContractFactory.deploy(
      "tokenA",
      "A",
      issueAmount,
      owner.address
    );
    const tokenB = await erc20ContractFactory.deploy(
      "tokenB",
      "B",
      issueAmount,
      owner.address
    );
    const tokenC = await erc20ContractFactory.deploy(
      "tokenC",
      "C",
      issueAmount,
      owner.address
    );

    const vPairFactoryInstance = await new VPairFactory__factory(
      VPairFactory__factory.createInterface(),
      VPairFactory__factory.bytecode,
      owner
    ).deploy();
    const vRouterInstance = await new VRouter__factory(
      VRouter__factory.createInterface(),
      VRouter__factory.bytecode,
      owner
    ).deploy(vPairFactoryInstance.address);

    await tokenA.approve(vRouterInstance.address, issueAmount);
    await tokenB.approve(vRouterInstance.address, issueAmount);
    await tokenC.approve(vRouterInstance.address, issueAmount);

    let balance = await tokenA.balanceOf(owner.address);
    console.log("owner bALANCE " + balance);

    const futureTs = (await time.latest()) + 1000000;

    // create pool A/B with 10,000 A and equivalent B
    let AInput = 10000 * A_PRICE;
    let BInput = (B_PRICE / A_PRICE) * AInput;
    console.log("1");
    await vRouterInstance.addLiquidity(
      tokenA.address,
      tokenB.address,
      ethers.utils.parseEther(AInput.toString()),
      ethers.utils.parseEther(BInput.toString()),
      ethers.utils.parseEther(AInput.toString()),
      ethers.utils.parseEther(BInput.toString()),
      owner.address,
      futureTs
    );
    console.log("2");
    // create pool A/C
    // create pool A/C with 10,000 A and equivalent C
    let CInput = (C_PRICE / A_PRICE) * AInput;
    await vRouterInstance.addLiquidity(
      tokenA.address,
      tokenC.address,
      ethers.utils.parseEther(AInput.toString()),
      ethers.utils.parseEther(CInput.toString()),
      ethers.utils.parseEther(AInput.toString()),
      ethers.utils.parseEther(CInput.toString()),
      owner.address,
      futureTs
    );

    // create pool B/C
    // create pool B/C with 20,000 B and equivalent C
    BInput = 20000 * B_PRICE;
    CInput = (C_PRICE / B_PRICE) * BInput;
    await vRouterInstance.addLiquidity(
      tokenB.address,
      tokenC.address,
      ethers.utils.parseEther(BInput.toString()),
      ethers.utils.parseEther(CInput.toString()),
      ethers.utils.parseEther(BInput.toString()),
      ethers.utils.parseEther(CInput.toString()),
      owner.address,
      futureTs
    );

    // whitelist tokens in pools

    // pool 1
    const address1 = await vPairFactoryInstance.getPair(
      tokenA.address,
      tokenB.address
    );
    console.log("AB address: " + address1);
    const pool1 = await VPair__factory.connect(address1, owner);

    // whitelist token C
    pool1.setWhitelist([tokenC.address]);

    const reserve0Pool1 = await pool1.reserve0();
    const reserve1Pool1 = await pool1.reserve1();

    const pool1Reserve0 = ethers.utils.formatEther(reserve0Pool1);
    const pool1Reserve1 = ethers.utils.formatEther(reserve1Pool1);

    console.log("pool1: A/B: " + pool1Reserve0 + "/" + pool1Reserve1);

    // pool 2
    const address2 = await vPairFactoryInstance.getPair(
      tokenA.address,
      tokenC.address
    );
    console.log("AC address: " + address2);
    const pool2 = VPair__factory.connect(address2, owner);

    // whitelist token B
    await pool2.setWhitelist([tokenB.address]);

    const reserve0Pool2 = await pool2.reserve0();
    const reserve1Pool2 = await pool2.reserve1();

    const pool2Reserve0 = ethers.utils.formatEther(reserve0Pool2);
    const pool2Reserve1 = ethers.utils.formatEther(reserve1Pool2);

    console.log("pool2: A/C: " + pool2Reserve0 + "/" + pool2Reserve1);

    // pool 3
    const address3 = await vPairFactoryInstance.getPair(
      tokenB.address,
      tokenC.address
    );
    console.log("BC address: " + address3);
    const pool3 = VPair__factory.connect(address3, owner);

    // whitelist token A
    await pool3.setWhitelist([tokenA.address]);

    const reserve0Pool3 = await pool3.reserve0();
    const reserve1Pool3 = await pool3.reserve1();

    const pool3Reserve0 = ethers.utils.formatEther(reserve0Pool3);
    const pool3Reserve1 = ethers.utils.formatEther(reserve1Pool3);

    console.log("pool3: B/C: " + pool3Reserve0 + "/" + pool3Reserve1);
    return {
      tokenA,
      tokenB,
      tokenC,
      A_PRICE,
      B_PRICE,
      C_PRICE,
      pool1,
      pool2,
      pool3,
      pool1Reserve0,
      pool1Reserve1,
      pool2Reserve0,
      pool2Reserve1,
      pool3Reserve0,
      pool3Reserve1,
      vRouterInstance,
      owner,
      otherAccount,
      vPairFactoryInstance,
    };
  }

  describe("Deployment", function () {
    it("Should calculate virtual pool A/C using pool A/C", async function () {
      const {
        A_PRICE,
        B_PRICE,
        tokenA,
        tokenB,
        tokenC,
        vRouterInstance,
        vPairFactoryInstance,
      } = await loadFixture(deployPools);

      const ik = await vPairFactoryInstance.getPair(
        tokenA.address,
        tokenC.address
      );

      const jk = await vPairFactoryInstance.getPair(
        tokenC.address,
        tokenB.address
      );

      const vPool = await vRouterInstance.getVirtualPool(jk, ik);

      let reserve0 = parseFloat(ethers.utils.formatEther(vPool.reserve0));
      let reserve1 = parseFloat(ethers.utils.formatEther(vPool.reserve1));

      expect(reserve0 / reserve1).to.equal(A_PRICE / B_PRICE);
      expect(vPool.token0 == tokenA.address);
      expect(vPool.token1 == tokenB.address);
    });
  });
});
