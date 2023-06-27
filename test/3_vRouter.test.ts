import { loadFixture, time } from '@nomicfoundation/hardhat-network-helpers';
import { expect } from 'chai';
import { ethers } from 'hardhat';
import { deployPools } from './fixtures/deployPools';
import { mine } from '@nomicfoundation/hardhat-network-helpers';

import {
    VRouter__factory,
    ERC20PresetFixedSupply__factory,
    VPair__factory,
} from '../typechain-types/index';
import _ from 'lodash';
import utils from './utils';

describe('vRouter 1', () => {
    let fixture: any = {};

    before(async function () {
        fixture = await loadFixture(deployPools);
    });

    it('Should quote A to B', async () => {
        const abPool = fixture.abPool;
        const tokenA = fixture.tokenA;
        const tokenB = fixture.tokenB;
        const vRouterInstance = fixture.vRouterInstance;

        let input = ethers.utils.parseEther('14');

        let quote = await vRouterInstance.quote(
            tokenA.address,
            tokenB.address,
            input
        );

        const token0 = await abPool.token0();

        const reserves = await abPool.getBalances();

        let tokenAReserve = 0;
        let tokenBReserve = 0;

        if (token0 == tokenA.address) {
            tokenAReserve = reserves._balance0;
            tokenBReserve = reserves._balance1;
        } else {
            tokenAReserve = reserves._balance1;
            tokenBReserve = reserves._balance0;
        }

        tokenAReserve = parseFloat(ethers.utils.formatEther(tokenAReserve));
        tokenBReserve = parseFloat(ethers.utils.formatEther(tokenBReserve));

        const ratio = tokenAReserve / tokenBReserve;

        quote = parseFloat(ethers.utils.formatEther(quote));

        expect(quote * ratio).to.equal(
            parseFloat(ethers.utils.formatEther(input))
        );
        expect(quote).to.equal(42);
    });

    it('Should (amountIn(amountOut(x)) = x)', async () => {
        const tokenA = fixture.tokenA;
        const tokenB = fixture.tokenB;
        const vRouterInstance = fixture.vRouterInstance;

        let X = ethers.utils.parseEther('395');

        const amountIn = await vRouterInstance.getAmountIn(
            tokenA.address,
            tokenB.address,
            X
        );

        const amountOut = await vRouterInstance.getAmountOut(
            tokenA.address,
            tokenB.address,
            amountIn
        );

        const amountOutEth = parseFloat(ethers.utils.formatEther(amountOut));
        expect(amountOutEth).to.equal(395);
    });

    it('Should calculate virtual pool A/C using B/C as oracle', async () => {
        const abPool = fixture.abPool;
        const bcPool = fixture.bcPool;

        const tokenA = fixture.tokenA;
        const tokenC = fixture.tokenC;
        const vRouterInstance = fixture.vRouterInstance;

        const vPool = await vRouterInstance.getVirtualPool(
            bcPool.address,
            abPool.address
        );

        expect(
            vPool.reserve0 / vPool.reserve1 == fixture.A_PRICE / fixture.C_PRICE
        );
        expect(
            vPool.token0 == tokenA.address && vPool.token1 == tokenC.address
        );
    });

    it('Should calculate virtual pool B/C using A/B as oracle', async () => {
        const abPool = fixture.abPool;
        const acPool = fixture.acPool;
        const tokenB = fixture.tokenB;
        const tokenC = fixture.tokenC;
        const vRouterInstance = fixture.vRouterInstance;

        const vPool = await vRouterInstance.getVirtualPool(
            acPool.address,
            abPool.address
        );

        expect(
            vPool.reserve0 / vPool.reserve1 == fixture.B_PRICE / fixture.C_PRICE
        );
        expect(
            vPool.token0 == tokenB.address && vPool.token1 == tokenC.address
        );
    });

    it('Should calculate virtual pool A/B using B/C as oracle', async () => {
        const abPool = fixture.abPool;
        const bcPool = fixture.bcPool;
        const tokenA = fixture.tokenA;
        const tokenB = fixture.tokenB;
        const vRouterInstance = fixture.vRouterInstance;

        const vPool = await vRouterInstance.getVirtualPool(
            bcPool.address,
            abPool.address
        );

        expect(
            vPool.reserve0 / vPool.reserve1 == fixture.A_PRICE / fixture.B_PRICE
        );
        expect(
            vPool.token0 == tokenA.address && vPool.token1 == tokenB.address
        );
    });

    it('Should calculate virtual pool B/A using B/C as oracle', async () => {
        const tokenA = fixture.tokenA;
        const acPool = fixture.acPool;
        const bcPool = fixture.bcPool;
        const tokenB = fixture.tokenB;
        const vRouterInstance = fixture.vRouterInstance;

        const vPool = await vRouterInstance.getVirtualPool(
            acPool.address,
            bcPool.address
        );

        expect(
            vPool.reserve0 / vPool.reserve1 == fixture.B_PRICE / fixture.A_PRICE
        );
        expect(
            vPool.token0 == tokenB.address && vPool.token1 == tokenA.address
        );
    });

    it('Should getVirtualAmountIn for buying 10 B in virtual pool A/B', async () => {
        const vRouterInstance = fixture.vRouterInstance;

        const amountOut = ethers.utils.parseEther('10');

        const amountIn = await vRouterInstance.getVirtualAmountIn(
            fixture.bcPool.address,
            fixture.acPool.address,
            amountOut
        );

        expect(
            parseFloat(
                parseFloat(ethers.utils.formatEther(amountIn)).toFixed(3)
            )
        ).to.equal(3.344);
    });

    it('Should getVirtualAmountOut', async () => {
        const vRouterInstance = fixture.vRouterInstance;

        const amountIn = ethers.utils.parseEther('10');

        const amountOut = await vRouterInstance.getVirtualAmountOut(
            fixture.bcPool.address,
            fixture.abPool.address,
            amountIn
        );
        expect(amountOut > 0);
    });

    it('Should getVirtualAmountIn(getVirtualAmountOut(x)) = x', async () => {
        const vRouterInstance = fixture.vRouterInstance;

        const _amountOut = ethers.utils.parseEther('10');

        const amountIn = await vRouterInstance.getVirtualAmountIn(
            fixture.bcPool.address,
            fixture.abPool.address,
            _amountOut
        );

        const amountOut = await vRouterInstance.getVirtualAmountOut(
            fixture.bcPool.address,
            fixture.abPool.address,
            amountIn
        );

        expect(_amountOut == amountOut);
    });

    it('Should swap exact out C to A on pool A/C', async () => {
        const tokenA = fixture.tokenA;
        const tokenC = fixture.tokenC;
        const owner = fixture.owner;

        const vRouterInstance = fixture.vRouterInstance;

        const tokenABalanceBefore = await tokenA.balanceOf(owner.address);
        const tokenCBalanceBefore = await tokenC.balanceOf(owner.address);

        const amountOut = ethers.utils.parseEther('10');

        let amountIn = await vRouterInstance.getAmountIn(
            tokenC.address,
            tokenA.address,
            amountOut
        );
        const futureTs = await utils.getFutureBlockTimestamp();

        await vRouterInstance.swapExactOutput(
            [tokenC.address, tokenA.address],
            amountOut,
            amountIn,
            owner.address,
            futureTs
        );
        const tokenABalanceAfter = await tokenA.balanceOf(owner.address);
        const tokenCBalanceAfter = await tokenC.balanceOf(owner.address);
        expect(tokenCBalanceAfter).to.be.lessThan(tokenCBalanceBefore);

        expect(tokenABalanceAfter).to.above(tokenABalanceBefore);
    });

    it('Should swap exact out A to C on pool A/C', async () => {
        const tokenA = fixture.tokenA;
        const tokenC = fixture.tokenC;
        const owner = fixture.owner;

        const vRouterInstance = fixture.vRouterInstance;

        const tokenABalanceBefore = await tokenA.balanceOf(owner.address);
        const tokenCBalanceBefore = await tokenC.balanceOf(owner.address);

        const amountIn = ethers.utils.parseEther('10');

        const amountOut = await vRouterInstance.getAmountOut(
            tokenA.address,
            tokenC.address,
            amountIn
        );

        const futureTs = await utils.getFutureBlockTimestamp();

        let multiData = [];

        let str = VRouter__factory.getInterface(
            VRouter__factory.abi
        ).encodeFunctionData('swapExactOutput', [
            [tokenA.address, tokenC.address],
            amountOut,
            amountIn,
            owner.address,
            futureTs,
        ]);

        multiData.push(str);

        await vRouterInstance.multicall(multiData);
        const tokenABalanceAfter = await tokenA.balanceOf(owner.address);
        const tokenCBalanceAfter = await tokenC.balanceOf(owner.address);
        expect(tokenCBalanceAfter).to.be.above(tokenCBalanceBefore);

        expect(tokenABalanceAfter).to.lessThan(tokenABalanceBefore);
    });

    it('Should swap exact in C to A on pool A/C', async () => {
        const tokenA = fixture.tokenA;
        const tokenC = fixture.tokenC;
        const owner = fixture.owner;

        const vRouterInstance = fixture.vRouterInstance;

        const tokenABalanceBefore = await tokenA.balanceOf(owner.address);
        const tokenCBalanceBefore = await tokenC.balanceOf(owner.address);

        const amountIn = ethers.utils.parseEther('10');

        let amountOut = await vRouterInstance.getAmountOut(
            tokenC.address,
            tokenA.address,
            amountIn
        );
        const futureTs = await utils.getFutureBlockTimestamp();

        await vRouterInstance.swapExactInput(
            [tokenC.address, tokenA.address],
            amountIn,
            amountOut,
            owner.address,
            futureTs
        );
        const tokenABalanceAfter = await tokenA.balanceOf(owner.address);
        const tokenCBalanceAfter = await tokenC.balanceOf(owner.address);
        expect(tokenCBalanceAfter).to.be.lessThan(tokenCBalanceBefore);

        expect(tokenABalanceAfter).to.above(tokenABalanceBefore);
    });

    it('Should swap exact in A to C on pool A/C', async () => {
        const tokenA = fixture.tokenA;
        const tokenC = fixture.tokenC;
        const owner = fixture.owner;

        const vRouterInstance = fixture.vRouterInstance;

        const tokenABalanceBefore = await tokenA.balanceOf(owner.address);
        const tokenCBalanceBefore = await tokenC.balanceOf(owner.address);
        let multiData = [];

        const amountIn = ethers.utils.parseEther('10');

        let amountOut = await vRouterInstance.getAmountOut(
            tokenC.address,
            tokenA.address,
            amountIn
        );
        const futureTs = await utils.getFutureBlockTimestamp();

        let str = VRouter__factory.getInterface(
            VRouter__factory.abi
        ).encodeFunctionData('swapExactInput', [
            [tokenA.address, tokenC.address],
            amountIn,
            amountOut,
            owner.address,
            futureTs,
        ]);

        multiData.push(str);

        await vRouterInstance.multicall(multiData);
        const tokenABalanceAfter = await tokenA.balanceOf(owner.address);
        const tokenCBalanceAfter = await tokenC.balanceOf(owner.address);
        expect(tokenCBalanceAfter).to.be.above(tokenCBalanceBefore);

        expect(tokenABalanceAfter).to.lessThan(tokenABalanceBefore);
    });

    let amountInTokenC: any;

    it('Should swap exact out C to A on pool A/B', async () => {
        const tokenA = fixture.tokenA;
        const tokenB = fixture.tokenB;
        const tokenC = fixture.tokenC;
        const owner = fixture.owner;
        const bcPool = fixture.bcPool;

        const vRouterInstance = fixture.vRouterInstance;

        const amountOut = ethers.utils.parseEther('100');

        let amountIn = await vRouterInstance.getVirtualAmountIn(
            fixture.abPool.address,
            fixture.bcPool.address,
            amountOut
        );

        amountInTokenC = amountIn;

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
    });

    it('Should swap exact out A to C on pool B/C', async () => {
        const abPool = fixture.abPool;
        const bcPool = fixture.bcPool;

        const tokenA = fixture.tokenA;
        const tokenB = fixture.tokenB;
        const owner = fixture.owner;

        const tokenC = fixture.tokenC;
        const vRouterInstance = fixture.vRouterInstance;

        let amountIn = await vRouterInstance.getVirtualAmountIn(
            bcPool.address,
            abPool.address,
            amountInTokenC
        );

        const futureTs = await utils.getFutureBlockTimestamp();
        await vRouterInstance.swapReserveExactOutput(
            tokenB.address,
            tokenC.address,
            abPool.address,
            amountInTokenC,
            amountIn,
            owner.address,
            futureTs
        );
    });

    it('Should swap exact in C to A on pool A/B', async () => {
        const tokenA = fixture.tokenA;
        const tokenB = fixture.tokenB;
        const tokenC = fixture.tokenC;
        const owner = fixture.owner;
        const bcPool = fixture.bcPool;

        const vRouterInstance = fixture.vRouterInstance;

        const amountIn = ethers.utils.parseEther('100');

        let amountOut = await vRouterInstance.getVirtualAmountOut(
            fixture.abPool.address,
            fixture.bcPool.address,
            amountIn
        );

        amountInTokenC = amountIn;

        const futureTs = await utils.getFutureBlockTimestamp();

        await vRouterInstance.swapReserveExactInput(
            tokenA.address,
            tokenB.address,
            bcPool.address,
            amountIn,
            amountOut,
            owner.address,
            futureTs
        );
    });

    it('Should swap exact out A to C on pool B/C', async () => {
        const abPool = fixture.abPool;
        const bcPool = fixture.bcPool;

        const tokenA = fixture.tokenA;
        const tokenB = fixture.tokenB;
        const owner = fixture.owner;

        const tokenC = fixture.tokenC;
        const vRouterInstance = fixture.vRouterInstance;

        let amountOut = await vRouterInstance.getVirtualAmountOut(
            bcPool.address,
            abPool.address,
            amountInTokenC
        );

        const futureTs = await utils.getFutureBlockTimestamp();
        await vRouterInstance.swapReserveExactOutput(
            tokenB.address,
            tokenC.address,
            abPool.address,
            amountOut,
            amountInTokenC,
            owner.address,
            futureTs
        );
    });

    it('Should revent on swap exact input with invalid pool C/B on pool B/C', async () => {
        const bcPool = fixture.bcPool;

        const tokenB = fixture.tokenB;
        const owner = fixture.owner;

        const tokenC = fixture.tokenC;
        const vRouterInstance = fixture.vRouterInstance;

        let amountIn = ethers.utils.parseEther('1');

        const futureTs = await utils.getFutureBlockTimestamp();

        let reverted = false;
        try {
            await vRouterInstance.swapReserveExactInput(
                tokenC.address,
                tokenB.address,
                bcPool.address,
                amountIn,
                amountInTokenC,
                owner.address,
                futureTs
            );
        } catch {
            reverted = true;
        }

        expect(reverted).to.be.true;
    });

    it('Should Total Pool swap -> 1. C to A on pool A/C   2. C to A on pool A/B', async () => {
        const tokenA = fixture.tokenA;
        const tokenB = fixture.tokenB;
        const tokenC = fixture.tokenC;
        const abPool = fixture.abPool;
        const owner = fixture.owner;

        const bcPool = fixture.bcPool;
        const vRouterInstance = fixture.vRouterInstance;

        const _amountOut = ethers.utils.parseEther('10');

        let realAmountIn = await vRouterInstance.getAmountIn(
            tokenC.address,
            tokenA.address,
            _amountOut
        );

        let virtualIn = await vRouterInstance.getVirtualAmountIn(
            abPool.address,
            bcPool.address,
            _amountOut
        );

        const futureTs = await utils.getFutureBlockTimestamp();
        let multiData = [];

        let str = VRouter__factory.getInterface(
            VRouter__factory.abi
        ).encodeFunctionData('swapExactOutput', [
            [tokenC.address, tokenA.address],
            _amountOut,
            realAmountIn,
            owner.address,
            futureTs,
        ]);

        multiData.push(str);

        str = VRouter__factory.getInterface(
            VRouter__factory.abi
        ).encodeFunctionData('swapReserveExactOutput', [
            tokenA.address,
            tokenB.address,
            bcPool.address,
            _amountOut,
            virtualIn,
            owner.address,
            futureTs,
        ]);

        multiData.push(str);

        await vRouterInstance.multicall(multiData);
    });

    it('Should revert on swap A to C on pool A/C with insuficient input amount', async () => {
        const tokenA = fixture.tokenA;
        const tokenC = fixture.tokenC;
        const owner = fixture.owner;

        const vRouterInstance = fixture.vRouterInstance;

        let pools = [fixture.acPool.address];
        let amountsIn = ethers.utils.parseEther('10');

        const amountOut = await vRouterInstance.getAmountOut(
            tokenA.address,
            tokenC.address,
            amountsIn
        );

        amountsIn = ethers.utils.parseEther('8');

        const futureTs = await utils.getFutureBlockTimestamp();
        let reverted = false;
        try {
            await vRouterInstance.swap(
                pools,
                [amountsIn],
                [amountOut],
                ['0x0000000000000000000000000000000000000000'],
                tokenA.address,
                tokenC.address,
                owner.address,
                futureTs
            );
        } catch {
            reverted = true;
        }

        expect(reverted);
    });

    it('Should remove 1/4 liquidity', async () => {
        const abPool = fixture.abPool;
        const tokenA = fixture.tokenA;
        const tokenB = fixture.tokenB;
        const owner = fixture.owner;

        const vRouterInstance = fixture.vRouterInstance;

        let lpBalanceBefore = await abPool.balanceOf(owner.address);

        let reserve0 = await abPool.pairBalance0();
        let reserve1 = await abPool.pairBalance1();
        reserve0 = reserve0;
        reserve1 = reserve1;

        const withdrawAmount = lpBalanceBefore.div(4);

        await abPool.approve(vRouterInstance.address, lpBalanceBefore);
        //get account0 balance before
        let tokenABalanceBefore = await tokenA.balanceOf(owner.address);
        let tokenBBalanceBefore = await tokenB.balanceOf(owner.address);
        const tokenAMin = reserve0.mul(999).div(1000).div(4);
        const tokenBMin = reserve1.mul(999).div(1000).div(4);

        const futureTs = await utils.getFutureBlockTimestamp();
        await vRouterInstance.removeLiquidity(
            tokenA.address,
            tokenB.address,
            withdrawAmount,
            tokenAMin,
            tokenBMin,
            owner.address,
            futureTs
        );
        //get account0 balance before
        let tokenABalanceAfter = await tokenA.balanceOf(owner.address);
        let tokenBBalanceAfter = await tokenB.balanceOf(owner.address);

        let reserve0After = await abPool.pairBalance0();
        let reserve1After = await abPool.pairBalance1();

        reserve0After = reserve0After;
        reserve1After = reserve1After;

        expect(tokenABalanceAfter).to.be.above(tokenABalanceBefore);
        expect(tokenBBalanceAfter).to.be.above(tokenBBalanceBefore);
    });

    it('Should add liquidity', async () => {
        const tokenA = fixture.tokenA;
        const tokenB = fixture.tokenB;
        const abPool = fixture.abPool;
        const owner = fixture.owner;

        const vRouterInstance = fixture.vRouterInstance;

        let amountADesired = ethers.utils.parseEther('1');

        const amountBDesired = await vRouterInstance.quote(
            tokenA.address,
            tokenB.address,
            amountADesired
        );

        let reserve0 = await abPool.pairBalance0();
        let reserve1 = await abPool.pairBalance1();

        let totalBalanceBefore0 = reserve0;
        let totalBalanceBefore1 = reserve1;

        const futureTs = await utils.getFutureBlockTimestamp();

        await vRouterInstance.addLiquidity(
            tokenA.address,
            tokenB.address,
            amountADesired,
            amountBDesired,
            amountADesired,
            amountBDesired,
            owner.address,
            futureTs
        );

        let lpBalance = await abPool.balanceOf(owner.address);

        reserve0 = await abPool.pairBalance0();
        reserve1 = await abPool.pairBalance1();

        let totalBalanceAfter0 = reserve0;
        let totalBalanceAfter1 = reserve1;

        expect(Number(totalBalanceBefore0.toString())).to.lessThan(
            Number(totalBalanceAfter0.toString())
        );

        expect(Number(totalBalanceBefore1.toString())).to.lessThan(
            Number(totalBalanceAfter1.toString())
        );
    });

    it('Should revert when trying to provide unbalanced A amount', async function () {
        const tokenA = fixture.tokenA;
        const owner = fixture.owner;

        const tokenB = fixture.tokenB;
        const vRouterInstance = fixture.vRouterInstance;

        const amountADesired = ethers.utils.parseEther('12');

        const amountBDesired = ethers.utils.parseEther('8');
        const futureTs = await utils.getFutureBlockTimestamp();
        expect(
            vRouterInstance.addLiquidity(
                tokenA.address,
                tokenB.address,
                amountADesired,
                amountBDesired,
                amountADesired,
                amountBDesired,
                owner.address,
                futureTs
            )
        ).to.revertedWithoutReason();
    });

    it('Should revert when trying to provide unbalanced B amount', async function () {
        const owner = fixture.owner;

        const tokenA = fixture.tokenA;
        const tokenB = fixture.tokenB;
        const vRouterInstance = fixture.vRouterInstance;

        const amountADesired = ethers.utils.parseEther('1');

        const amountBDesired = ethers.utils.parseEther('4');

        const futureTs = await utils.getFutureBlockTimestamp();
        expect(
            vRouterInstance.addLiquidity(
                tokenA.address,
                tokenB.address,
                amountADesired,
                amountBDesired,
                amountADesired,
                amountBDesired,
                owner.address,
                futureTs
            )
        ).to.revertedWithoutReason();
    });

    it('Should remove all pool liquidity', async () => {
        const owner = fixture.owner;

        const abPool = fixture.abPool;
        const tokenA = fixture.tokenA;
        const tokenB = fixture.tokenB;
        const tokenC = fixture.tokenC;
        const vRouterInstance = fixture.vRouterInstance;

        let lpBalance = await abPool.balanceOf(owner.address);

        let tokenABalanceBefore = await tokenA.balanceOf(owner.address);
        let tokenBBalanceBefore = await tokenB.balanceOf(owner.address);

        let token0 = await abPool.token0();
        let token1 = await abPool.token1();
        let amountADesired = await abPool.pairBalance0();

        let amountBDesired = await vRouterInstance.quote(
            token0,
            token1,
            amountADesired
        );

        amountADesired = amountADesired.mul(999).div(1000);
        amountBDesired = amountBDesired.mul(999).div(1000);

        const cResrveRatio = await abPool.reservesBaseValue(tokenC.address);
        const userTokenCBalance = await tokenC.balanceOf(owner.address);

        let reserve0 = await abPool.pairBalance0();
        let reserve1 = await abPool.pairBalance1();

        await abPool.approve(vRouterInstance.address, lpBalance);

        const futureTs = await utils.getFutureBlockTimestamp();
        await vRouterInstance.removeLiquidity(
            tokenA.address,
            tokenB.address,
            lpBalance,
            amountADesired,
            amountBDesired,
            owner.address,
            futureTs
        );

        const cResrveRatioAfter = await abPool.reservesBaseValue(
            tokenC.address
        );

        let lpBalanceAfter = await abPool.balanceOf(owner.address);
        lpBalanceAfter = lpBalanceAfter;

        let tokenABalanceAfter = await tokenA.balanceOf(owner.address);
        let tokenBBalanceAfter = await tokenB.balanceOf(owner.address);

        tokenABalanceAfter = tokenABalanceAfter;
        tokenBBalanceAfter = tokenBBalanceAfter;

        let reserve0After = await abPool.pairBalance0();
        let reserve1After = await abPool.pairBalance1();

        const userTokenCBalanceAfter = await tokenC.balanceOf(owner.address);

        expect(lpBalanceAfter).to.equal(0);
        expect(tokenABalanceBefore).to.lessThan(tokenABalanceAfter);
        expect(tokenBBalanceBefore).to.lessThan(tokenBBalanceAfter);

        expect(reserve0After).to.lessThan(reserve0);
        expect(reserve1After).to.lessThan(reserve1);

        expect(userTokenCBalance).to.lessThan(userTokenCBalanceAfter);

        // check C reserve was updated in pool
        expect(cResrveRatioAfter).to.lessThan(cResrveRatio);
    });

    it('Should re-add liquidity', async () => {
        const abPool = fixture.abPool;
        const tokenA = fixture.tokenA;
        const tokenB = fixture.tokenB;
        const owner = fixture.owner;

        const vRouterInstance = fixture.vRouterInstance;

        let reserve0 = await abPool.pairBalance0();
        let reserve1 = await abPool.pairBalance1();

        const amountADesired = ethers.utils.parseEther('100');

        const amountBDesired = await vRouterInstance.quote(
            tokenA.address,
            tokenB.address,
            amountADesired
        );

        const futureTs = await utils.getFutureBlockTimestamp();

        await vRouterInstance.addLiquidity(
            tokenA.address,
            tokenB.address,
            amountADesired,
            amountBDesired,
            amountADesired,
            amountBDesired,
            owner.address,
            futureTs
        );

        let reserve0After = await abPool.pairBalance0();
        let reserve1After = await abPool.pairBalance1();

        let reserve0Eth, reserve1Eth, reserve0AfterEth, reserve1AfterEth;

        reserve0Eth = reserve0;
        reserve1Eth = reserve1;
        reserve0AfterEth = reserve0After;
        reserve1AfterEth = reserve1After;

        expect(reserve0Eth).to.lessThan(reserve0AfterEth);
        expect(reserve1Eth).to.lessThan(reserve1AfterEth);
    });

    it('Should change factory', async () => {
        const tokenA = fixture.tokenA;
        const vRouterInstance = fixture.vRouterInstance;

        const currentFactory = await vRouterInstance.factory();
        await vRouterInstance.changeFactory(tokenA.address);
        const newFactory = await vRouterInstance.factory();

        expect(
            currentFactory != tokenA.address && newFactory == tokenA.address
        );
    });
});

