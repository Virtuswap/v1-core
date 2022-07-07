const {toDecimalUnits} = require("./utils");
const vPairFactory = artifacts.require("vPairFactory");
const vPair = artifacts.require('vPair')
const ERC20 = artifacts.require('ERC20')

contract('vPairFactory', (accounts) => {

	it('Creates and adds a new pair', async () => {
		const vPairFactoryInstance = await vPairFactory.deployed();

		let tokenA = await ERC20.new("tokenA", "A", toDecimalUnits(18, 1000));
		let tokenB = await ERC20.new("tokenB", "B", toDecimalUnits(18, 1000));
		let lengthBefore = (await vPairFactoryInstance.allPairsLength()).toNumber();

		await vPairFactoryInstance.createPair(tokenA.address, tokenB.address);
		let createdPair = await vPairFactoryInstance.getPair(tokenA.address, tokenB.address);
		let pair = await vPair.at(createdPair);
		expect(lengthBefore + 1).to.equal((await vPairFactoryInstance.allPairsLength()).toNumber());
		expect(pair.address).to.equal(createdPair)
	});
	
});
