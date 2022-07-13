const {solidity} =  require('ethereum-waffle');
const chai = require('chai');
const vPair = artifacts.require('vPair')
const vPairFactory = artifacts.require("vPairFactory");
const ERC20 = artifacts.require('ERC20PresetFixedSupply')
const { toDecimalUnits, toBn } = require("./utils");

chai.use(solidity);
const { expect } = chai;

contract('vPairFactory', (accounts) => {
	const wallet = accounts[0];
  	const zeroAddress = "0x0000000000000000000000000000000000000000";

	it('[SUCCESS] Creates and adds a new pair', async () => {
		const vPairFactoryInstance = await vPairFactory.deployed();

		let tokenA = await ERC20.new("tokenA", "A", toBn(18, 1000000), wallet);
		let tokenB = await ERC20.new("tokenB", "B", toBn(18, 1000000), wallet);
		let lengthBefore = (await vPairFactoryInstance.allPairsLength()).toNumber();

		await vPairFactoryInstance.createPair(tokenA.address, tokenB.address);
		let createdPair = await vPairFactoryInstance.getPair(tokenA.address, tokenB.address);
		let pair = await vPair.at(createdPair);
		expect(lengthBefore + 1).to.equal((await vPairFactoryInstance.allPairsLength()).toNumber());
		expect(pair.address).to.equal(createdPair)
	});

	it('[FAIL] Creates new pair wit the same token', async () => {
		const vPairFactoryInstance = await vPairFactory.deployed();

		let tokenA = await ERC20.new("tokenA", "A", toBn(18, 1000000), wallet);

		await expect(vPairFactoryInstance.createPair(tokenA.address, tokenA.address)).to.revertedWith('VSWAP: IDENTICAL_ADDRESSES');
	});

	it('[FAIL] Creates already exists pair', async () => {
		const vPairFactoryInstance = await vPairFactory.deployed();

		let tokenA = await ERC20.new("tokenA", "A", toBn(18, 1000000), wallet);
		let tokenB = await ERC20.new("tokenB", "B", toBn(18, 1000000), wallet);

		await vPairFactoryInstance.createPair(tokenA.address, tokenB.address);

		//try to create the same pair second time 
		await expect(vPairFactoryInstance.createPair(tokenA.address, tokenB.address)).to.revertedWith('VSWAP: PAIR_EXISTS');
	});

	it('[FAIL] Creates new pair with zero token address', async () => {
		const vPairFactoryInstance = await vPairFactory.deployed();

		let tokenA = await ERC20.new("tokenA", "A", toBn(18, 1000000), wallet);

		// try to create the new pair with zero address
		await expect(vPairFactoryInstance.createPair(tokenA.address, zeroAddress)).to.revertedWith('VSWAP: ZERO_ADDRESS');
	});
});
