//####
// ## Based on https://docs.google.com/spreadsheets/d/1OW2c76WO-FvI4dp-5HB0LGUbDfv_YzVw/edit?usp=sharing&ouid=100308376099877825660&rtpof=true&sd=true
//####

import { loadFixture } from '@nomicfoundation/hardhat-network-helpers';
import { ethers } from 'hardhat';
import { reserveRatioManipulation } from './fixtures/reserveRatioManipulation';
import _ from 'lodash';
import utils from './utils';

describe('ExchangeReserves manipulation scenarios', () => {
    let fixture: any = {};

    before(async () => {
        fixture = await loadFixture(reserveRatioManipulation);
    });

    it('Manipulation 1: manipulating pool AB in order to reduce reserve ratio (i.e. making A more expensive)', async () => {
        console.log('===========================================');
        console.log('STEP1: Buying A and paying 300 B in pool AB');
        console.log('===========================================');

        await fixture.acPool.setAllowList([
            fixture.tokenB.address,
            fixture.tokenD.address,
        ]);

        let amountIn = ethers.utils.parseEther('300');
        let amountOut = await fixture.vRouterInstance.getAmountOut(
            fixture.tokenB.address,
            fixture.tokenA.address,
            amountIn
        );

        const futureTs = await utils.getFutureBlockTimestamp();
        await fixture.vRouterInstance.swapExactOutput(
            fixture.tokenB.address,
            fixture.tokenA.address,
            amountOut,
            amountIn,
            fixture.owner.address,
            futureTs
        );

        console.log('===========================================');
        console.log('STEP2: send 1B to pool AC');
        console.log('===========================================');

        const ikPair = await fixture.vPairFactoryInstance.getPair(
            fixture.tokenB.address,
            fixture.tokenA.address
        );

        const jkPair = await fixture.vPairFactoryInstance.getPair(
            fixture.tokenA.address,
            fixture.tokenC.address
        );

        let amountBIn = ethers.utils.parseEther('1');
        let amountCOut = await fixture.vRouterInstance.getVirtualAmountOut(
            jkPair,
            ikPair,
            amountBIn
        );

        console.log(
            'Amount B Sent to pool: ' + utils.fromWeiToNumber(amountBIn)
        );
        console.log(
            'Amount C Received from pool ' + utils.fromWeiToNumber(amountCOut)
        );
        const futureTs2 = await utils.getFutureBlockTimestamp();
        let jkPairInstance = fixture.acPool;

        let rrBefore = await jkPairInstance.calculateReserveRatio();
        console.log(
            'reserveRatio before ' +
                utils.fromWeiToNumber(rrBefore) / 1000 +
                '%'
        );

        await fixture.vRouterInstance.swapReserveExactOutput(
            fixture.tokenC.address,
            fixture.tokenA.address,
            ikPair,
            amountCOut,
            amountBIn,
            fixture.owner.address,
            futureTs2
        );

        let reserveRatioAfter = await jkPairInstance.calculateReserveRatio();
        console.log(
            'reserveRatio after ' +
                utils.fromWeiToNumber(reserveRatioAfter) / 1000 +
                '%'
        );
    });

    it('Manipulation 2: manipulating pool AB in order to make B more expensive (and get more C in the trade)', async () => {
        console.log('===========================================');
        console.log('STEP1: Buying B and paying 300A in pool AB');
        console.log('===========================================');

        let amountIn = ethers.utils.parseEther('300');
        let amountOut = await fixture.vRouterInstance.getAmountOut(
            fixture.tokenA.address,
            fixture.tokenB.address,
            amountIn
        );

        const futureTs = await utils.getFutureBlockTimestamp();
        await fixture.vRouterInstance.swapExactOutput(
            fixture.tokenA.address,
            fixture.tokenB.address,
            amountOut,
            amountIn,
            fixture.owner.address,
            futureTs
        );

        console.log('===========================================');
        console.log('STEP2: send 1B to pool AC');
        console.log('===========================================');

        const ikPair = await fixture.vPairFactoryInstance.getPair(
            fixture.tokenB.address,
            fixture.tokenA.address
        );

        const jkPair = await fixture.vPairFactoryInstance.getPair(
            fixture.tokenA.address,
            fixture.tokenC.address
        );

        let amountBIn = ethers.utils.parseEther('1');
        let amountCOut = await fixture.vRouterInstance.getVirtualAmountOut(
            jkPair,
            ikPair,
            amountBIn
        );

        console.log(
            'Amount B Sent to pool: ' + utils.fromWeiToNumber(amountBIn)
        );
        console.log(
            'Amount C Received from pool ' + utils.fromWeiToNumber(amountCOut)
        );
        const futureTs2 = await utils.getFutureBlockTimestamp();
        let jkPairInstance = fixture.acPool;

        let rrBefore = await jkPairInstance.calculateReserveRatio();
        console.log(
            'reserveRatio before ' +
                utils.fromWeiToNumber(rrBefore) / 1000 +
                '%'
        );

        let cBalance = await fixture.tokenC.balanceOf(jkPair);
        let aBalance = await fixture.tokenA.balanceOf(jkPair);
        let bBalance = await fixture.tokenB.balanceOf(jkPair);

        console.log('cBalance ' + cBalance);
        console.log('aBalance ' + aBalance);
        console.log('bBalance ' + bBalance);

        let vPool = await fixture.vRouterInstance.getVirtualPool(
            jkPair,
            ikPair
        );
        console.log(JSON.stringify(vPool));

        await fixture.vRouterInstance.swapReserveExactOutput(
            fixture.tokenC.address,
            fixture.tokenA.address,
            ikPair,
            amountCOut,
            amountBIn,
            fixture.owner.address,
            futureTs2
        );

        let cBalanceAfter = await fixture.tokenC.balanceOf(jkPair);
        let aBalanceAfter = await fixture.tokenA.balanceOf(jkPair);
        let bBalanceAfter = await fixture.tokenB.balanceOf(jkPair);

        console.log('cBalanceAfter ' + cBalanceAfter);
        console.log('aBalanceAfter ' + aBalanceAfter);
        console.log('bBalanceAfter ' + bBalanceAfter);

        let reserveRatioAfter = await jkPairInstance.calculateReserveRatio();
        console.log(
            'reserveRatio after ' +
                utils.fromWeiToNumber(reserveRatioAfter) / 1000 +
                '%'
        );
    });

    it('Manipulation 3: manipulating pool AC in order to make C cheaper (and get more C in the trade)', async () => {
        console.log('===========================================');
        console.log('STEP1: Buying A and paying 300C in pool AC');
        console.log('===========================================');

        let amountIn = ethers.utils.parseEther('300');
        let amountOut = await fixture.vRouterInstance.getAmountOut(
            fixture.tokenC.address,
            fixture.tokenA.address,
            amountIn
        );

        const futureTs = await utils.getFutureBlockTimestamp();
        await fixture.vRouterInstance.swapExactOutput(
            fixture.tokenC.address,
            fixture.tokenA.address,
            amountOut,
            amountIn,
            fixture.owner.address,
            futureTs
        );

        console.log('===========================================');
        console.log('STEP2: send 1B to pool AC');
        console.log('===========================================');

        const ikPair = await fixture.vPairFactoryInstance.getPair(
            fixture.tokenB.address,
            fixture.tokenA.address
        );

        const jkPair = await fixture.vPairFactoryInstance.getPair(
            fixture.tokenA.address,
            fixture.tokenC.address
        );

        let amountBIn = ethers.utils.parseEther('1');
        let amountCOut = await fixture.vRouterInstance.getVirtualAmountOut(
            jkPair,
            ikPair,
            amountBIn
        );

        console.log(
            'Amount B Sent to pool: ' + utils.fromWeiToNumber(amountBIn)
        );
        console.log(
            'Amount C Received from pool ' + utils.fromWeiToNumber(amountCOut)
        );
        const futureTs2 = await utils.getFutureBlockTimestamp();
        let jkPairInstance = fixture.acPool;

        let rrBefore = await jkPairInstance.calculateReserveRatio();
        console.log(
            'reserveRatio before ' +
                utils.fromWeiToNumber(rrBefore) / 1000 +
                '%'
        );

        let cBalance = await fixture.tokenC.balanceOf(jkPair);
        let aBalance = await fixture.tokenA.balanceOf(jkPair);
        let bBalance = await fixture.tokenB.balanceOf(jkPair);

        console.log('cBalance ' + cBalance);
        console.log('aBalance ' + aBalance);
        console.log('bBalance ' + bBalance);

        let vPool = await fixture.vRouterInstance.getVirtualPool(
            jkPair,
            ikPair
        );
        console.log(JSON.stringify(vPool));

        await fixture.vRouterInstance.swapReserveExactOutput(
            fixture.tokenC.address,
            fixture.tokenA.address,
            ikPair,
            amountCOut,
            amountBIn,
            fixture.owner.address,
            futureTs2
        );

        let cBalanceAfter = await fixture.tokenC.balanceOf(jkPair);
        let aBalanceAfter = await fixture.tokenA.balanceOf(jkPair);
        let bBalanceAfter = await fixture.tokenB.balanceOf(jkPair);

        console.log('cBalanceAfter ' + cBalanceAfter);
        console.log('aBalanceAfter ' + aBalanceAfter);
        console.log('bBalanceAfter ' + bBalanceAfter);

        let reserveRatioAfter = await jkPairInstance.calculateReserveRatio();
        console.log(
            'reserveRatio after ' +
                utils.fromWeiToNumber(reserveRatioAfter) / 1000 +
                '%'
        );
    });

    it('Manipulation 4: manipulating pool AC in order to make C cheaper (and get more C in the trade)', async () => {
        console.log('===========================================');
        console.log('STEP1: Buying C and paying 300A in pool AC');
        console.log('===========================================');

        let amountIn = ethers.utils.parseEther('300');
        let amountOut = await fixture.vRouterInstance.getAmountOut(
            fixture.tokenA.address,
            fixture.tokenC.address,
            amountIn
        );

        const futureTs = await utils.getFutureBlockTimestamp();
        await fixture.vRouterInstance.swapExactOutput(
            fixture.tokenA.address,
            fixture.tokenC.address,
            amountOut,
            amountIn,
            fixture.owner.address,
            futureTs
        );

        console.log('===========================================');
        console.log('STEP2: send 1B to pool AC');
        console.log('===========================================');

        const ikPair = await fixture.vPairFactoryInstance.getPair(
            fixture.tokenB.address,
            fixture.tokenA.address
        );

        const jkPair = await fixture.vPairFactoryInstance.getPair(
            fixture.tokenA.address,
            fixture.tokenC.address
        );

        let amountBIn = ethers.utils.parseEther('1');
        let amountCOut = await fixture.vRouterInstance.getVirtualAmountOut(
            jkPair,
            ikPair,
            amountBIn
        );

        console.log(
            'Amount B Sent to pool: ' + utils.fromWeiToNumber(amountBIn)
        );
        console.log(
            'Amount C Received from pool ' + utils.fromWeiToNumber(amountCOut)
        );
        const futureTs2 = await utils.getFutureBlockTimestamp();
        let jkPairInstance = fixture.acPool;

        let rrBefore = await jkPairInstance.calculateReserveRatio();
        console.log(
            'reserveRatio before ' +
                utils.fromWeiToNumber(rrBefore) / 1000 +
                '%'
        );

        let cBalance = await fixture.tokenC.balanceOf(jkPair);
        let aBalance = await fixture.tokenA.balanceOf(jkPair);
        let bBalance = await fixture.tokenB.balanceOf(jkPair);

        console.log('cBalance ' + cBalance);
        console.log('aBalance ' + aBalance);
        console.log('bBalance ' + bBalance);

        let vPool = await fixture.vRouterInstance.getVirtualPool(
            jkPair,
            ikPair
        );
        console.log(JSON.stringify(vPool));

        await fixture.vRouterInstance.swapReserveExactOutput(
            fixture.tokenC.address,
            fixture.tokenA.address,
            ikPair,
            amountCOut,
            amountBIn,
            fixture.owner.address,
            futureTs2
        );

        let cBalanceAfter = await fixture.tokenC.balanceOf(jkPair);
        let aBalanceAfter = await fixture.tokenA.balanceOf(jkPair);
        let bBalanceAfter = await fixture.tokenB.balanceOf(jkPair);

        console.log('cBalanceAfter ' + cBalanceAfter);
        console.log('aBalanceAfter ' + aBalanceAfter);
        console.log('bBalanceAfter ' + bBalanceAfter);

        let reserveRatioAfter = await jkPairInstance.calculateReserveRatio();
        console.log(
            'reserveRatio after ' +
                utils.fromWeiToNumber(reserveRatioAfter) / 1000 +
                '%'
        );
    });
});
