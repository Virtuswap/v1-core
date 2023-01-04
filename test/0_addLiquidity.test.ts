import { loadFixture } from '@nomicfoundation/hardhat-network-helpers';
import { expect } from 'chai';
import { ethers } from 'hardhat';
import { deployPools } from './fixtures/deployPools';

import _ from 'lodash';
import utils from './utils';

describe('vRouter 1', () => {
    let fixture: any = {};

    before(async function () {
        fixture = await loadFixture(deployPools);
    });

    it('Should add liquidity to pool AB', async function () {
        const futureTs = await utils.getFutureBlockTimestamp();

        const amountA = ethers.utils.parseEther('100'.toString());
        const amountBDesired = await fixture.vRouterInstance.quote(
            fixture.tokenA.address,
            fixture.tokenB.address,
            amountA
        );

        console.log(
            'amountBDesired ' + ethers.utils.formatEther(amountBDesired)
        );

        await fixture.vRouterInstance.addLiquidity(
            fixture.tokenA.address,
            fixture.tokenB.address,
            amountA,
            amountBDesired,
            amountA,
            amountBDesired,
            fixture.owner.address,
            futureTs
        );

        let aBalance2 = await fixture.tokenA.balanceOf(fixture.abPool.address);
        console.log(ethers.utils.formatEther(aBalance2));
    });
});