describe('vRouter 2', () => {
    let fixture: any = {};

    before(async function () {
        fixture = await loadFixture(deployPools);
    });

    it('Should swap WETH9<>B token', async () => {
        const vRouterInstance = fixture.vRouterInstance;
        const WETH9 = await vRouterInstance.WETH9();
        const tokenB = fixture.tokenB;
        const owner = fixture.owner;
        const wbPool = fixture.wbPool;

        const tokenABalanceBefore = await ethers.provider.getBalance(
            owner.address
        );
        const tokenBBalanceBefore = await tokenB.balanceOf(owner.address);

        const amountOut = ethers.utils.parseEther('10');

        let amountIn = await vRouterInstance.getAmountIn(
            WETH9,
            tokenB.address,
            amountOut
        );
        const futureTs = await utils.getFutureBlockTimestamp();

        await vRouterInstance.swapExactOutput(
            [WETH9, tokenB.address],
            amountOut,
            amountIn,
            owner.address,
            futureTs,
            { value: amountIn }
        );
        const tokenABalanceAfter = await ethers.provider.getBalance(
            owner.address
        );
        const tokenBBalanceAfter = await tokenB.balanceOf(owner.address);
        expect(tokenBBalanceAfter).to.above(tokenBBalanceBefore);
        expect(tokenABalanceAfter).to.be.lessThan(tokenABalanceBefore);
    });

    it('Should swap B<>WETH9 token', async () => {
        const vRouterInstance = fixture.vRouterInstance;
        const WETH9 = await vRouterInstance.WETH9();
        const tokenB = fixture.tokenB;
        const owner = fixture.owner;
        const wbPool = fixture.wbPool;

        const tokenABalanceBefore = await tokenB.balanceOf(owner.address);
        const tokenBBalanceBefore = await ethers.provider.getBalance(
            owner.address
        );

        const amountOut = ethers.utils.parseEther('10');

        let amountIn = await vRouterInstance.getAmountIn(
            tokenB.address,
            WETH9,
            amountOut
        );
        const futureTs = await utils.getFutureBlockTimestamp();

        await vRouterInstance.swapExactOutput(
            [tokenB.address, WETH9],
            amountOut,
            amountIn,
            owner.address,
            futureTs
        );
        const tokenABalanceAfter = await tokenB.balanceOf(owner.address);
        const tokenBBalanceAfter = await ethers.provider.getBalance(
            owner.address
        );
        expect(tokenBBalanceAfter).to.above(tokenBBalanceBefore);
        expect(tokenABalanceAfter).to.be.lessThan(tokenABalanceBefore);
    });
});

