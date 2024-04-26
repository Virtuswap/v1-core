import { ethers } from 'hardhat';
import type { SignerWithAddress } from '@nomiclabs/hardhat-ethers/signers';
import { loadFixture } from '@nomicfoundation/hardhat-network-helpers';
import { expect } from 'chai';
import { deployAdapter } from './fixtures/deployAdapter';

const abiCoder = ethers.utils.defaultAbiCoder;

const RealPoolDataTypesInfo = [
    `tuple(bytes4 functionSelector, address path0, address path1, uint256 deadline)`,
] as const;

const VirtualPoolDataTypesInfo = [
    `tuple(bytes4 functionSelector, address tokenOut, address commonToken, address ikPair, uint256 deadline)`,
] as const;

describe('VirtuSwapAdapter', function () {
    let fixture: Awaited<ReturnType<typeof deployAdapter>>;
    let accounts: SignerWithAddress[];
    let owner: SignerWithAddress;

    beforeEach(async function () {
        fixture = await loadFixture(deployAdapter);
        accounts = fixture.accounts;
        owner = fixture.owner;
    });

    it('Should revert on initialize', async function () {
        const { adapter } = fixture;

        await expect(
            adapter.connect(owner).initialize('0x00')
        ).to.revertedWith('METHOD NOT IMPLEMENTED');
    });

    describe('swap', function() {
        it('Should revert if wrong index', async function() {
            const { adapter } = fixture;

            await expect(
                adapter.connect(accounts[0]).swap(
                    fixture.tokenA.address,
                    fixture.tokenB.address,
                    ethers.utils.parseEther('10'),
                    ethers.utils.parseEther('10'),
                    [{
                        index: 12345,
                        targetExchange: fixture.vRouterMock.address,
                        percent: 10000,
                        payload: '0x00',
                        networkFee: 0,
                    }],
                    {
                        value: 0,
                    }
                )
            ).to.revertedWith('Index not supported');
        });

        describe('Real pools', function() {
            const functions = [
                'swapExactETHForTokens',
                'swapExactTokensForETH',
                'swapExactTokensForTokens',
            ] as const;

            functions.forEach(functionName => {
                it(`Should call ${functionName}`, async function() {
                    const { adapter, vRouterMock } = fixture;

                    // get selector by functionName from vRouterMock
                    const selector = vRouterMock.interface.getSighash(functionName);

                    const payload = abiCoder.encode(
                        RealPoolDataTypesInfo,
                        [{
                            functionSelector: selector,
                            path0: fixture.tokenA.address,
                            path1: fixture.tokenB.address,
                            deadline: fixture.deadline,
                        }]
                    );

                    const isFromEth = functionName.startsWith('swapExactETH');

                    expect(await vRouterMock.functionCalled(selector)).to.be.false;

                    await adapter.connect(accounts[0]).swap(
                        fixture.tokenA.address,
                        fixture.tokenB.address,
                        ethers.utils.parseEther('10'),
                        ethers.utils.parseEther('10'),
                        [{
                            index: 1,
                            targetExchange: vRouterMock.address,
                            percent: 10000,
                            payload: payload,
                            networkFee: 0,
                        }],
                        {
                            value: isFromEth ? ethers.utils.parseEther('10') : 0,
                        }
                    );

                    expect(await vRouterMock.functionCalled(selector)).to.be.true;
                });
            });
        });

        describe('Virtual pools', function() {
            const functions = [
                'swapReserveExactTokensForETH',
                'swapReserveExactETHForTokens',
                'swapReserveExactTokensForTokens',
            ] as const;

            functions.forEach(functionName => {
                it(`Should call ${functionName}`, async function() {
                    const { adapter, vRouterMock } = fixture;

                    // get selector by functionName from vRouterMock
                    const selector = vRouterMock.interface.getSighash(functionName);

                    const payload = abiCoder.encode(
                        VirtualPoolDataTypesInfo,
                        [{
                            functionSelector: selector,
                            tokenOut: fixture.tokenB.address,
                            commonToken: fixture.tokenA.address,
                            ikPair: ethers.constants.AddressZero, // ikPair is ignored in this test
                            deadline: fixture.deadline,
                        }]
                    );

                    const isFromEth = functionName.startsWith('swapReserveExactETH');

                    expect(await vRouterMock.functionCalled(selector)).to.be.false;

                    await adapter.connect(accounts[0]).swap(
                        fixture.tokenA.address,
                        fixture.tokenB.address,
                        ethers.utils.parseEther('10'),
                        ethers.utils.parseEther('10'),
                        [{
                            index: 1,
                            targetExchange: vRouterMock.address,
                            percent: 10000,
                            payload: payload,
                            networkFee: 0,
                        }],
                        {
                            value: isFromEth ? ethers.utils.parseEther('10') : 0,
                        }
                    );

                    expect(await vRouterMock.functionCalled(selector)).to.be.true;
                });
            });
        });
    });

    describe('buy', function() {
        it('Should revert if wrong index', async function() {
            const { adapter, vRouterMock } = fixture;

            await expect(
                adapter.connect(accounts[0]).buy(
                    12345,
                    fixture.tokenA.address,
                    fixture.tokenB.address,
                    ethers.utils.parseEther('10'),
                    ethers.utils.parseEther('10'),
                    vRouterMock.address,
                    '0x00'
                )
            ).to.revertedWith('Index not supported');
        });

        describe('Real pools', function() {
            const functions = [
                'swapETHForExactTokens',
                'swapTokensForExactETH',
                'swapTokensForExactTokens',
            ] as const;

            functions.forEach(functionName => {
                it(`Should call ${functionName}`, async function() {
                    const { adapter, vRouterMock } = fixture;

                    // get selector by functionName from vRouterMock
                    const selector = vRouterMock.interface.getSighash(functionName);

                    const payload = abiCoder.encode(
                        RealPoolDataTypesInfo,
                        [{
                            functionSelector: selector,
                            path0: fixture.tokenA.address,
                            path1: fixture.tokenB.address,
                            deadline: fixture.deadline,
                        }]
                    );

                    const isFromEth = functionName.startsWith('swapETH');

                    expect(await vRouterMock.functionCalled(selector)).to.be.false;

                    await adapter.connect(accounts[0]).buy(
                        1,
                        fixture.tokenA.address,
                        fixture.tokenB.address,
                        ethers.utils.parseEther('10'),
                        ethers.utils.parseEther('10'),
                        vRouterMock.address,
                        payload,
                        {
                            value: isFromEth ? ethers.utils.parseEther('10') : 0,
                        }
                    );

                    expect(await vRouterMock.functionCalled(selector)).to.be.true;
                });
            });
        });

        describe('Virtual pools', function() {
            const functions = [
                'swapReserveETHForExactTokens',
                'swapReserveTokensForExactETH',
                'swapReserveTokensForExactTokens',
            ] as const;

            functions.forEach(functionName => {
                it(`Should call ${functionName}`, async function() {
                    const { adapter, vRouterMock } = fixture;

                    // get selector by functionName from vRouterMock
                    const selector = vRouterMock.interface.getSighash(functionName);

                    const payload = abiCoder.encode(
                        VirtualPoolDataTypesInfo,
                        [{
                            functionSelector: selector,
                            tokenOut: fixture.tokenB.address,
                            commonToken: fixture.tokenA.address,
                            ikPair: ethers.constants.AddressZero, // ikPair is ignored in this test
                            deadline: fixture.deadline,
                        }]
                    );

                    const isFromEth = functionName.startsWith('swapReserveETH');

                    expect(await vRouterMock.functionCalled(selector)).to.be.false;

                    await adapter.connect(accounts[0]).buy(
                        1,
                        fixture.tokenA.address,
                        fixture.tokenB.address,
                        ethers.utils.parseEther('10'),
                        ethers.utils.parseEther('10'),
                        vRouterMock.address,
                        payload,
                        {
                            value: isFromEth ? ethers.utils.parseEther('10') : 0,
                        }
                    );

                    expect(await vRouterMock.functionCalled(selector)).to.be.true;
                });
            });
        });
    });
});
