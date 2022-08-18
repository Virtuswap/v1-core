import { loadFixture } from "@nomicfoundation/hardhat-network-helpers";
import { expect } from "chai";
import { deployPools } from "./fixtures/deployPools";

describe("Base actions", function () {
  it("Should deploy fixture", async function () {
    const fixture = await loadFixture(deployPools);

    expect(fixture.tokenA.address.length > 0);
    expect(fixture.tokenB.address.length > 0);
    expect(fixture.tokenC.address.length > 0);
    expect(fixture.vRouterInstance.address.length > 0);
    expect(fixture.vPairFactoryInstance.address.length > 0);
    expect(fixture.abPool.address.length > 0);
    expect(fixture.bcPool.address.length > 0);
    expect(fixture.acPool.address.length > 0);
  });

  it("Validate INIT_HASH_CODE", async function () {
    const fixture = await loadFixture(deployPools);
    let hashCode = await fixture.vPairFactoryInstance.getInitCodeHash();
    expect(hashCode).to.equal(
      "0xe938ca8d38879668d9ae583acd07e1dad77a26c33dd58d3c46605c36a33180cf"
    );
  });
  it("Calculate A/B pair address", async function () {
    const fixture = await loadFixture(deployPools);
    let abPoolAddressCalc = await fixture.vRouterInstance.calculatePoolAddress(
      fixture.tokenA.address,
      fixture.tokenB.address
    );

    let abPoolAddress = await fixture.vPairFactoryInstance.getPair(
      fixture.tokenA.address,
      fixture.tokenB.address
    );
    expect(abPoolAddress).to.equal(abPoolAddressCalc);
  });
});