describe('vRouter: getVirtualPools', () => {
    let fixture: any = {};

    before(async function () {
        fixture = await loadFixture(deployPools);
        let allowList = [
            fixture.tokenA.address,
            fixture.tokenB.address,
            fixture.tokenC.address,
        ];
        for (let i = 0; i < 5; ++i) {
            const erc20ContractFactory = new ERC20PresetFixedSupply__factory(
                fixture.owner
            );
            const tokenI = await erc20ContractFactory.deploy(
                'token' + i,
                i.toString(),
                ethers.utils.parseEther('100000'),
                fixture.owner.address
            );
            await tokenI.approve(
                fixture.vRouterInstance.address,
                ethers.utils.parseEther('100000')
            );

            await fixture.vRouterInstance.addLiquidity(
                fixture.tokenA.address,
                tokenI.address,
                ethers.utils.parseEther('1000'),
                ethers.utils.parseEther('1000'),
                ethers.utils.parseEther('1000'),
                ethers.utils.parseEther('1000'),
                fixture.owner.address,
                (await time.latest()) + 100
            );
            allowList.push(tokenI.address);
            await fixture.vRouterInstance.addLiquidity(
                fixture.tokenD.address,
                tokenI.address,
                ethers.utils.parseEther('1000'),
                ethers.utils.parseEther('1000'),
                ethers.utils.parseEther('1000'),
                ethers.utils.parseEther('1000'),
                fixture.owner.address,
                (await time.latest()) + 100
            );
        }
        for (
            let i = 0;
            i < (await fixture.vPairFactoryInstance.allPairsLength());
            ++i
        ) {
            const pairAddr = await fixture.vPairFactoryInstance.allPairs(i);
            const pool = VPair__factory.connect(pairAddr, fixture.owner);
            await pool.setMaxAllowListCount(8);
            await pool.setAllowList(
                allowList.sort((a, b) => {
                    if (ethers.BigNumber.from(a).lt(ethers.BigNumber.from(b)))
                        return -1;
                    else if (
                        ethers.BigNumber.from(a).eq(ethers.BigNumber.from(b))
                    )
                        return 0;
                    else return 1;
                })
            );
        }
    });

    it('getVirtualPools works', async () => {
        // virtual pool AD = AX_i + X_iD where i from 0 to 5 and AB + BD
        expect(
            (
                await fixture.vRouterInstance.getVirtualPools(
                    fixture.tokenA.address,
                    fixture.tokenD.address
                )
            ).length
        ).to.equal(6);

        for (
            let i = 0;
            i < (await fixture.vPairFactoryInstance.allPairsLength());
            ++i
        ) {
            const pairAddr = await fixture.vPairFactoryInstance.allPairs(i);
            const pool = VPair__factory.connect(pairAddr, fixture.owner);
            await pool.setAllowList([fixture.tokenD.address]);
        }

        // A is not in a allow list so there is 0 virtual pools AD
        expect(
            (
                await fixture.vRouterInstance.getVirtualPools(
                    fixture.tokenA.address,
                    fixture.tokenD.address
                )
            ).length
        ).to.equal(0);
    });
});

