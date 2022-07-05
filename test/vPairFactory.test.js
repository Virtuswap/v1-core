const vPairFactory = artifacts.require("vPairFactory");
const vPair = artifacts.require('vPair')

contract('vPairFactory', (accounts) => {

	it('Creates and adds a new pair', async () => {
		const vPairFactoryInstance = await vPairFactory.deployed();

		const tokenA = accounts[0];
		const tokenB = accounts[1];
		let lengthBefore = (await vPairFactoryInstance.allPairsLength()).toNumber();

		await vPairFactoryInstance.createPair(tokenA, tokenB);

		expect(lengthBefore + 1).to.equal((await vPairFactoryInstance.allPairsLength()).toNumber());

	});
	
});
