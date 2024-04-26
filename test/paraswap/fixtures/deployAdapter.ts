import { ethers } from 'hardhat';
import { time } from '@nomicfoundation/hardhat-network-helpers';
import {
    ERC20PresetFixedSupply__factory,
    WETH9__factory,
    VRouterMock__factory,
    VirtuSwapAdapter__factory,
} from '../../../typechain-types';

// We define a fixture to reuse the same setup in every test.
// We use loadFixture to run this setup once, snapshot that state,
// and reset Hardhat Network to that snapshot in every test.
export async function deployAdapter() {
    console.log('=====================');
    console.log('deployAdapter Fixture');
    console.log('=====================');

    const issueAmount = ethers.utils.parseEther(
        '100000000000000000000000000000000000'
    );

    // Contracts are deployed using the first signer/account by default
    const [owner, ...accounts] = await ethers.getSigners();

    const erc20ContractFactory = await new ERC20PresetFixedSupply__factory(
        owner
    );
    const tokenA = await erc20ContractFactory.deploy(
        'tokenA',
        'A',
        issueAmount,
        owner.address
    );
    const tokenB = await erc20ContractFactory.deploy(
        'tokenB',
        'B',
        issueAmount,
        owner.address
    );

    const WETH9ContractFactory = await new WETH9__factory(owner);
    const weth9 = await WETH9ContractFactory.deploy();

    await weth9.deposit({ value: ethers.utils.parseEther('1000') });

    const vRouterMockContractFactory = await new VRouterMock__factory(owner);
    const vRouterMock = await vRouterMockContractFactory.deploy();

    const adapterContractFactory = await new VirtuSwapAdapter__factory(owner);
    const adapter = await adapterContractFactory.deploy();

    await tokenA.approve(adapter.address, issueAmount);
    await tokenB.approve(adapter.address, issueAmount);

    const deadline = (await time.latest()) + 1000000;

    return {
        tokenA,
        tokenB,
        weth9,
        owner,
        accounts,
        vRouterMock,
        adapter,
        deadline,
    };
}
