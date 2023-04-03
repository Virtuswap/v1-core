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
export async function deployPools() {
    console.log('==================');
    console.log('deployPool Fixture');
    console.log('==================');

    const issueAmount = ethers.utils.parseEther(
        '100000000000000000000000000000000000'
    );

    // Contracts are deployed using the first signer/account by default
    const [
        owner,
        account1,
        account2,
        account3,
        account4,
        account5,
        account6,
        account7,
        account8,
        account9,
        account10,
    ] = await ethers.getSigners();

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

    await WETH9Instance.deposit({ value: ethers.utils.parseEther('1000') });

    const vPairContractFactory = await ethers.getContractFactory(
        'vPairFactory'
    );
    const vPairFactoryInstance = await vPairContractFactory.deploy();

    const vRouterContractFactory = await ethers.getContractFactory('vRouter');
    const vRouterInstance = await vRouterContractFactory.deploy(
        vPairFactoryInstance.address,
        WETH9Instance.address
    );

    const vExchangeReserveContractFactory = await ethers.getContractFactory(
        'vExchangeReserves'
    );
    const exchageReserveInstance = await vExchangeReserveContractFactory.deploy(
        vPairFactoryInstance.address
    );

    const vPoolManagerFactory = await ethers.getContractFactory('vPoolManager');
    const vPoolManagerInstance = await vPoolManagerFactory.deploy(
        vPairFactoryInstance.address
    );

    await vPairFactoryInstance.setVPoolManagerAddress(
        vPoolManagerInstance.address
    );

    await vPairFactoryInstance.setDefaultAllowList([
        tokenA.address,
        tokenB.address,
        tokenC.address,
        tokenD.address,
        tokenA.address,
        tokenB.address,
        tokenC.address,
        tokenD.address,
    ]);

    await tokenA.approve(vRouterInstance.address, issueAmount);
    await tokenB.approve(vRouterInstance.address, issueAmount);
    await tokenC.approve(vRouterInstance.address, issueAmount);
    await tokenD.approve(vRouterInstance.address, issueAmount);

    const futureTs = (await time.latest()) + 1000000;

    // create pool A/B with 10,000 A and equivalent B
    let AInput = 10000 * A_PRICE;
    let BInput = (B_PRICE / A_PRICE) * AInput;

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

    // create pool B/D
    // create pool B/D with 20,000 B and equivalent C
    BInput = 20000 * B_PRICE;
    let DInput = (D_PRICE / B_PRICE) * BInput;
    await vRouterInstance.addLiquidity(
        tokenB.address,
        tokenD.address,
        ethers.utils.parseEther(BInput.toString()),
        ethers.utils.parseEther(DInput.toString()),
        ethers.utils.parseEther(BInput.toString()),
        ethers.utils.parseEther(DInput.toString()),
        owner.address,
        futureTs
    );

    // create pool WETH9/B
    let WETH9Input = 1000;
    BInput = 2000;

    await vRouterInstance.addLiquidity(
        WETH9Instance.address,
        tokenB.address,
        ethers.utils.parseEther(WETH9Input.toString()),
        ethers.utils.parseEther(BInput.toString()),
        ethers.utils.parseEther(WETH9Input.toString()),
        ethers.utils.parseEther(BInput.toString()),
        owner.address,
        futureTs
    );

    // whitelist tokens in pools

    // pool 1
    const address1 = await vPairFactoryInstance.getPair(
        tokenA.address,
        tokenB.address
    );
    console.log('AB address: ' + address1);
    const abPool = VPair__factory.connect(address1, owner);

    // whitelist token C
    // await abPool.setAllowList([tokenC.address]);

    const reserve0Pool1 = await abPool.pairBalance0();
    const reserve1Pool1 = await abPool.pairBalance1();

    const pool1Reserve0 = ethers.utils.formatEther(reserve0Pool1);
    const pool1Reserve1 = ethers.utils.formatEther(reserve1Pool1);

    console.log('pool1: A/B: ' + pool1Reserve0 + '/' + pool1Reserve1);

    // pool 2
    const address2 = await vPairFactoryInstance.getPair(
        tokenA.address,
        tokenC.address
    );
    console.log('AC address: ' + address2);
    const acPool = VPair__factory.connect(address2, owner);

    // whitelist token B
    // await acPool.setAllowList([tokenB.address]);

    const reserve0Pool2 = await acPool.pairBalance0();
    const reserve1Pool2 = await acPool.pairBalance1();

    const pool2Reserve0 = ethers.utils.formatEther(reserve0Pool2);
    const pool2Reserve1 = ethers.utils.formatEther(reserve1Pool2);

    console.log('pool2: A/C: ' + pool2Reserve0 + '/' + pool2Reserve1);

    // pool 3
    const address3 = await vPairFactoryInstance.getPair(
        tokenB.address,
        tokenC.address
    );
    console.log('BC address: ' + address3);
    const bcPool = VPair__factory.connect(address3, owner);

    // whitelist token A
    // await bcPool.setAllowList([tokenA.address]);

    const reserve0Pool3 = await bcPool.pairBalance0();
    const reserve1Pool3 = await bcPool.pairBalance1();

    const pool3Reserve0 = ethers.utils.formatEther(reserve0Pool3);
    const pool3Reserve1 = ethers.utils.formatEther(reserve1Pool3);

    console.log('pool3: B/C: ' + pool3Reserve0 + '/' + pool3Reserve1);

    // pool 4
    const address4 = await vPairFactoryInstance.getPair(
        tokenD.address,
        tokenB.address
    );
    console.log('AB address: ' + address1);
    const bdPool = VPair__factory.connect(address1, owner);

    // whitelist token C
    await bdPool.setAllowList([tokenC.address]);

    const reserve0Pool4 = await bdPool.pairBalance0();
    const reserve1Pool4 = await bdPool.pairBalance1();

    const pool4Reserve0 = ethers.utils.formatEther(reserve0Pool4);
    const pool4Reserve1 = ethers.utils.formatEther(reserve1Pool4);

    console.log('pool4: B/D: ' + pool4Reserve0 + '/' + pool4Reserve1);

    const address5 = await vPairFactoryInstance.getPair(
        WETH9Instance.address,
        tokenB.address
    );
    console.log('WETH9B address: ' + address5);
    const wbPool = VPair__factory.connect(address5, owner);
    const reserve0Pool5 = await wbPool.pairBalance0();
    const reserve1Pool5 = await wbPool.pairBalance1();

    const pool5Reserve0 = ethers.utils.formatEther(reserve0Pool5);
    const pool5Reserve1 = ethers.utils.formatEther(reserve1Pool5);

    console.log('pool5: WETH9/B: ' + pool5Reserve0 + '/' + pool5Reserve1);

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
        bdPool,
        wbPool,
        pool1Reserve0,
        pool1Reserve1,
        pool2Reserve0,
        pool2Reserve1,
        pool3Reserve0,
        pool3Reserve1,
        vRouterInstance,
        owner,
        accounts: [
            account1,
            account2,
            account3,
            account4,
            account5,
            account6,
            account7,
            account8,
            account9,
            account10,
        ],
        vPairFactoryInstance,
        exchageReserveInstance,
    };
}
