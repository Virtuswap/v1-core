import { loadFixture } from '@nomicfoundation/hardhat-network-helpers';
import { expect } from 'chai';
import { ethers } from 'hardhat';
import { deployPools } from './fixtures/deployPools';
import {
    IERC20Metadata__factory,
    VPair__factory,
} from '../typechain-types/index';
import _ from 'lodash';

describe('vPair1', () => {
    let accounts: any = [];
    let fixture: any = {};

    before(async function () {
        fixture = await loadFixture(deployPools);
    });

    it('Should swap native A to B on pool A/B', async () => {
        accounts = _.map(fixture.accounts, 'address');
        const abPool = fixture.abPool;
        const tokenA = fixture.tokenA;
        const owner = fixture.owner;
        const tokenB = fixture.tokenB;

        const aBalancePoolBefore = await tokenB.balanceOf(abPool.address);
        const bBalancePoolBefore = await tokenA.balanceOf(abPool.address);
        const aBalanceWalletBefore = await tokenB.balanceOf(owner.address);
        const bBalanceWalletBefore = await tokenA.balanceOf(owner.address);
        let aAmountOut = ethers.utils.parseEther('10');

        let amountIn = await fixture.vRouterInstance.getAmountIn(
            tokenA.address,
            tokenB.address,
            aAmountOut
        );

        await tokenA.transfer(abPool.address, amountIn);

        await abPool.swapNative(aAmountOut, tokenB.address, owner.address, []);

        const aBalancePoolAfter = await tokenB.balanceOf(abPool.address);
        const bBalancePoolAfter = await tokenA.balanceOf(abPool.address);
        const aBalanceWalletAfter = await tokenB.balanceOf(owner.address);
        const bBalanceWalletAfter = await tokenA.balanceOf(owner.address);

        expect(aBalancePoolBefore).to.be.above(aBalancePoolAfter);
        expect(bBalancePoolBefore).to.be.lessThan(bBalancePoolAfter);

        expect(aBalanceWalletBefore).to.be.lessThan(aBalanceWalletAfter);
        expect(bBalanceWalletBefore).to.be.above(bBalanceWalletAfter);
    });

    it('Should swap native B to A on pool A/B', async () => {
        const abPool = fixture.abPool;
        const tokenA = fixture.tokenA;
        const owner = fixture.owner;
        const tokenB = fixture.tokenB;

        const aBalancePoolBefore = await tokenA.balanceOf(abPool.address);
        const bBalancePoolBefore = await tokenB.balanceOf(abPool.address);
        const aBalanceWalletBefore = await tokenA.balanceOf(owner.address);
        const bBalanceWalletBefore = await tokenB.balanceOf(owner.address);

        let aAmountOut = ethers.utils.parseEther('10');

        let amountIn = await fixture.vRouterInstance.getAmountIn(
            tokenB.address,
            tokenA.address,
            aAmountOut
        );

        await tokenB.transfer(abPool.address, amountIn);

        await abPool.swapNative(aAmountOut, tokenA.address, owner.address, []);

        const aBalancePoolAfter = await tokenA.balanceOf(abPool.address);
        const bBalancePoolAfter = await tokenB.balanceOf(abPool.address);
        const aBalanceWalletAfter = await tokenA.balanceOf(owner.address);
        const bBalanceWalletAfter = await tokenB.balanceOf(owner.address);

        expect(aBalancePoolBefore).to.be.above(aBalancePoolAfter);
        expect(bBalancePoolBefore).to.be.lessThan(bBalancePoolAfter);
        expect(aBalanceWalletBefore).to.be.lessThan(aBalanceWalletAfter);
        expect(bBalanceWalletBefore).to.be.above(bBalanceWalletAfter);
    });

    it('Should swap reserve-to-native C to A on pool A/B', async () => {
        const abPool = fixture.abPool;
        const tokenA = fixture.tokenA;
        const owner = fixture.owner;
        const tokenB = fixture.tokenB;
        const tokenC = fixture.tokenC;
        const vPairFactoryInstance = fixture.vPairFactoryInstance;
        const vRouterInstance = fixture.vRouterInstance;

        const aBalancePoolBefore = await tokenA.balanceOf(abPool.address);
        const bBalancePoolBefore = await tokenC.balanceOf(abPool.address);
        const aBalanceWalletBefore = await tokenA.balanceOf(owner.address);
        const bBalanceWalletBefore = await tokenC.balanceOf(owner.address);

        let aAmountOut = ethers.utils.parseEther('1000');

        let jkAddress = await vPairFactoryInstance.getPair(
            tokenB.address,
            tokenA.address
        );

        let ikAddress = await vPairFactoryInstance.getPair(
            tokenB.address,
            tokenC.address
        );

        let amountIn = await vRouterInstance.getVirtualAmountIn(
            jkAddress,
            ikAddress,
            aAmountOut
        );

        await tokenC.transfer(abPool.address, amountIn);

        await abPool.swapReserveToNative(
            aAmountOut,
            ikAddress,
            owner.address,
            []
        );

        const aBalancePoolAfter = await tokenA.balanceOf(abPool.address);
        const bBalancePoolAfter = await tokenC.balanceOf(abPool.address);
        const aBalanceWalletAfter = await tokenA.balanceOf(owner.address);
        const bBalanceWalletAfter = await tokenC.balanceOf(owner.address);

        expect(aBalancePoolBefore).to.be.above(aBalancePoolAfter);
        expect(bBalancePoolBefore).to.be.lessThan(bBalancePoolAfter);
        expect(aBalanceWalletBefore).to.be.lessThan(aBalanceWalletAfter);
        expect(bBalanceWalletBefore).to.be.above(bBalanceWalletAfter);

        let amountOut = await abPool.reserves(tokenC.address);
    });

    it('Should swap native-to-reserve A to C on pool A/B', async () => {
        const abPool = fixture.abPool;
        const bcPool = fixture.bcPool;

        const tokenA = fixture.tokenA;
        const owner = fixture.owner;
        const tokenC = fixture.tokenC;
        const vPairFactoryInstance = fixture.vPairFactoryInstance;
        const vRouterInstance = fixture.vRouterInstance;

        await vPairFactoryInstance.setExchangeReservesAddress(owner.address);

        let amountOut = await abPool.reserves(tokenC.address);

        let amountIn = await vRouterInstance.getVirtualAmountIn(
            abPool.address,
            bcPool.address,
            amountOut
        );

        let reserveRatioBefore = await abPool.calculateReserveRatio();
        let tokenAReserve = await abPool.reservesBaseValue(tokenC.address);

        await tokenA.transfer(abPool.address, amountIn);

        await abPool.swapNativeToReserve(
            amountOut,
            bcPool.address,
            owner.address,
            []
        );

        let reserveRatioAfter = await abPool.calculateReserveRatio();

        expect(reserveRatioAfter).to.lessThan(reserveRatioBefore);

        let tokenAReserveAfter = await abPool.reservesBaseValue(tokenC.address);
        expect(tokenAReserveAfter).to.lessThan(tokenAReserve);
    });

    it('Should set max whitelist count', async () => {
        const abPool = fixture.abPool;

        const maxWhitelist = await abPool.maxAllowListCount();

        await abPool.setMaxAllowListCount(maxWhitelist - 1);

        const maxWhitelistAfter = await abPool.maxAllowListCount();

        expect(maxWhitelist - 1).to.equal(maxWhitelistAfter);
    });

    it('Should set whitelist', async () => {
        const abPool = fixture.abPool;
        const owner = fixture.owner;

        await abPool.setAllowList(accounts.slice(1, 4), {
            from: owner.address,
        });
        const response1 = await abPool.allowListMap(accounts[1]);
        const response2 = await abPool.allowListMap(accounts[2]);
        const response3 = await abPool.allowListMap(accounts[3]);

        expect(response1).to.be.true;
        expect(response2).to.be.true;
        expect(response3).to.be.true;
    });

    it('Should assert old whitelist is obsolete after re-setting', async () => {
        const abPool = fixture.abPool;
        const owner = fixture.owner;

        await abPool.setAllowList(accounts.slice(1, 5));

        let response1 = await abPool.allowListMap(accounts[1]);
        let response2 = await abPool.allowListMap(accounts[2]);
        let response3 = await abPool.allowListMap(accounts[3]);
        let response4 = await abPool.allowListMap(accounts[4]);
        let response5 = await abPool.allowListMap(accounts[5]);
        let response6 = await abPool.allowListMap(accounts[6]);
        let response7 = await abPool.allowListMap(accounts[7]);
        let response8 = await abPool.allowListMap(accounts[8]);

        expect(response1).to.be.true;
        expect(response2).to.be.true;
        expect(response3).to.be.true;
        expect(response4).to.be.true;
        expect(response5).to.be.false;
        expect(response6).to.be.false;
        expect(response7).to.be.false;
        expect(response8).to.be.false;

        await abPool.setAllowList(accounts.slice(5, 9), {
            from: owner.address,
        });

        response1 = await abPool.allowListMap(accounts[1]);
        response2 = await abPool.allowListMap(accounts[2]);
        response3 = await abPool.allowListMap(accounts[3]);
        response4 = await abPool.allowListMap(accounts[4]);
        response5 = await abPool.allowListMap(accounts[5]);
        response6 = await abPool.allowListMap(accounts[6]);
        response7 = await abPool.allowListMap(accounts[7]);
        response8 = await abPool.allowListMap(accounts[8]);

        expect(response1).to.be.false;
        expect(response2).to.be.false;
        expect(response3).to.be.false;
        expect(response4).to.be.false;

        expect(response5).to.be.true;
        expect(response6).to.be.true;
        expect(response7).to.be.true;
        expect(response8).to.be.true;
    });

    it('Should not set allowList if list is longer then maxAllowList', async () => {
        const abPool = fixture.abPool;

        await abPool.setMaxAllowListCount(1);
        await expect(abPool.setAllowList(accounts.slice(1, 9))).to.revertedWith(
            'MW'
        );
    });

    it('Should not set allowlist if not admin', async () => {
        const abPool = fixture.abPool;
        const abPoolSigner2 = VPair__factory.connect(
            abPool.address,
            fixture.accounts[2]
        );

        await expect(
            abPoolSigner2.setAllowList(accounts.slice(1, 5))
        ).to.revertedWith('OA');
    });

    it('Should set fee', async () => {
        const abPool = fixture.abPool;

        const feeChange = 999;
        const vFeeChange = 300;
        await abPool.setFee(feeChange, vFeeChange);

        const fee = await abPool.fee();
        const vFee = await abPool.vFee();

        expect(fee).to.be.equal(feeChange);
        expect(vFee).to.be.equal(vFeeChange);
    });

    it('Should set max reserve threshold', async () => {
        const abPool = fixture.abPool;
        const thresholdChange = 2000;
        await abPool.setMaxReserveThreshold(thresholdChange);
    });

    it('Should burn', async () => {
        const abPool = fixture.abPool;
        const owner = fixture.owner;

        //get LP balance
        const lpBalance = await abPool.balanceOf(owner.address);
        //transfer LP tokens to pool
        let erc20 = IERC20Metadata__factory.connect(abPool.address, owner);
        await erc20.transfer(abPool.address, lpBalance);
        //call burn function
        await abPool.burn(owner.address);

        const lpBalanceAfter = await abPool.balanceOf(owner.address);
        const reservesAfter = await abPool.getBalances();

        expect(lpBalanceAfter).to.equal(0);

        let reservesAfter0 = reservesAfter._balance0;
        let reservesAfter1 = reservesAfter._balance1;

        expect(reservesAfter0).to.equal(10655); // 598 = MINIUMUM LOCKED LIQUIDITY
        expect(reservesAfter1).to.equal(1734); // 1733 = MINIUMUM LOCKED LIQUIDITY
    });

    it('Should set factory', async () => {
        const abPool = fixture.abPool;

        await abPool.setFactory(accounts[1]);

        const factoryAddress = await abPool.factory();

        expect(factoryAddress).to.be.equal(accounts[1]);
    });

    it('Should mint', async () => {
        const abPool = fixture.abPool;
        const owner = fixture.owner;

        let AInput = 10000 * fixture.A_PRICE;
        let BInput = (fixture.B_PRICE / fixture.A_PRICE) * AInput;

        const lpBalance = await abPool.balanceOf(owner.address);

        await fixture.tokenA.transfer(
            abPool.address,
            ethers.utils.parseEther(AInput.toString())
        );
        await fixture.tokenB.transfer(
            abPool.address,
            ethers.utils.parseEther(BInput.toString())
        );
        await abPool.mint(owner.address);

        const lpBalanceAfter = await abPool.balanceOf(owner.address);

        expect(lpBalanceAfter).to.be.above(lpBalance);
    });

    it('Should not swap reserves if calculate reserve ratio is more than max allowed', async () => {
        const bcPool = fixture.bcPool;
        const tokenA = fixture.tokenA;
        const owner = fixture.owner;
        const tokenB = fixture.tokenB;
        const tokenC = fixture.tokenC;
        const vPairFactoryInstance = fixture.vPairFactoryInstance;
        const vRouterInstance = fixture.vRouterInstance;

        let aAmountOut = ethers.utils.parseEther('50000');

        let jkAddress = await vPairFactoryInstance.getPair(
            tokenB.address,
            tokenC.address
        );

        let ikAddress = await vPairFactoryInstance.getPair(
            tokenB.address,
            tokenA.address
        );

        let amountIn = await vRouterInstance.getVirtualAmountIn(
            jkAddress,
            ikAddress,
            aAmountOut
        );
        await tokenA.transfer(bcPool.address, amountIn);

        await expect(
            bcPool.swapReserveToNative(aAmountOut, ikAddress, owner.address, [])
        ).to.revertedWith('TBPT');
    });

    it('Should not swap reserves if ik0 is not whitelisted', async () => {
        const bcPool = fixture.bcPool;
        const tokenA = fixture.tokenA;
        const owner = fixture.owner;
        const tokenB = fixture.tokenB;
        const tokenC = fixture.tokenC;
        const tokenD = fixture.tokenD;
        const vPairFactoryInstance = fixture.vPairFactoryInstance;
        const vRouterInstance = fixture.vRouterInstance;

        await bcPool.setAllowList([tokenD.address]);
        // tokenA is not in the allow list anymore

        let cAmountOut = ethers.utils.parseEther('10');
        //ethers.utils.parseEther('1');

        let jkAddress = await vPairFactoryInstance.getPair(
            tokenB.address,
            tokenC.address
        );

        let ikAddress = await vPairFactoryInstance.getPair(
            tokenB.address,
            tokenA.address
        );

        let vPool = await vRouterInstance.getVirtualPool(jkAddress, ikAddress);

        let amountIn = await vRouterInstance.getVirtualAmountIn(
            jkAddress,
            ikAddress,
            cAmountOut
        );

        await tokenA.transfer(bcPool.address, amountIn);

        await expect(
            bcPool.swapReserveToNative(cAmountOut, ikAddress, owner.address, [])
        ).to.revertedWith('TNW');
    });

    it('Should not swap native if address is 0', async () => {
        const abPool = fixture.abPool;
        const tokenB = fixture.tokenB;

        let aAmountOut = ethers.utils.parseEther('10');

        await expect(
            abPool.swapNative(
                aAmountOut,
                tokenB.address,
                ethers.constants.AddressZero,
                []
            )
        ).to.revertedWith('IT');
    });

    it('Should not swap native if amount exceeds balance', async () => {
        const abPool = fixture.abPool;
        const tokenA = fixture.tokenA;
        const owner = fixture.owner;
        const tokenB = fixture.tokenB;

        const aBalancePool = await tokenA.balanceOf(abPool.address);
        let aAmountOut = aBalancePool + ethers.BigNumber.from(1);

        await expect(
            abPool.swapNative(aAmountOut, tokenB.address, owner.address, [])
        ).to.be.reverted;
    });
});

