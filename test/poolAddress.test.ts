import { time, loadFixture } from "@nomicfoundation/hardhat-network-helpers";
import { expect } from "chai";
import { ethers } from "hardhat";
import { ERC20PresetFixedSupply__factory, ERC20__factory, VPairFactory__factory, VPair__factory, VRouter__factory, VSwapERC20__factory } from "../typechain-types";

const ONE_GWEI = 1_000_000_000;

describe("Pool address", function () {

    // We define a fixture to reuse the same setup in every test.
    // We use loadFixture to run this setup once, snapshot that state,
    // and reset Hardhat Network to that snapshot in every test.
    async function deployPools() {

        const issueAmount = 100000000000000 * ONE_GWEI;

        // Contracts are deployed using the first signer/account by default
        const [owner, otherAccount] = await ethers.getSigners();

        const A_PRICE = 1;
        const B_PRICE = 3;
        const C_PRICE = 6;

        const erc20ContractFactory = await new ERC20PresetFixedSupply__factory(owner);
        const tokenA = erc20ContractFactory.deploy("tokenA", "A", issueAmount, owner.address);
        const tokenB = erc20ContractFactory.deploy("tokenB", "B", issueAmount, owner.address);
        const tokenC = erc20ContractFactory.deploy("tokenC", "C", issueAmount, owner.address);

        const vPairFactoryInstance = await new VPairFactory__factory().deploy();
        const vRouterInstance = await new VRouter__factory().deploy("Router");
        // Wrong! Where is VSwapLibrary?
        //const vSwapLibraryInstance = await new VSwapERC20__factory().deploy();

        (await tokenA).approve(vRouterInstance.address, issueAmount);
        (await tokenB).approve(vRouterInstance.address, issueAmount);
        (await tokenC).approve(vRouterInstance.address, issueAmount);

        const futureTs = (await time.latest()) + 1000000;

        // create pool A/B with 10,000 A and equivalent B
        let AInput = 10000 * A_PRICE;
        let BInput = (B_PRICE / A_PRICE) * AInput;

        await vRouterInstance.addLiquidity(
            (await tokenA).address,
            (await tokenB).address,
            AInput * ONE_GWEI,
            BInput * ONE_GWEI,
            AInput * ONE_GWEI,
            BInput * ONE_GWEI,
            owner.address,
            futureTs);

        // create pool A/C
        // create pool A/C with 10,000 A and equivalent C
        let CInput = (C_PRICE / A_PRICE) * AInput;
        await vRouterInstance.addLiquidity(
            (await tokenA).address,
            (await tokenC).address,
            AInput * ONE_GWEI,
            CInput * ONE_GWEI,
            AInput * ONE_GWEI,
            CInput * ONE_GWEI,
            owner.address,
            futureTs);

        // create pool B/C
        // create pool B/C with 20,000 B and equivalent C
        BInput = 20000 * B_PRICE;
        CInput = (C_PRICE / B_PRICE) * BInput;
        await vRouterInstance.addLiquidity(
            (await tokenB).address,
            (await tokenC).address,
            BInput * ONE_GWEI,
            CInput * ONE_GWEI,
            BInput * ONE_GWEI,
            CInput * ONE_GWEI,
            owner.address,
            futureTs);

        // whitelist tokens in pools

        // pool 1
        const address1 = await vPairFactoryInstance.getPair(
            (await tokenA).address,
            (await tokenB).address
        );
        console.log("AB address: " + address1);
        // Wrong! Creating pool1 should use address1
        const vPair = await new VPair__factory();
        const pool1 = vPair.deploy();

        // whitelist token C
        (await pool1).setWhitelist([(await tokenC).address]);

        const reserve0Pool1 = (await pool1).reserve0();
        const reserve1Pool1 = (await pool1).reserve1();

        const pool1Reserve0 = (await reserve0Pool1).div(ONE_GWEI).toNumber();
        const pool1Reserve1 = (await reserve1Pool1).div(ONE_GWEI).toNumber();

        console.log("pool1: A/B: " + pool1Reserve0 + "/" + pool1Reserve1);

        // pool 2
        const address2 = await vPairFactoryInstance.getPair(
            (await tokenA).address,
            (await tokenC).address
        );
        console.log("AC address: " + address2);
        // Wrong! Creating pool2 should use address2
        const pool2 = vPair.deploy();

        // whitelist token B
        (await pool2).setWhitelist([(await tokenB).address]);

        const reserve0Pool2 = (await pool2).reserve0();
        const reserve1Pool2 = (await pool2).reserve1();

        const pool2Reserve0 = (await reserve0Pool2).div(ONE_GWEI).toNumber();
        const pool2Reserve1 = (await reserve1Pool2).div(ONE_GWEI).toNumber();

        console.log("pool2: A/C: " + pool2Reserve0 + "/" + pool2Reserve1);

        // pool 3
        const address3 = await vPairFactoryInstance.getPair(
            (await tokenB).address,
            (await tokenC).address
        );
        console.log("BC address: " + address3);
        // Wrong! Creating pool3 should use address3
        const pool3 = vPair.deploy();

        //whitelist token A
        (await pool3).setWhitelist([(await tokenA).address]);

        const reserve0Pool3 = (await pool3).reserve0();
        const reserve1Pool3 = (await pool3).reserve1();

        const pool3Reserve0 = (await reserve0Pool3).div(ONE_GWEI).toNumber();
        const pool3Reserve1 = (await reserve1Pool3).div(ONE_GWEI).toNumber();

        console.log("pool3: B/C: " + pool3Reserve0 + "/" + pool3Reserve1);
        return {
            tokenA, tokenB, tokenC,
            A_PRICE, B_PRICE, C_PRICE,
            pool1, pool2, pool3,
            pool1Reserve0, pool1Reserve1,
            pool2Reserve0, pool2Reserve1,
            pool3Reserve0, pool3Reserve1,
            vRouterInstance,
            owner, otherAccount };
    }

    describe("Deployment", function () {
        it("Should compute tokenA / tokenC pool address", async function () {
            const { pool1, pool2, pool3, tokenA, tokenC, vRouterInstance, owner } = await loadFixture(deployPools);

            const tokenABalanceBefore = (await tokenA).balanceOf(owner.address);
            const tokenCBalanceBefore = (await tokenC).balanceOf(owner.address);

            const amountIn = 10 * ONE_GWEI;
            const amountOut = await vRouterInstance.getAmountOut(
                (await tokenA).address,
                (await tokenC).address,
                amountIn);
            const futureTs = (await time.latest()) + 1000000;

            await vRouterInstance.swap(
                [(await pool1).address, (await pool2).address, (await pool3).address],
                [amountIn],
                [amountOut],
                ["0x0000000000000000000000000000000000000000"],
                (await tokenA).address,
                (await tokenC).address,
                owner.address,
                futureTs);

            const tokenABalanceAfter = (await tokenA).balanceOf(owner.address);
            const tokenCBalanceAfter = (await tokenC).balanceOf(owner.address);

            expect((await tokenCBalanceAfter).toNumber()).to.be.above((await tokenCBalanceBefore).toNumber());
            expect((await tokenABalanceAfter).toNumber()).to.be.lessThan((await tokenABalanceBefore).toNumber());

        });
    });

});
