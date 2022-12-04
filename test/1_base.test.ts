import { loadFixture } from '@nomicfoundation/hardhat-network-helpers';
import { expect } from 'chai';
import { deployPools } from './fixtures/deployPools';

describe('Base actions', function () {
    it('Should deploy fixture', async function () {
        const fixture = await loadFixture(deployPools);

        const initHash = await fixture.vPairFactoryInstance.getInitCodeHash();
        console.log('initHash ' + initHash);

        expect(fixture.tokenA.address.length > 0);
        expect(fixture.tokenB.address.length > 0);
        expect(fixture.tokenC.address.length > 0);
        expect(fixture.vRouterInstance.address.length > 0);
        expect(fixture.vPairFactoryInstance.address.length > 0);
        expect(fixture.abPool.address.length > 0);
        expect(fixture.bcPool.address.length > 0);
        expect(fixture.acPool.address.length > 0);
    });
});