describe('vRouter: getVirtualMaxTradeAmount', () => {
    let fixture: any = {};
    let tokenNumber = 1;
    let tokenA: any;
    let tokenB: any;
    let tokenC: any;

    let deployPoolsWithAmounts = async function (
        amountA: string,
        amountB: string,
        amountC: string
    ) {
        const issueAmount = ethers.utils.parseEther(
            '100000000000000000000000000000000000'
        );
        const erc20ContractFactory = new ERC20PresetFixedSupply__factory(
            fixture.owner
        );
        tokenA = await erc20ContractFactory.deploy(
            `token ${tokenNumber}`,
            `${tokenNumber++}`,
            issueAmount,
            fixture.owner.address
        );
        tokenB = await erc20ContractFactory.deploy(
            `token ${tokenNumber}`,
            `${tokenNumber++}`,
            issueAmount,
            fixture.owner.address
        );
        tokenC = await erc20ContractFactory.deploy(
            `token ${tokenNumber}`,
            `${tokenNumber++}`,
            issueAmount,
            fixture.owner.address
        );

        await tokenA.approve(fixture.vRouterInstance.address, issueAmount);
        await tokenB.approve(fixture.vRouterInstance.address, issueAmount);
        await tokenC.approve(fixture.vRouterInstance.address, issueAmount);

        const vPairFactoryInstance = fixture.vPairFactoryInstance;

        await vPairFactoryInstance.setDefaultAllowList(
            [tokenA.address, tokenB.address, tokenC.address].sort((a, b) => {
                if (ethers.BigNumber.from(a).lt(ethers.BigNumber.from(b)))
                    return -1;
                else if (ethers.BigNumber.from(a).eq(ethers.BigNumber.from(b)))
                    return 0;
                else return 1;
            })
        );

        const futureTs = (await time.latest()) + 1000000;

        await fixture.vRouterInstance.addLiquidity(
            tokenA.address,
            tokenB.address,
            ethers.utils.parseEther(amountA),
            ethers.utils.parseEther(amountB),
            ethers.utils.parseEther(amountA),
            ethers.utils.parseEther(amountB),
            fixture.owner.address,
            futureTs
        );
        await fixture.vRouterInstance.addLiquidity(
            tokenB.address,
            tokenC.address,
            ethers.utils.parseEther(amountB),
            ethers.utils.parseEther(amountC),
            ethers.utils.parseEther(amountB),
            ethers.utils.parseEther(amountC),
            fixture.owner.address,
            futureTs
        );

        const addr1 = await vPairFactoryInstance.pairs(
            tokenA.address,
            tokenB.address
        );
        const addr2 = await vPairFactoryInstance.pairs(
            tokenB.address,
            tokenC.address
        );
        const abPool = VPair__factory.connect(addr1, fixture.owner);
        const bcPool = VPair__factory.connect(addr2, fixture.owner);

        return { abPool, bcPool };
    };

    before(async function () {
        fixture = await loadFixture(deployPools);
    });

    it('Small pool balances', async () => {
        const pools = await deployPoolsWithAmounts('3', '1', '7');
        const vRouterInstance = fixture.vRouterInstance;
        let amountIn = await vRouterInstance.getMaxVirtualTradeAmountRtoN(
            pools.bcPool.address,
            pools.abPool.address
        );
        let amountOut = await vRouterInstance.getVirtualAmountOut(
            pools.bcPool.address,
            pools.abPool.address,
            amountIn
        );
        await vRouterInstance.swapReserveExactInput(
            tokenC.address,
            tokenB.address,
            pools.abPool.address,
            amountIn,
            amountOut,
            fixture.owner.address,
            (await time.latest()) + 100000
        );
        expect(await pools.bcPool.calculateReserveRatio()).to.be.below('2001');
        expect(await pools.bcPool.calculateReserveRatio()).to.be.above('1998');
    });

    it('Medium pool balances', async () => {
        const pools = await deployPoolsWithAmounts(
            '7000000',
            '1000000',
            '3000000'
        );
        const vRouterInstance = fixture.vRouterInstance;
        let amountIn = await vRouterInstance.getMaxVirtualTradeAmountRtoN(
            pools.abPool.address,
            pools.bcPool.address
        );
        let amountOut = await vRouterInstance.getVirtualAmountOut(
            pools.abPool.address,
            pools.bcPool.address,
            amountIn
        );
        await vRouterInstance.swapReserveExactInput(
            tokenA.address,
            tokenB.address,
            pools.bcPool.address,
            amountIn,
            amountOut,
            fixture.owner.address,
            (await time.latest()) + 100000
        );
        expect(await pools.abPool.calculateReserveRatio()).to.be.below('2001');
        expect(await pools.abPool.calculateReserveRatio()).to.be.above('1998');
    });

    it('Large pool balances', async () => {
        const pools = await deployPoolsWithAmounts(
            '9000000000000',
            '1000000000000',
            '5000000000000'
        );
        const vRouterInstance = fixture.vRouterInstance;
        let amountIn = await vRouterInstance.getMaxVirtualTradeAmountRtoN(
            pools.abPool.address,
            pools.bcPool.address
        );
        let amountOut = await vRouterInstance.getVirtualAmountOut(
            pools.abPool.address,
            pools.bcPool.address,
            amountIn
        );
        await vRouterInstance.swapReserveExactInput(
            tokenA.address,
            tokenB.address,
            pools.bcPool.address,
            amountIn,
            amountOut,
            fixture.owner.address,
            (await time.latest()) + 100000
        );
        expect(await pools.abPool.calculateReserveRatio()).to.be.below('2001');
        expect(await pools.abPool.calculateReserveRatio()).to.be.above('1998');
    });

    it('The first balance is greater than the second', async () => {
        const pools = await deployPoolsWithAmounts(
            '100',
            '100000000',
            '1000000000000'
        );
        const vRouterInstance = fixture.vRouterInstance;
        let amountIn = await vRouterInstance.getMaxVirtualTradeAmountRtoN(
            pools.abPool.address,
            pools.bcPool.address
        );
        let amountOut = await vRouterInstance.getVirtualAmountOut(
            pools.abPool.address,
            pools.bcPool.address,
            amountIn
        );
        await vRouterInstance.swapReserveExactInput(
            tokenA.address,
            tokenB.address,
            pools.bcPool.address,
            amountIn,
            amountOut,
            fixture.owner.address,
            (await time.latest()) + 100000
        );
        expect(await pools.abPool.calculateReserveRatio()).to.be.below('2001');
        expect(await pools.abPool.calculateReserveRatio()).to.be.above('1998');
    });

    it('The second balance is greater than the first', async () => {
        const pools = await deployPoolsWithAmounts(
            '1000000000000',
            '100000000',
            '100'
        );
        const vRouterInstance = fixture.vRouterInstance;
        let amountIn = await vRouterInstance.getMaxVirtualTradeAmountRtoN(
            pools.abPool.address,
            pools.bcPool.address
        );
        let amountOut = await vRouterInstance.getVirtualAmountOut(
            pools.abPool.address,
            pools.bcPool.address,
            amountIn
        );
        await vRouterInstance.swapReserveExactInput(
            tokenA.address,
            tokenB.address,
            pools.bcPool.address,
            amountIn,
            amountOut,
            fixture.owner.address,
            (await time.latest()) + 100000
        );
        expect(await pools.abPool.calculateReserveRatio()).to.be.below('2001');
        expect(await pools.abPool.calculateReserveRatio()).to.be.above('1998');
    });

    it('Swap maximum twice', async () => {
        const pools = await deployPoolsWithAmounts(
            '9000000000000',
            '1000000000000',
            '7000000000000'
        );
        const vRouterInstance = fixture.vRouterInstance;
        let amountIn = await vRouterInstance.getMaxVirtualTradeAmountRtoN(
            pools.abPool.address,
            pools.bcPool.address
        );
        let amountOut = await vRouterInstance.getVirtualAmountOut(
            pools.abPool.address,
            pools.bcPool.address,
            amountIn
        );

        await vRouterInstance.swapReserveExactInput(
            tokenA.address,
            tokenB.address,
            pools.bcPool.address,
            amountIn,
            amountOut,
            fixture.owner.address,
            (await time.latest()) + 100000
        );

        await mine();
        amountIn = await vRouterInstance.getMaxVirtualTradeAmountRtoN(
            pools.abPool.address,
            pools.bcPool.address
        );

        amountOut = await vRouterInstance.getVirtualAmountOut(
            pools.abPool.address,
            pools.bcPool.address,
            amountIn
        );

        await vRouterInstance.swapReserveExactInput(
            tokenA.address,
            tokenB.address,
            pools.bcPool.address,
            amountIn,
            amountOut,
            fixture.owner.address,
            (await time.latest()) + 100000
        );
        expect(await pools.abPool.calculateReserveRatio()).to.be.below('2001');
        expect(await pools.abPool.calculateReserveRatio()).to.be.above('1998');
    });

    it('Swap twice by halfs', async () => {
        const pools = await deployPoolsWithAmounts(
            '9000000000000',
            '1000000000000',
            '8000000000000'
        );
        const vRouterInstance = fixture.vRouterInstance;
        let amountIn = await vRouterInstance.getMaxVirtualTradeAmountRtoN(
            pools.abPool.address,
            pools.bcPool.address
        );
        amountIn = amountIn.div(ethers.BigNumber.from('2'));
        let amountOut = await vRouterInstance.getVirtualAmountOut(
            pools.abPool.address,
            pools.bcPool.address,
            amountIn
        );
        await vRouterInstance.swapReserveExactInput(
            tokenA.address,
            tokenB.address,
            pools.bcPool.address,
            amountIn,
            amountOut,
            fixture.owner.address,
            (await time.latest()) + 100000
        );

        await mine();
        amountIn = await vRouterInstance.getMaxVirtualTradeAmountRtoN(
            pools.abPool.address,
            pools.bcPool.address
        );
        amountOut = await vRouterInstance.getVirtualAmountOut(
            pools.abPool.address,
            pools.bcPool.address,
            amountIn
        );
        await vRouterInstance.swapReserveExactInput(
            tokenA.address,
            tokenB.address,
            pools.bcPool.address,
            amountIn,
            amountOut,
            fixture.owner.address,
            (await time.latest()) + 100000
        );
        expect(await pools.abPool.calculateReserveRatio()).to.be.below('2001');
        expect(await pools.abPool.calculateReserveRatio()).to.be.above('1998');
    });
});

