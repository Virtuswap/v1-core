import { time } from '@nomicfoundation/hardhat-network-helpers';
import { ethers } from 'hardhat';
import {
    ERC20PresetFixedSupply__factory,
    VPairFactory__factory,
    VPair__factory,
    VRouter__factory,
    VExchangeReserves__factory,
    WETH9__factory,
} from '../../typechain-types/index';

// We define a fixture to reuse the same setup in every test.
// We use loadFixture to run this setup once, snapshot that state,
// and reset Hardhat Network to that snapshot in every test.
export async function reserveRatioManipulation() {
    console.log('==================');
    console.log('Reserve ratio manipulation fixture');
    console.log('==================');

    const issueAmount = ethers.utils.parseEther(
        '100000000000000000000000000000000000'
    );

    // Contracts are deployed using the first signer/account by default
    const [owner] = await ethers.getSigners();

    const A_PRICE = 1;
    const B_PRICE = 3;
    const C_PRICE = 6;
    const D_PRICE = 9;

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
    const tokenC = await erc20ContractFactory.deploy(
        'tokenC',
        'C',
        issueAmount,
        owner.address
    );

    const tokenD = await erc20ContractFactory.deploy(
        'tokenD',
        'D',
        issueAmount,
        owner.address
    );

    const WETH9ContractFactory = await ethers.getContractFactory('WETH9');
    const WETH9Instance = await WETH9ContractFactory.deploy();

    const vPairContractFactory = await ethers.getContractFactory(
        'vPairFactory'
    );
    const vPairFactoryInstance = await vPairContractFactory.deploy();

    await vPairFactoryInstance.setDefaultAllowList([
        tokenA.address,
        tokenB.address,
        tokenC.address,
        tokenD.address,
    ]);

    const vRouterContractFactory = await ethers.getContractFactory('vRouter');
    const vRouterInstance = await vRouterContractFactory.deploy(
        vPairFactoryInstance.address,
        WETH9Instance.address
    );

    await tokenA.approve(vRouterInstance.address, issueAmount);
    await tokenB.approve(vRouterInstance.address, issueAmount);
    await tokenC.approve(vRouterInstance.address, issueAmount);
    await tokenD.approve(vRouterInstance.address, issueAmount);

    const futureTs = (await time.latest()) + 1000000;

    await vRouterInstance.addLiquidity(
        tokenA.address,
        tokenB.address,
        ethers.utils.parseEther('100'),
        ethers.utils.parseEther('100'),
        ethers.utils.parseEther('100'),
        ethers.utils.parseEther('100'),
        owner.address,
        futureTs
    );

    //create pool A/C
    //create pool A/B with 10,000 A and equivalent C

    await vRouterInstance.addLiquidity(
        tokenA.address,
        tokenC.address,
        ethers.utils.parseEther('50'),
        ethers.utils.parseEther('200'),
        ethers.utils.parseEther('50'),
        ethers.utils.parseEther('200'),
        owner.address,
        futureTs
    );

    //create pool B/C
    //create pool B/C with 10,000 B and equivalent C

    await vRouterInstance.addLiquidity(
        tokenB.address,
        tokenC.address,
        ethers.utils.parseEther('50'),
        ethers.utils.parseEther('200'),
        ethers.utils.parseEther('50'),
        ethers.utils.parseEther('200'),
        owner.address,
        futureTs
    );

    //whitelist tokens in pools

    //pool 1
    const abAddress = await vPairFactoryInstance.getPair(
        tokenA.address,
        tokenB.address
    );

    const abPool = VPair__factory.connect(abAddress, owner);

    // whitelist token C
    await abPool.setMaxReserveThreshold(ethers.utils.parseEther('100000'));
    //whitelist token C
    await abPool.setAllowList([tokenC.address, tokenD.address]);

    //pool 2
    const acAddress = await vPairFactoryInstance.getPair(
        tokenA.address,
        tokenC.address
    );
    const acPool = VPair__factory.connect(acAddress, owner);

    //whitelist token B
    await acPool.setAllowList([tokenB.address, tokenD.address]);
    await acPool.setMaxReserveThreshold(ethers.utils.parseEther('100000'));

    //pool 3
    const bcAddress = await vPairFactoryInstance.getPair(
        tokenB.address,
        tokenC.address
    );
    const bcPool = VPair__factory.connect(acAddress, owner);

    //whitelist token A
    await bcPool.setAllowList([tokenA.address, tokenD.address]);
    await bcPool.setMaxReserveThreshold(ethers.utils.parseEther('100000'));

    // console.log("pool3: B/C: " + reserve0Pool3 + "/" + reserve1Pool3);

    return {
        tokenA,
        tokenB,
        tokenC,
        tokenD,
        A_PRICE,
        B_PRICE,
        C_PRICE,
        D_PRICE,
        abPool,
        bcPool,
        acPool,
        vRouterInstance,
        owner,
        vPairFactoryInstance,
    };
}
