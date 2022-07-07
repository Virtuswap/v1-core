const vRouter = artifacts.require('vRouter')
const vPair = artifacts.require('vPair')
const vPairFactory = artifacts.require("vPairFactory");
const vSwapMath = artifacts.require("vSwapMath");
const ERC20 = artifacts.require("ERC20");
function getMethods(obj) {
    let result = [];
    for (let id in obj) {
        try {
            if (typeof(obj[id]) == "function") {
                result.push(id + ": " + obj[id].toString());
            }
        } catch (err) {
            result.push(id + ": inaccessible");
        }
    }
    return result;
}
const ZERO_ADDRESS = "0x0000000000000000000000000000000000000000";
contract('vRouter',  (accounts) => {
    let tokenA, tokenB, tokenC, WETH;
    let vRouterInstance, vPairInstance, vPairFactoryInstance, vSwapMathInstance;
    const wallet = accounts[0]
    beforeEach(async () => {
        tokenA = await ERC20.new("tokenA", "A", 0);
        tokenB = await ERC20.new("tokenB", "B", 0);
        tokenC = await ERC20.new("tokenC", "C", 0);
        WETH = await ERC20.new("WETH", "WETH", 0);
        await tokenA._mint(wallet, 100000000000)
        await tokenB._mint(wallet, 100000000000)
        await tokenC._mint(wallet, 100000000000)
        await WETH._mint(wallet, 100000000000)
        vPairFactoryInstance = await vPairFactory.deployed();
        vRouterInstance = await vRouter.deployed();
        vSwapMathInstance = await vSwapMath.deployed();
        await vPairFactoryInstance.createPair(tokenA.address, tokenB.address);
        await vPairFactoryInstance.createPair(tokenA.address, tokenC.address);
        await vPairFactoryInstance.createPair(tokenB.address, tokenC.address);

        await tokenA.approve(vRouterInstance.address, 10000000000)
        await tokenB.approve(vRouterInstance.address, 10000000000)
        await tokenC.approve(vRouterInstance.address, 10000000000)


        await vRouterInstance.addLiquidity(
            tokenA.address,
            tokenB.address,
            10000,
            100000,
            10000,
            100000,
            wallet,
            new Date().getTime() + 1000 * 60 * 60
        )
        await vRouterInstance.addLiquidity(
            tokenA.address,
            tokenC.address,
            100000,
            1000,
            100000,
            1000,
            wallet,
            new Date().getTime() + 1000 * 60 * 60
        )
        await vRouterInstance.addLiquidity(
            tokenB.address,
            tokenC.address,
            10000000,
            10000,
            10000000,
            10000,
            wallet,
            new Date().getTime() + 1000 * 60 * 60
        )
    })
    it('adds Liquidity', async () => {

        if ((await vPairFactoryInstance.getPair(tokenA.address, tokenB.address)) === ZERO_ADDRESS) {
            await vPairFactoryInstance.createPair(tokenA.address, tokenB.address);
        }

        let amountADesired = 100;
        let amountBDesired = 10;
        const pool = await vPair.at(await vPairFactoryInstance.getPair(tokenA.address, tokenB.address));


        let balanceBefore = await pool.balanceOf(wallet);
        await vRouterInstance.addLiquidity(
            tokenA.address,
            tokenB.address,
            amountADesired,
            amountBDesired,
            1,
            1,
            wallet,
            new Date().getTime() + 1000 * 60 * 60
        )
        let balanceAfter = await pool.balanceOf(wallet);
        //basic check
        expect(Number(balanceBefore.toString())).to.lessThan(Number(balanceAfter.toString()));
    });

    it('removes Liquidity', async () => {
        // wip

        const wallet = accounts[3];

        let amountADesired = 100;
        let amountBDesired = 10;
        const pool = await vPair.at(await vPairFactoryInstance.getPair(tokenA.address, tokenB.address));

        let balanceBefore = await pool.balanceOf(wallet);
        await vRouterInstance.addLiquidity(
            tokenA.address,
            tokenB.address,
            amountADesired,
            amountBDesired,
            amountADesired,
            amountBDesired,
            wallet,
            new Date().getTime() + 1000 * 60 * 60
        )
        let balanceAfter = await pool.balanceOf(wallet);
        await vRouterInstance.removeLiquidity(
            tokenA.address,
            tokenB.address,
            amountADesired,
            amountBDesired,
            balanceAfter.sub(balanceBefore).toString(),
            wallet,
            new Date().getTime() + 1000 * 60 * 60
        )
        // balance should be equal to initial balance
        expect(balanceBefore.toString()).to.equal((await pool.balanceOf(wallet)).toString())
    });

    it('Swaps A for B in pool A/B', async () => {
        // WIP
        const vPairFactoryInstance = await vPairFactory.deployed();

        const wallet = accounts[3];
        if ((await vPairFactoryInstance.getPair(tokenA.address, tokenB.address)) === ZERO_ADDRESS) {
            await vPairFactoryInstance.createPair(tokenA.address, tokenB.address);
        }

        const vRouterInstance = await vRouter.deployed(vPairFactoryInstance.address, WETH);
        // wip
        const pool = await vPairFactoryInstance.getPair(tokenA.address, tokenB.address);
        let amountIn = 10;
        let amountOut = 100;

        await vRouterInstance.swap(
            [pool],
            [amountIn],
            [0],
            [0],
            tokenA.address,
            tokenB.address,
            wallet,
            new Date().getTime() + 1000 * 60 * 60
        )
    });

    it('Swaps C for B in pool A/B, Swaps B for A in pool A/C then exchanges', async () => {
        const vPairFactoryInstance = await vPairFactory.deployed();

        const wallet = accounts[3];

        if ((await vPairFactoryInstance.getPair(tokenA.address, tokenB.address)) === ZERO_ADDRESS) {
            await vPairFactoryInstance.createPair(tokenA.address, tokenB.address);
        }
        if ((await vPairFactoryInstance.getPair(tokenA.address, tokenC.address)) === ZERO_ADDRESS) {
            await vPairFactoryInstance.createPair(tokenA.address, tokenC.address);
        }


        const vRouterInstance = await vRouter.deployed(vPairFactoryInstance.address, WETH);
        const pool = await vPairFactoryInstance.getPair(tokenA.address, tokenB.address);
        // wip
    });

});
