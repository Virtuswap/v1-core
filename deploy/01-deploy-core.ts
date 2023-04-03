import { HardhatRuntimeEnvironment } from 'hardhat/types';
import { DeployFunction } from 'hardhat-deploy/types';
import { networkConfig, developmentChains } from '../helper-hardhat-config';
import verify from '../utils/verify';

const deployCore: DeployFunction = async function (
    hre: HardhatRuntimeEnvironment
) {
    const { getNamedAccounts, deployments, network, config } = hre;
    const { deploy, log } = deployments;
    const { deployer } = await getNamedAccounts();
    const chainId: number = network.config.chainId!;

    let weth9Address: string;
    if (chainId == 31337) {
        const weth9 = await deployments.get('WETH9');
        weth9Address = weth9.address;
    } else {
        weth9Address = networkConfig[network.name].weth9!;
    }

    log('Deploying core contracts...');
    const vPairFactory = await deploy('vPairFactory', {
        from: deployer,
        log: true,
        waitConfirmations: networkConfig[network.name].blockConfirmations || 0,
    });
    const vPoolManager = await deploy('vPoolManager', {
        from: deployer,
        log: true,
        args: [vPairFactory.address],
        waitConfirmations: networkConfig[network.name].blockConfirmations || 0,
    });
    const vExchangeReserves = await deploy('vExchangeReserves', {
        from: deployer,
        log: true,
        args: [vPairFactory.address],
        waitConfirmations: networkConfig[network.name].blockConfirmations || 0,
    });
    const vRouter = await deploy('vRouter', {
        from: deployer,
        log: true,
        args: [vPairFactory.address, weth9Address],
        waitConfirmations: networkConfig[network.name].blockConfirmations || 0,
    });
    log('Core contracts deployed!');

    const pairFactoryContract = await hre.ethers.getContractAt(
        'vPairFactory',
        vPairFactory.address
    );

    log('Setting vPoolManager for vPairFactory...');
    if ((await pairFactoryContract.vPoolManager()) == vPoolManager.address) {
        log('Already set');
    } else {
        await pairFactoryContract.setVPoolManagerAddress(vPoolManager.address);
    }
    log('Setting vExchangeReserves for vPairFactory...');
    if (
        (await pairFactoryContract.exchangeReserves()) ==
        vExchangeReserves.address
    ) {
        log('Already set');
    } else {
        await pairFactoryContract.setExchangeReservesAddress(
            vExchangeReserves.address
        );
    }
    log('Done!');

    if (
        !developmentChains.includes(network.name) &&
        config.etherscan.apiKey.polygonMumbai
    ) {
        await verify(vPairFactory.address, []);
        await verify(vPoolManager.address, [vPairFactory.address]);
        await verify(vExchangeReserves.address, [vPairFactory.address]);
        await verify(vRouter.address, [vPairFactory.address, weth9Address]);
    }
};

export default deployCore;
deployCore.tags = ['all', 'core'];