describe('vPair2', () => {
    let accounts: any = [];
    let fixture: any = {};

    before(async function () {
        fixture = await loadFixture(deployPools);
    });

    it('Swap native to reserve -> should deduct reserve ratio correctly', async () => {
        const abPool = fixture.abPool;
        const bcPool = fixture.bcPool;
        const tokenA = fixture.tokenA;
        const owner = fixture.owner;
        const tokenB = fixture.tokenB;
        const tokenC = fixture.tokenC;
        const tokenD = fixture.tokenD;
        const vPairFactoryInstance = fixture.vPairFactoryInstance;
        const vRouterInstance = fixture.vRouterInstance;

        await vPairFactoryInstance.setExchangeReservesAddress(owner.address);

        let aAmountOut = ethers.utils.parseEther('100');

        let jkAddress = await vPairFactoryInstance.getPair(
            tokenB.address,
            tokenA.address
        );

        let ikAddress = await vPairFactoryInstance.getPair(
            tokenB.address,
            tokenC.address
        );

        let cAmountIn = await vRouterInstance.getVirtualAmountIn(
            jkAddress,
            ikAddress,
            aAmountOut
        );

        await tokenC.transfer(abPool.address, cAmountIn);

        await abPool.swapReserveToNative(
            aAmountOut,
            ikAddress,
            owner.address,
            []
        );

        let cAmountOut = cAmountIn.div(2);
        let aAmountIn = await vRouterInstance.getVirtualAmountIn(
            jkAddress,
            ikAddress,
            cAmountOut
        );

        await tokenA.transfer(abPool.address, aAmountIn);

        const PRECISION = '1000';

        let aABBalance = await tokenA.balanceOf(abPool.address);
        let bABBalance = await tokenB.balanceOf(abPool.address);
        let bBCBalance = await tokenB.balanceOf(bcPool.address);
        let cBCBalance = await tokenC.balanceOf(bcPool.address);
        let virtualCBalance = cBCBalance
            .mul(bABBalance.gt(bBCBalance) ? bBCBalance : bABBalance)
            .div(bBCBalance);
        let virtualABalance = aABBalance
            .mul(bABBalance.gt(bBCBalance) ? bBCBalance : bABBalance)
            .div(bABBalance);
        let reserveBaseValue = cAmountOut
            .mul(virtualABalance)
            .div(virtualCBalance);
        let expectedReserveRatio = reserveBaseValue
            .mul(ethers.BigNumber.from(PRECISION))
            .div(ethers.BigNumber.from(2).mul(aABBalance));

        await abPool.swapNativeToReserve(
            cAmountOut,
            ikAddress,
            owner.address,
            []
        );

        // must be changed when calculateReserveRatio precision changes
        const PRECISION_DIFFERENCE = '100000000000000000000'; // 23 - 3 == 20
        expectedReserveRatio = expectedReserveRatio.mul(
            ethers.BigNumber.from(PRECISION_DIFFERENCE)
        );
        let returnedReserveRatio = await abPool.calculateReserveRatio();
        expect(
            expectedReserveRatio
                .sub(returnedReserveRatio)
                .abs()
                .lt(ethers.BigNumber.from(PRECISION_DIFFERENCE))
        );
    });

    it('Burn -> Should distribute reserve tokens correctly', async () => {
        const abPool = fixture.abPool;
        const tokenC = fixture.tokenC;
        const owner = fixture.owner;
        const other_account = fixture.accounts[0].address;

        let AInput = 1000 * fixture.A_PRICE;
        let BInput = (fixture.B_PRICE / fixture.A_PRICE) * AInput;

        await fixture.tokenA.transfer(
            abPool.address,
            ethers.utils.parseEther(AInput.toString())
        );
        await fixture.tokenB.transfer(
            abPool.address,
            ethers.utils.parseEther(BInput.toString())
        );
        await abPool.mint(other_account);

        //get LP balance
        const lpBalance = await abPool.balanceOf(owner.address);
        const totalSupply = await abPool.totalSupply();
        const reserveRatio = await abPool.calculateReserveRatio();
        const cBalancePool = await tokenC.balanceOf(abPool.address);
        const cBalanceOwner = await tokenC.balanceOf(owner.address);

        //transfer LP tokens to pool
        let erc20 = IERC20Metadata__factory.connect(abPool.address, owner);
        await erc20.transfer(abPool.address, lpBalance);
        //call burn function
        await abPool.burn(owner.address);

        const cBalancePoolAfter = await tokenC.balanceOf(abPool.address);
        const cBalanceOwnerAfter = await tokenC.balanceOf(owner.address);
        const expectedCBalance = cBalancePool.mul(lpBalance).div(totalSupply);

        expect(cBalanceOwnerAfter.sub(cBalanceOwner)).to.equal(
            expectedCBalance
        );
    });
});

