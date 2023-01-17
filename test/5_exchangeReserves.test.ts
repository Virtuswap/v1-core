import { loadFixture } from '@nomicfoundation/hardhat-network-helpers';
import { expect } from 'chai';
import { ethers } from 'hardhat';
import { deployPools } from './fixtures/deployPools';
import _ from 'lodash';
import utils from './utils';

describe('ExchangeReserves', () => {
    let fixture: any = {};

    before(async function () {
        fixture = await loadFixture(deployPools);

        await fixture.vPairFactoryInstance.setExchangeReservesAddress(
            fixture.exchageReserveInstance.address
        );
    });

    it('Should change incentives limit', async () => {
        const exchangeReserves = fixture.exchageReserveInstance;
        const incentivesLimitBefore =
            await exchangeReserves.incentivesLimitPct();
        await exchangeReserves.changeIncentivesLimitPct(50);
        const incentivesLimitAfter =
            await exchangeReserves.incentivesLimitPct();
        expect(incentivesLimitBefore).to.equal(1);
        expect(incentivesLimitAfter).to.equal(50);
    });

    it('Incentives limit can be changed only by factory admin', async () => {
        const exchangeReserves = fixture.exchageReserveInstance;
        await expect(
            exchangeReserves
                .connect(fixture.accounts[1])
                .changeIncentivesLimitPct(50)
        ).to.revertedWith('Admin only');
    });

    it('Should revert when callback caller is not jkPair1', async () => {
        const abPool = fixture.abPool;
        const bdPool = fixture.bdPool;
        const tokenA = fixture.tokenA;
        const tokenB = fixture.tokenB;
        const owner = fixture.owner;

        let amountOut = ethers.utils.parseEther('100');
        let data = utils.getEncodedExchangeReserveCallbackParams(
            abPool.address, //jk1
            bdPool.address, //ik1
            bdPool.address, //jk2
            abPool.address, //ik2
            owner.address,
            amountOut
        );

        await expect(
            fixture.exchageReserveInstance.vFlashSwapCallback(
                tokenA.address,
                tokenB.address,
                amountOut,
                data
            )
        ).to.revertedWith('IC');
    });

    it('Should add C to pool A/B', async () => {
        const abPool = fixture.abPool;
        const bcPool = fixture.bcPool;
        const acPool = fixture.acPool;
        const tokenA = fixture.tokenA;
        const tokenB = fixture.tokenB;
        const tokenC = fixture.tokenC;
        const owner = fixture.owner;
        const vRouterInstance = fixture.vRouterInstance;

        let amountOut = ethers.utils.parseEther('100');

        let amountIn = await vRouterInstance.getVirtualAmountIn(
            abPool.address,
            bcPool.address,
            amountOut
        );

        let reserveRatioBefore = await abPool.calculateReserveRatio();
        let tokenCReserve = await abPool.reservesBaseValue(tokenC.address);

        const futureTs = await utils.getFutureBlockTimestamp();

        await vRouterInstance.swapReserveExactOutput(
            tokenA.address,
            tokenB.address,
            bcPool.address,
            amountOut,
            amountIn,
            owner.address,
            futureTs
        );

        let reserveRatioAfter = await abPool.calculateReserveRatio();

        expect(reserveRatioBefore).to.lessThan(reserveRatioAfter);

        let tokenCReserveAfter = await abPool.reservesBaseValue(tokenC.address);
        expect(tokenCReserve).to.lessThan(tokenCReserveAfter);
    });

    it('Should add A to pool B/C', async () => {
        const abPool = fixture.abPool;
        const bcPool = fixture.bcPool;
        const tokenA = fixture.tokenA;
        const tokenB = fixture.tokenB;
        const tokenC = fixture.tokenC;
        const owner = fixture.owner;
        const vRouterInstance = fixture.vRouterInstance;

        let amountOut = ethers.utils.parseEther('500');

        let amountIn = await vRouterInstance.getVirtualAmountIn(
            bcPool.address,
            abPool.address,
            amountOut
        );

        let reserveRatioBefore = await bcPool.calculateReserveRatio();
        let tokenAReserve = await bcPool.reservesBaseValue(tokenA.address);
        const futureTs = await utils.getFutureBlockTimestamp();

        await vRouterInstance.swapReserveExactOutput(
            tokenB.address,
            tokenC.address,
            abPool.address,
            amountOut,
            amountIn,
            owner.address,
            futureTs
        );

        let reserveRatioAfter = await bcPool.calculateReserveRatio();

        expect(reserveRatioBefore).to.lessThan(reserveRatioAfter);

        let tokenAReserveAfter = await bcPool.reservesBaseValue(tokenA.address);
        expect(tokenAReserve).to.lessThan(tokenAReserveAfter);
    });

    it('Should exchange reserves A<>C -> A goes from B/C to A/B, C goes from A/B to B/C', async () => {
        const abPool = fixture.abPool;
        const bcPool = fixture.bcPool;
        const tokenA = fixture.tokenA;
        const tokenC = fixture.tokenC;
        const owner = fixture.owner;

        let amountAInReserve = await bcPool.reserves(tokenA.address);

        await tokenC.transfer(bcPool.address, ethers.utils.parseEther('10'));

        let aReserveInBC = await bcPool.reserves(tokenA.address);
        let cReserveInAB = await abPool.reserves(tokenC.address);
        let poolABRR = await abPool.calculateReserveRatio();

        let tokenAReserveBaseValue = await bcPool.reservesBaseValue(
            tokenA.address
        );
        let tokenCReserveBaseValue = await abPool.reservesBaseValue(
            tokenC.address
        );

        let poolBCRR = await bcPool.calculateReserveRatio();

        let balanceABefore = await tokenA.balanceOf(owner.address);

        //get flash swap of amount required amount C from pool BC.
        await fixture.exchageReserveInstance.exchange(
            bcPool.address, //jk1
            abPool.address, // ik1
            abPool.address, //jk2
            bcPool.address, // ik2
            amountAInReserve
        );

        let balanceAAfter = await tokenA.balanceOf(owner.address);

        let tokenAReserveBaseValueAfter = await bcPool.reservesBaseValue(
            tokenA.address
        );
        let tokenCReserveBaseValueAfter = await abPool.reservesBaseValue(
            tokenC.address
        );

        let aReserveInBCAfter = await bcPool.reserves(tokenA.address);
        let cReserveInABAfter = await abPool.reserves(tokenC.address);
        let poolABRRAfter = await abPool.calculateReserveRatio();

        let poolBCRRAfter = await bcPool.calculateReserveRatio();

        // incentives received
        expect(balanceAAfter).to.be.above(balanceABefore);

        expect(aReserveInBCAfter).to.equal(0);

        expect(poolABRRAfter).to.lessThan(poolABRR);

        expect(poolBCRRAfter).to.lessThan(poolBCRR);

        expect(tokenAReserveBaseValueAfter).to.lessThan(tokenAReserveBaseValue);

        expect(aReserveInBCAfter).to.lessThan(aReserveInBC);

        expect(cReserveInABAfter).to.lessThan(cReserveInAB);
    });
});
