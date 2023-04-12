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
export async function sameValues() {
    console.log('==================');
    console.log('Reserve ratio manipulation fixture');
    console.log('==================');

    const issueAmount = ethers.utils.parseEther(
        '10000000000000000000000000000000000000000000000'
    );

    // Contracts are deployed using the first signer/account by default
    const [owner] = await ethers.getSigners();

    const A_PRICE = 1;
    const B_PRICE = 1;
    const C_PRICE = 1;
    const D_PRICE = 1;

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

    const vPoolManagerFactory = await ethers.getContractFactory('vPoolManager');
    const vPoolManagerInstance = await vPoolManagerFactory.deploy(
        vPairFactoryInstance.address
    );

    await vPairFactoryInstance.setVPoolManagerAddress(
        vPoolManagerInstance.address
    );

    await vPairFactoryInstance.setDefaultAllowList(
        [tokenA.address, tokenB.address, tokenC.address, tokenD.address].sort(
            (a, b) => {
                if (ethers.BigNumber.from(a).lt(ethers.BigNumber.from(b)))
                    return -1;
                else if (ethers.BigNumber.from(a).eq(ethers.BigNumber.from(b)))
                    return 0;
                else return 1;
            }
        )
    );

    const vRouterContractFactory = await ethers.getContractFactory('vRouter');
    const vRouterInstance = await vRouterContractFactory.deploy(
        vPairFactoryInstance.address,
        WETH9Instance.address
    );

    const vExchangeReserveContractFactory = await ethers.getContractFactory(
        'vExchangeReserves'
    );
    const exchangeReserveInstance =
        await vExchangeReserveContractFactory.deploy(
            vPairFactoryInstance.address
        );

    await tokenA.approve(vRouterInstance.address, issueAmount);
    await tokenB.approve(vRouterInstance.address, issueAmount);
    await tokenC.approve(vRouterInstance.address, issueAmount);
    await tokenD.approve(vRouterInstance.address, issueAmount);

    const futureTs = (await time.latest()) + 1000000;

    await vRouterInstance.addLiquidity(
        tokenA.address,
        tokenB.address,
        ethers.utils.parseEther('50000000'),
        ethers.utils.parseEther('50000000'),
        ethers.utils.parseEther('50000000'),
        ethers.utils.parseEther('50000000'),
        owner.address,
        futureTs
    );

    //create pool A/C
    //create pool A/B with 10,000 A and equivalent C

    await vRouterInstance.addLiquidity(
        tokenA.address,
        tokenC.address,
        ethers.utils.parseEther('50000000'),
        ethers.utils.parseEther('50000000'),
        ethers.utils.parseEther('50000000'),
        ethers.utils.parseEther('50000000'),
        owner.address,
        futureTs
    );

    //create pool B/C
    //create pool B/C with 10,000 B and equivalent C

    await vRouterInstance.addLiquidity(
        tokenB.address,
        tokenC.address,
        ethers.utils.parseEther('50000000'),
        ethers.utils.parseEther('50000000'),
        ethers.utils.parseEther('50000000'),
        ethers.utils.parseEther('50000000'),
        owner.address,
        futureTs
    );

    await vRouterInstance.addLiquidity(
        tokenB.address,
        tokenD.address,
        ethers.utils.parseEther('50000000'),
        ethers.utils.parseEther('50000000'),
        ethers.utils.parseEther('50000000'),
        ethers.utils.parseEther('50000000'),
        owner.address,
        futureTs
    );

    //whitelist tokens in pools

    //pool 1
    const abAddress = await vPairFactoryInstance.pairs(
        tokenA.address,
        tokenB.address
    );

    const abPool = VPair__factory.connect(abAddress, owner);

    await abPool.setMaxReserveThreshold(2000);
    //whitelist token C
    await abPool.setAllowList(
        [tokenC.address, tokenD.address].sort((a, b) => {
            if (ethers.BigNumber.from(a).lt(ethers.BigNumber.from(b)))
                return -1;
            else if (ethers.BigNumber.from(a).eq(ethers.BigNumber.from(b)))
                return 0;
            else return 1;
        })
    );

    //pool 2
    const acAddress = await vPairFactoryInstance.pairs(
        tokenA.address,
        tokenC.address
    );
    const acPool = VPair__factory.connect(acAddress, owner);

    //whitelist token B
    await acPool.setAllowList(
        [tokenB.address, tokenD.address].sort((a, b) => {
            if (ethers.BigNumber.from(a).lt(ethers.BigNumber.from(b)))
                return -1;
            else if (ethers.BigNumber.from(a).eq(ethers.BigNumber.from(b)))
                return 0;
            else return 1;
        })
    );
    await acPool.setMaxReserveThreshold(2000);

    //pool 3
    const bcAddress = await vPairFactoryInstance.pairs(
        tokenB.address,
        tokenC.address
    );
    const bcPool = VPair__factory.connect(bcAddress, owner);

    //whitelist token A
    await bcPool.setAllowList(
        [tokenA.address, tokenD.address].sort((a, b) => {
            if (ethers.BigNumber.from(a).lt(ethers.BigNumber.from(b)))
                return -1;
            else if (ethers.BigNumber.from(a).eq(ethers.BigNumber.from(b)))
                return 0;
            else return 1;
        })
    );
    await bcPool.setMaxReserveThreshold(2000);

    // pool 4
    const bdAddress = await vPairFactoryInstance.pairs(
        tokenB.address,
        tokenD.address
    );
    const bdPool = VPair__factory.connect(bdAddress, owner);

    //whitelist token A
    await bdPool.setAllowList(
        [tokenA.address, tokenC.address].sort((a, b) => {
            if (ethers.BigNumber.from(a).lt(ethers.BigNumber.from(b)))
                return -1;
            else if (ethers.BigNumber.from(a).eq(ethers.BigNumber.from(b)))
                return 0;
            else return 1;
        })
    );
    await bdPool.setMaxReserveThreshold(2000);

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
        bdPool,
        vRouterInstance,
        owner,
        vPairFactoryInstance,
        exchangeReserveInstance,
    };
}