describe('vPair reentrancy guard', () => {
    let accounts: any = [];
    let fixture: any = {};
    let exploiter: any;

    before(async function () {
        fixture = await loadFixture(deployPools);
        const exploiterFactory = await ethers.getContractFactory(
            'ReentrancyExploiter'
        );
        exploiter = await exploiterFactory.deploy();
    });

    it('Reentrancy guard in swapNative', async () => {
        const abPool = fixture.abPool;
        const tokenA = fixture.tokenA;
        const tokenB = fixture.tokenB;
        const owner = fixture.owner;

        let aAmountOut = ethers.utils.parseEther('10');

        let amountIn = await fixture.vRouterInstance.getAmountIn(
            tokenA.address,
            tokenB.address,
            aAmountOut
        );

        await tokenA.transfer(abPool.address, amountIn);
        await expect(
            exploiter.exploitSwapNative(
                abPool.address,
                tokenB.address,
                aAmountOut,
                owner.address
            )
        ).to.revertedWith('ReentrancyGuard: reentrant call');
    });

    it('Reentrancy guard in swapReserveToNative', async () => {
        const abPool = fixture.abPool;
        const bcPool = fixture.bcPool;
        const tokenA = fixture.tokenA;
        const tokenB = fixture.tokenB;
        const tokenC = fixture.tokenC;
        const owner = fixture.owner;
        const vPairFactoryInstance = fixture.vPairFactoryInstance;
        const vRouterInstance = fixture.vRouterInstance;

        let aAmountOut = ethers.utils.parseEther('10');

        let jkAddress = await vPairFactoryInstance.getPair(
            tokenB.address,
            tokenA.address
        );

        let ikAddress = await vPairFactoryInstance.getPair(
            tokenB.address,
            tokenC.address
        );

        let amountIn = await vRouterInstance.getVirtualAmountIn(
            jkAddress,
            ikAddress,
            aAmountOut
        );

        await tokenC.transfer(abPool.address, amountIn);

        await expect(
            exploiter.exploitSwapReserveToNative(
                abPool.address,
                ikAddress,
                aAmountOut,
                owner.address
            )
        ).to.revertedWith('ReentrancyGuard: reentrant call');
    });

    it('Reentrancy guard in swapNativeToReserve', async () => {
        const abPool = fixture.abPool;
        const bcPool = fixture.bcPool;
        const tokenA = fixture.tokenA;
        const tokenB = fixture.tokenB;
        const tokenC = fixture.tokenC;
        const owner = fixture.owner;
        const vPairFactoryInstance = fixture.vPairFactoryInstance;
        const vRouterInstance = fixture.vRouterInstance;

        let aAmountOut = ethers.utils.parseEther('10');

        let jkAddress = await vPairFactoryInstance.getPair(
            tokenB.address,
            tokenA.address
        );

        let ikAddress = await vPairFactoryInstance.getPair(
            tokenB.address,
            tokenC.address
        );

        let cAmountIn = await vRouterInstance.getVirtualAmountIn(
            jkAddress,
            ikAddress,
            aAmountOut
        );

        await abPool.swapReserveToNative(
            aAmountOut,
            ikAddress,
            owner.address,
            []
        );

        let amountOut = await abPool.reserves(tokenC.address);

        let amountIn = await vRouterInstance.getVirtualAmountIn(
            abPool.address,
            bcPool.address,
            amountOut
        );

        await tokenA.transfer(abPool.address, amountIn);

        await expect(
            exploiter.exploitSwapReserveToNative(
                abPool.address,
                bcPool.address,
                amountOut,
                owner.address
            )
        ).to.revertedWith('ReentrancyGuard: reentrant call');
    });
});
