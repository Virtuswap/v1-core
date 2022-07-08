const { toDecimalUnits } = require("./utils");

const vPair = artifacts.require('vPair')
const ERC20 = artifacts.require('ERC20PresetFixedSupply')
const vPairFactory = artifacts.require('vPairFactory')
contract('vPair',  (accounts) => {
    let tokenA, tokenB;
    let vPairFactoryInstance, vPairInstance;
    const wallet = accounts[0]
    beforeEach(async () => {
        tokenA = await ERC20.new("tokenA", "A", toDecimalUnits(18, 1000000), wallet);
        tokenB = await ERC20.new("tokenB", "B", toDecimalUnits(18, 1000000), wallet)
        vPairFactoryInstance = await vPairFactory.deployed();
        await vPairFactoryInstance.createPair(tokenA.address, tokenB.address);
        let createdPair = await vPairFactoryInstance.getPair(tokenA.address, tokenB.address);
        vPairInstance = await vPair.at(createdPair);
        tokenA.approve(wallet, toDecimalUnits(18, 1000000))
        tokenB.approve(wallet, toDecimalUnits(18, 1000000))
        await tokenA.transferFrom(wallet, vPairInstance.address, toDecimalUnits(18, 100))
        await tokenB.transferFrom(wallet, vPairInstance.address, toDecimalUnits(18, 300))
    })


    it("mints lp tokens", async() => {
        await vPairInstance.mint(wallet)
        console.log((await vPairInstance.balanceOf(wallet)).toString())
    })


});