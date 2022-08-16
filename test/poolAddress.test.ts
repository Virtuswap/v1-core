import { loadFixture } from "@nomicfoundation/hardhat-network-helpers";
import { expect } from "chai";
import { ethers } from "hardhat";
import { deployPools } from "../fixtures/deployPools";

describe("Pool address", function () {

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