describe('vRouter: swap with multiple hops', () => {
    let fixture: any = {};

    before(async function () {
        fixture = await loadFixture(deployPools);
    });

    it('Should swap exact out C to A through B', async () => {
        const tokenA = fixture.tokenA;
        const tokenC = fixture.tokenC;
        const tokenB = fixture.tokenB;
        const owner = fixture.owner;

        const vRouterInstance = fixture.vRouterInstance;

        const tokenABalanceBefore = await tokenA.balanceOf(owner.address);
        const tokenBBalanceBefore = await tokenB.balanceOf(owner.address);
        const tokenCBalanceBefore = await tokenC.balanceOf(owner.address);

        const amountOut = ethers.utils.parseEther('10');

        let amountInBA = await vRouterInstance.getAmountIn(
            tokenB.address,
            tokenA.address,
            amountOut
        );
        let amountInCB = await vRouterInstance.getAmountIn(
            tokenC.address,
            tokenB.address,
            amountInBA
        );
        const futureTs = await utils.getFutureBlockTimestamp();

        await vRouterInstance.swapExactOutput(
            [tokenC.address, tokenB.address, tokenA.address],
            amountOut,
            amountInCB,
            owner.address,
            futureTs
        );
        const tokenABalanceAfter = await tokenA.balanceOf(owner.address);
        const tokenBBalanceAfter = await tokenB.balanceOf(owner.address);
        const tokenCBalanceAfter = await tokenC.balanceOf(owner.address);
        expect(tokenCBalanceAfter).to.be.lessThan(tokenCBalanceBefore);
        expect(tokenBBalanceAfter).to.be.equal(tokenBBalanceBefore);
        expect(tokenABalanceAfter).to.above(tokenABalanceBefore);
    });

    it('Should fail if maxAmountIn is not satisfied', async () => {
        const tokenA = fixture.tokenA;
        const tokenC = fixture.tokenC;
        const tokenB = fixture.tokenB;
        const owner = fixture.owner;

        const vRouterInstance = fixture.vRouterInstance;

        const amountOut = ethers.utils.parseEther('10');

        let amountInBA = await vRouterInstance.getAmountIn(
            tokenB.address,
            tokenA.address,
            amountOut
        );
        let amountInCB = await vRouterInstance.getAmountIn(
            tokenC.address,
            tokenB.address,
            amountInBA
        );
        const futureTs = await utils.getFutureBlockTimestamp();

        await expect(
            vRouterInstance.swapExactOutput(
                [tokenC.address, tokenB.address, tokenA.address],
                amountOut,
                amountInCB.sub(1),
                owner.address,
                futureTs
            )
        ).to.revertedWith('VSWAP: REQUIRED_AMOUNT_EXCEEDS');
    });

    it('Should swap exact in C to A through B', async () => {
        const tokenA = fixture.tokenA;
        const tokenC = fixture.tokenC;
        const tokenB = fixture.tokenB;
        const owner = fixture.owner;

        const vRouterInstance = fixture.vRouterInstance;

        const tokenABalanceBefore = await tokenA.balanceOf(owner.address);
        const tokenBBalanceBefore = await tokenB.balanceOf(owner.address);
        const tokenCBalanceBefore = await tokenC.balanceOf(owner.address);

        const amountIn = ethers.utils.parseEther('10');

        let amountOutCB = await vRouterInstance.getAmountOut(
            tokenC.address,
            tokenB.address,
            amountIn
        );
        let amountOutBA = await vRouterInstance.getAmountOut(
            tokenB.address,
            tokenA.address,
            amountOutCB
        );
        const futureTs = await utils.getFutureBlockTimestamp();

        await vRouterInstance.swapExactInput(
            [tokenC.address, tokenB.address, tokenA.address],
            amountIn,
            amountOutBA,
            owner.address,
            futureTs
        );
        const tokenABalanceAfter = await tokenA.balanceOf(owner.address);
        const tokenBBalanceAfter = await tokenB.balanceOf(owner.address);
        const tokenCBalanceAfter = await tokenC.balanceOf(owner.address);
        expect(tokenCBalanceAfter).to.be.lessThan(tokenCBalanceBefore);
        expect(tokenBBalanceAfter).to.be.equal(tokenBBalanceBefore);
        expect(tokenABalanceAfter).to.above(tokenABalanceBefore);
    });

    it('Should fail if minAmountOut is not satisfied', async () => {
        const tokenA = fixture.tokenA;
        const tokenC = fixture.tokenC;
        const tokenB = fixture.tokenB;
        const owner = fixture.owner;

        const vRouterInstance = fixture.vRouterInstance;

        const amountIn = ethers.utils.parseEther('10');

        let amountOutCB = await vRouterInstance.getAmountOut(
            tokenC.address,
            tokenB.address,
            amountIn
        );
        let amountOutBA = await vRouterInstance.getAmountOut(
            tokenB.address,
            tokenA.address,
            amountOutCB
        );
        const futureTs = await utils.getFutureBlockTimestamp();

        await expect(
            vRouterInstance.swapExactInput(
                [tokenC.address, tokenB.address, tokenA.address],
                amountIn,
                amountOutBA.add(1),
                owner.address,
                futureTs
            )
        ).to.revertedWith('VSWAP: INSUFFICIENT_INPUT_AMOUNT');
    });
});
