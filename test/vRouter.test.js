const vRouter = artifacts.require('vRouter')
const vPairFactory = artifacts.require("vPairFactory");

contract('vRouter',  (accounts) => {

    it('adds Liquidity', async () => {
        // WIP
        const vPairFactoryInstance = await vPairFactory.deployed();

        const tokenA = accounts[0];
        const tokenB = accounts[1];
        const WETH = accounts[2];
        const wallet = accounts[3];
        let pairExists = await vPairFactoryInstance.getPair(tokenA, tokenB);
        if (!pairExists) {

            await vPairFactoryInstance.createPair(tokenA, tokenB);
        }

        const vRouterInstance = await vRouter.deployed(vPairFactoryInstance.address, WETH);
        // wip
        let amountADesired = 100;
        let amountBDesired = 1000;

        await vRouterInstance.addLiquidity(
            tokenA,
            tokenB,
            amountADesired,
            amountBDesired,
            amountADesired,
            amountBDesired,
            wallet,
            new Date().getTime() + 1000 * 60 * 60
        )
    });

    it('removes Liquidity', async () => {
        // wip
        const vPairFactoryInstance = await vPairFactory.deployed();

        const tokenA = accounts[0];
        const tokenB = accounts[1];
        const WETH = accounts[2];
        const wallet = accounts[3];
        let pairExists = await vPairFactoryInstance.getPair(tokenA, tokenB);
        if (!pairExists) {

            await vPairFactoryInstance.createPair(tokenA, tokenB);
        }

        const vRouterInstance = await vRouter.deployed(vPairFactoryInstance.address, WETH);
        let amountADesired = 100;
        let amountBDesired = 1000;
        await vRouterInstance.removeLiquidity(
            tokenA,
            tokenB,
            amountADesired,
            amountBDesired,
            1, // hardcoded for now
            wallet,
            new Date().getTime() + 1000 * 60 * 60
        )
    });

    it('Swaps A for B in pool A/B', async () => {
        // WIP
        const vPairFactoryInstance = await vPairFactory.deployed();

        const tokenA = accounts[0];
        const tokenB = accounts[1];
        const WETH = accounts[2];
        const wallet = accounts[3];
        let pairExists = await vPairFactoryInstance.getPair(tokenA, tokenB);
        if (!pairExists) {
            await vPairFactoryInstance.createPair(tokenA, tokenB);
        }

        const vRouterInstance = await vRouter.deployed(vPairFactoryInstance.address, WETH);
        // wip
        let amountADesired = 100;
        let amountBDesired = 1000;
        const pool = vPairFactoryInstance.getPair(tokenA, tokenB);
        await vRouterInstance.addLiquidity(
            tokenA,
            tokenB,
            amountADesired,
            amountBDesired,
            amountADesired,
            amountBDesired,
            wallet,
            new Date().getTime() + 1000 * 60 * 60
        )
        let amountIn = 10;
        let amountOut = 100;

        await vRouterInstance.swap(
            [pool],
            [amountIn],
            [0],
            [0],
            tokenA,
            tokenB,
            wallet,
            new Date().getTime() + 1000 * 60 * 60
        )
    });

    it('Swaps C for B in pool A/B, Swaps B for A in pool A/C then exchanges', async () => {
        const vPairFactoryInstance = await vPairFactory.deployed();

        const tokenA = accounts[0];
        const tokenB = accounts[1];
        const tokenC = accounts[4];
        const WETH = accounts[2];
        const wallet = accounts[3];

        if (!(await vPairFactoryInstance.getPair(tokenA, tokenB))) {
            await vPairFactoryInstance.createPair(tokenA, tokenB);
        }
        if (!(await vPairFactoryInstance.getPair(tokenA, tokenC))) {
            await vPairFactoryInstance.createPair(tokenA, tokenC);
        }


        const vRouterInstance = await vRouter.deployed(vPairFactoryInstance.address, WETH);
        const pool = vPairFactoryInstance.getPair(tokenA, tokenB);
        // wip
    });

});
