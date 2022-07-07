const { toDecimalUnits } = require("./utils");

const vPair = artifacts.require('vPair')
const ERC20 = artifacts.require('ERC20')
const vPairFactory = artifacts.require('vPairFactory')
contract('vPair',  (accounts) => {
    let tokenA, tokenB;
    let vPairFactoryInstance, vPairInstance;
    const wallet = accounts[0]
    beforeEach(async () => {
        tokenA = await ERC20.new("tokenA", "A", toDecimalUnits(18, 1000));
        tokenB = await ERC20.new("tokenB", "B", toDecimalUnits(18, 1000));
        vPairFactoryInstance = await vPairFactory.deployed();
        await vPairFactoryInstance.createPair(tokenA.address, tokenB.address);
        let createdPair = await vPairFactoryInstance.getPair(tokenA.address, tokenB.address);
        vPairInstance = await vPair.at(createdPair);
        await tokenA.transfer(vPairInstance.address, toDecimalUnits(18, 100))
        await tokenB.transfer(vPairInstance.address, toDecimalUnits(18, 300))
    })


    it("mints lp tokens", async() => {
        await vPairInstance.mint(wallet)
    })
});