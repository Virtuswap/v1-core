import { loadFixture } from '@nomicfoundation/hardhat-network-helpers';
import { expect } from 'chai';
import { deployAdapter } from './fixtures/deployAdapter';

describe('Base actions', function () {
    it('Should deploy fixture', async function () {
        const fixture = await loadFixture(deployAdapter);

        expect(fixture.tokenA.address.length > 0);
        expect(fixture.tokenB.address.length > 0);
        expect(fixture.weth9.address.length > 0);
        expect(fixture.vRouterMock.address.length > 0);
        expect(fixture.adapter.address.length > 0);
    });
});
