const vRouter = artifacts.require("vRouter");
const vPair = artifacts.require("vPair");
const vPairFactory = artifacts.require("vPairFactory");
const vSwapLibrary = artifacts.require("vSwapLibrary");
const { catchRevert } = require("./exceptions");
const ERC20 = artifacts.require("ERC20PresetFixedSupply");

contract("vRouter", (accounts) => {
  function fromWeiToNumber(number) {
    return parseFloat(web3.utils.fromWei(number, "ether")).toFixed(6) * 1;
  }

  async function getFutureBlockTimestamp() {
    const blockNumber = await web3.eth.getBlockNumber();
    const block = await web3.eth.getBlock(blockNumber);
    return block.timestamp + 1000000;
  }

  const A_PRICE = 1;
  const B_PRICE = 3;
  const C_PRICE = 6;

  let tokenA, tokenB, tokenC, WETH;

  const issueAmount = web3.utils.toWei("100000000000000", "ether");

  let vPairFactoryInstance, vRouterInstance, vSwapLibraryInstance;

  before(async () => {
    tokenA = await ERC20.new("tokenA", "A", issueAmount, accounts[0]);

    tokenB = await ERC20.new("tokenB", "B", issueAmount, accounts[0]);

    tokenC = await ERC20.new("tokenC", "C", issueAmount, accounts[0]);

    vPairFactoryInstance = await vPairFactory.deployed();
    vRouterInstance = await vRouter.deployed();
    vSwapLibraryInstance = await vSwapLibrary.deployed();

    await tokenA.approve(vRouterInstance.address, issueAmount);
    await tokenB.approve(vRouterInstance.address, issueAmount);
    await tokenC.approve(vRouterInstance.address, issueAmount);

    const futureTs = await getFutureBlockTimestamp();

    //create pool A/B with 10,000 A and equivalent B
    let AInput = 10000 * A_PRICE;
    let BInput = (B_PRICE / A_PRICE) * AInput;

    await vRouterInstance.addLiquidity(
      tokenA.address,
      tokenB.address,
      web3.utils.toWei(AInput.toString(), "ether"),
      web3.utils.toWei(BInput.toString(), "ether"),
      web3.utils.toWei(AInput.toString(), "ether"),
      web3.utils.toWei(BInput.toString(), "ether"),
      accounts[0],
      futureTs
    );

    //create pool A/C
    //create pool A/B with 10,000 A and equivalent C

    let CInput = (C_PRICE / A_PRICE) * AInput;
    await vRouterInstance.addLiquidity(
      tokenA.address,
      tokenC.address,
      web3.utils.toWei(AInput.toString(), "ether"),
      web3.utils.toWei(CInput.toString(), "ether"),
      web3.utils.toWei(AInput.toString(), "ether"),
      web3.utils.toWei(CInput.toString(), "ether"),
      accounts[0],
      futureTs
    );

    //create pool B/C
    //create pool B/C with 10,000 B and equivalent C
    BInput = 20000 * B_PRICE;
    CInput = (C_PRICE / B_PRICE) * BInput;
    await vRouterInstance.addLiquidity(
      tokenB.address,
      tokenC.address,
      web3.utils.toWei(BInput.toString(), "ether"),
      web3.utils.toWei(CInput.toString(), "ether"),
      web3.utils.toWei(BInput.toString(), "ether"),
      web3.utils.toWei(CInput.toString(), "ether"),
      accounts[0],
      futureTs
    );

    //whitelist tokens in pools

    //pool 1
    const address = await vPairFactoryInstance.getPair(
      tokenA.address,
      tokenB.address
    );
    const pool = await vPair.at(address);

    //whitelist token C
    await pool.setWhitelist([tokenC.address]);

    let reserve0 = await pool.reserve0();
    let reserve1 = await pool.reserve1();

    reserve0 = fromWeiToNumber(reserve0);
    reserve1 = fromWeiToNumber(reserve1);

    // console.log("pool1: A/B: " + reserve0 + "/" + reserve1);

    //pool 2
    const address2 = await vPairFactoryInstance.getPair(
      tokenA.address,
      tokenC.address
    );
    const pool2 = await vPair.at(address2);

    //whitelist token B
    await pool2.setWhitelist([tokenB.address]);

    let reserve0Pool2 = await pool2.reserve0();
    let reserve1Pool2 = await pool2.reserve1();

    reserve0Pool2 = fromWeiToNumber(reserve0Pool2);
    reserve1Pool2 = fromWeiToNumber(reserve1Pool2);

    // console.log("pool2: A/C: " + reserve0Pool2 + "/" + reserve1Pool2);

    //pool 3
    const address3 = await vPairFactoryInstance.getPair(
      tokenB.address,
      tokenC.address
    );
    const pool3 = await vPair.at(address3);

    //whitelist token A
    await pool3.setWhitelist([tokenA.address]);

    let reserve0Pool3 = await pool3.reserve0();
    let reserve1Pool3 = await pool3.reserve1();

    reserve0Pool3 = fromWeiToNumber(reserve0Pool3);
    reserve1Pool3 = fromWeiToNumber(reserve1Pool3);

    // console.log("pool3: B/C: " + reserve0Pool3 + "/" + reserve1Pool3);
  });

  it("Should swap A to C on pool A/C", async () => {
    const poolAddress = await vPairFactoryInstance.getPair(
      tokenA.address,
      tokenC.address
    );
    const tokenABalanceBefore = await tokenA.balanceOf(accounts[0]);
    const tokenCBalanceBefore = await tokenC.balanceOf(accounts[0]);

    let amountsIn = web3.utils.toWei("10", "ether");

    const amountOut = await vRouterInstance.getAmountOut(
      tokenA.address,
      tokenC.address,
      amountsIn
    );

    let data = web3.eth.abi.encodeParameter(
      {
        SwapCallbackData: {
          payer: "address",
          tokenIn: "address",
          tokenOut: "address",
          tokenInMax: "uint256",
        },
      },
      {
        payer: accounts[0],
        tokenIn: tokenA.address,
        tokenOut: tokenC.address,
        tokenInMax: amountsIn,
      }
    );

    const futureTs = await getFutureBlockTimestamp();

    await vRouterInstance.swapToExactNative(
      tokenA.address,
      tokenC.address,
      amountOut,
      accounts[0],
      data,
      futureTs
    );

    const tokenABalanceAfter = await tokenA.balanceOf(accounts[0]);
    const tokenCBalanceAfter = await tokenC.balanceOf(accounts[0]);

    expect(fromWeiToNumber(tokenCBalanceAfter)).to.be.above(
      fromWeiToNumber(tokenCBalanceBefore)
    );

    expect(fromWeiToNumber(tokenABalanceAfter)).to.lessThan(
      fromWeiToNumber(tokenABalanceBefore)
    );
  });

  // it("Should quote A to B", async () => {
  //   const address = await vPairFactoryInstance.getPair(
  //     tokenA.address,
  //     tokenB.address
  //   );
  //   const pool = await vPair.at(address);

  //   const input = web3.utils.toWei("14", "ether");

  //   const quote = await vRouterInstance.quote(
  //     tokenA.address,
  //     tokenB.address,
  //     input
  //   );

  //   const token0 = await pool.token0();

  //   const reserves = await pool.getReserves();

  //   let tokenAReserve = 0;
  //   let tokenBReserve = 0;

  //   if (token0 == tokenA.address) {
  //     tokenAReserve = reserves._reserve0;
  //     tokenBReserve = reserves._reserve1;
  //   } else {
  //     tokenAReserve = reserves._reserve1;
  //     tokenBReserve = reserves._reserve0;
  //   }

  //   const ratio = tokenAReserve / tokenBReserve;

  //   assert.equal(quote * ratio, input, "Invalid quote");
  //   assert.equal(fromWeiToNumber(quote), 42, "Invalid quote");
  // });

  // it("Should (amountIn(amountOut(x)) = x)", async () => {
  //   const X = web3.utils.toWei("395", "ether");
  //   const fee = 997;

  //   const address = await vPairFactoryInstance.getPair(
  //     tokenA.address,
  //     tokenB.address
  //   );

  //   const amountIn = await vRouterInstance.getAmountIn(
  //     tokenA.address,
  //     tokenB.address,
  //     X
  //   );

  //   const amountOut = await vRouterInstance.getAmountOut(
  //     tokenA.address,
  //     tokenB.address,
  //     amountIn
  //   );

  //   const amountOutEth = web3.utils.fromWei(amountOut, "ether") * 1;
  //   const xEth = web3.utils.fromWei(X, "ether") * 1;
  //   assert.equal(amountOutEth, xEth, "Invalid getAmountIn / getAmountOut");
  // });

  // it("Should calculate virtual pool A/C using B/C as oracle", async () => {
  //   const ik = await vPairFactoryInstance.getPair(
  //     tokenA.address,
  //     tokenB.address
  //   );

  //   const jk = await vPairFactoryInstance.getPair(
  //     tokenB.address,
  //     tokenC.address
  //   );

  //   const vPool = await vRouterInstance.getVirtualPool(jk, ik);

  //   assert(vPool.reserve0 / vPool.reserve1 == A_PRICE / C_PRICE);
  //   assert(vPool.token0 == tokenA.address && vPool.token1 == tokenC.address);
  // });

  // it("Should calculate virtual pool B/C using A/B as oracle", async () => {
  //   const ik = await vPairFactoryInstance.getPair(
  //     tokenB.address,
  //     tokenA.address
  //   );

  //   const jk = await vPairFactoryInstance.getPair(
  //     tokenA.address,
  //     tokenC.address
  //   );

  //   const vPool = await vRouterInstance.getVirtualPool(jk, ik);

  //   assert(vPool.reserve0 / vPool.reserve1 == B_PRICE / C_PRICE);
  //   assert(vPool.token0 == tokenB.address && vPool.token1 == tokenC.address);
  // });

  // it("Should calculate virtual pool A/B using B/C as oracle", async () => {
  //   const ik = await vPairFactoryInstance.getPair(
  //     tokenA.address,
  //     tokenC.address
  //   );

  //   const jk = await vPairFactoryInstance.getPair(
  //     tokenC.address,
  //     tokenB.address
  //   );

  //   const vPool = await vRouterInstance.getVirtualPool(jk, ik);

  //   assert(vPool.reserve0 / vPool.reserve1 == A_PRICE / B_PRICE);
  //   assert(vPool.token0 == tokenA.address && vPool.token1 == tokenB.address);
  // });

  // it("Should calculate virtual pool B/A using B/C as oracle", async () => {
  //   const ik = await vPairFactoryInstance.getPair(
  //     tokenB.address,
  //     tokenC.address
  //   );

  //   const jk = await vPairFactoryInstance.getPair(
  //     tokenC.address,
  //     tokenA.address
  //   );

  //   const vPool = await vRouterInstance.getVirtualPool(jk, ik);

  //   assert(vPool.reserve0 / vPool.reserve1 == B_PRICE / A_PRICE);
  //   assert(vPool.token0 == tokenB.address && vPool.token1 == tokenA.address);
  // });

  // it("Should getVirtualAmountIn for buying 10 B in virtual pool A/B", async () => {
  //   const ikPair = await vPairFactoryInstance.getPair(
  //     tokenB.address,
  //     tokenC.address
  //   );

  //   const jkPair = await vPairFactoryInstance.getPair(
  //     tokenA.address,
  //     tokenC.address
  //   );

  //   const amountOut = web3.utils.toWei("10", "ether");

  //   const amountIn = await vRouterInstance.getVirtualAmountIn(
  //     ikPair,
  //     jkPair,
  //     amountOut
  //   );

  //   assert.equal(fromWeiToNumber(amountIn).toFixed(3), 3.348);
  // });

  // it("Should getVirtualAmountOut", async () => {
  //   const ikPair = await vPairFactoryInstance.getPair(
  //     tokenA.address,
  //     tokenB.address
  //   );

  //   const jkPair = await vPairFactoryInstance.getPair(
  //     tokenB.address,
  //     tokenC.address
  //   );

  //   const amountIn = web3.utils.toWei("10", "ether");

  //   const amountOut = await vRouterInstance.getVirtualAmountOut(
  //     jkPair,
  //     ikPair,
  //     amountIn
  //   );
  //   assert(amountOut > 0);
  // });

  // it("Should getVirtualAmountIn(getVirtualAmountOut(x)) = x", async () => {
  //   const ikPair = await vPairFactoryInstance.getPair(
  //     tokenA.address,
  //     tokenB.address
  //   );

  //   const jkPair = await vPairFactoryInstance.getPair(
  //     tokenB.address,
  //     tokenC.address
  //   );

  //   const _amountOut = web3.utils.toWei("6", "ether");

  //   const amountIn = await vRouterInstance.getVirtualAmountIn(
  //     jkPair,
  //     ikPair,
  //     _amountOut
  //   );

  //   const amountOut = await vRouterInstance.getVirtualAmountOut(
  //     jkPair,
  //     ikPair,
  //     amountIn
  //   );

  //   assert(
  //     fromWeiToNumber(_amountOut) == fromWeiToNumber(amountOut),
  //     "Not equal"
  //   );
  // });

  // it("Should swap C to A on pool A/C", async () => {
  //   const poolAddress = await vPairFactoryInstance.getPair(
  //     tokenA.address,
  //     tokenC.address
  //   );

  //   const tokenABalanceBefore = await tokenA.balanceOf(accounts[0]);
  //   const tokenCBalanceBefore = await tokenC.balanceOf(accounts[0]);

  //   let amountOut = web3.utils.toWei("10", "ether");
  //   let iks = ["0x0000000000000000000000000000000000000000"];

  //   const amountIn = await vRouterInstance.getAmountIn(
  //     tokenC.address,
  //     tokenA.address,
  //     amountOut
  //   );

  //   const futureTs = await getFutureBlockTimestamp();
  //   await vRouterInstance.swap(
  //     [poolAddress],
  //     [amountIn],
  //     [amountOut],
  //     iks,
  //     tokenC.address,
  //     tokenA.address,
  //     accounts[0],
  //     futureTs
  //   );

  //   const tokenABalanceAfter = await tokenA.balanceOf(accounts[0]);
  //   const tokenCBalanceAfter = await tokenC.balanceOf(accounts[0]);

  //   expect(fromWeiToNumber(tokenCBalanceAfter)).to.be.lessThan(
  //     fromWeiToNumber(tokenCBalanceBefore)
  //   );

  //   expect(fromWeiToNumber(tokenABalanceAfter)).to.above(
  //     fromWeiToNumber(tokenABalanceBefore)
  //   );
  // });

  // let amountInTokenC;

  // it("Should swap C to A on pool A/B", async () => {
  //   const ikPair = await vPairFactoryInstance.getPair(
  //     tokenC.address,
  //     tokenB.address
  //   );

  //   const jkPair = await vPairFactoryInstance.getPair(
  //     tokenB.address,
  //     tokenA.address
  //   );

  //   let amountOut = web3.utils.toWei("100", "ether");

  //   const amountIn = await vRouterInstance.getVirtualAmountIn(
  //     jkPair,
  //     ikPair,
  //     amountOut
  //   );

  //   amountInTokenC = amountIn;

  //   const futureTs = await getFutureBlockTimestamp();
  //   await vRouterInstance.swap(
  //     [jkPair],
  //     [amountIn],
  //     [amountOut],
  //     [ikPair],
  //     tokenC.address,
  //     tokenA.address,
  //     accounts[0],
  //     futureTs
  //   );
  // });

  // it("Should swap A to C on pool A/B", async () => {
  //   const ikPair = await vPairFactoryInstance.getPair(
  //     tokenA.address,
  //     tokenB.address
  //   );

  //   const jkPair = await vPairFactoryInstance.getPair(
  //     tokenB.address,
  //     tokenC.address
  //   );

  //   const amountIn = await vRouterInstance.getVirtualAmountIn(
  //     jkPair,
  //     ikPair,
  //     amountInTokenC
  //   );

  //   const pool = await vPair.at(ikPair);

  //   const cReserve = await pool.reserves(tokenC.address);
  //   console.log("cReserve " + cReserve);

  //   const futureTs = await getFutureBlockTimestamp();
  //   await vRouterInstance.swap(
  //     [jkPair],
  //     [amountIn],
  //     [amountInTokenC],
  //     [ikPair],
  //     tokenA.address,
  //     tokenC.address,
  //     accounts[0],
  //     futureTs
  //   );
  // });

  // it("Should Total Pool swap -> 1. C to A on pool A/C   2. C to A on pool A/B", async () => {
  //   const ikPair = await vPairFactoryInstance.getPair(
  //     tokenC.address,
  //     tokenB.address
  //   );

  //   const jkPair = await vPairFactoryInstance.getPair(
  //     tokenB.address,
  //     tokenA.address
  //   );

  //   const realPool = await vPairFactoryInstance.getPair(
  //     tokenA.address,
  //     tokenC.address
  //   );

  //   let pools = [realPool, jkPair];
  //   let _amountOut = web3.utils.toWei("10", "ether");
  //   let amountsIn = [];
  //   let amountsOut = [_amountOut, _amountOut];
  //   let iks = ["0x0000000000000000000000000000000000000000", ikPair];

  //   const realAmountIn = await vRouterInstance.getAmountIn(
  //     tokenC.address,
  //     tokenA.address,
  //     _amountOut
  //   );

  //   amountsIn.push(realAmountIn); // keep testing
  //   const virtualIn = await vRouterInstance.getVirtualAmountIn(
  //     jkPair,
  //     iks[1],
  //     _amountOut
  //   );

  //   amountsIn.push(virtualIn);

  //   const futureTs = await getFutureBlockTimestamp();
  //   await vRouterInstance.swap(
  //     pools,
  //     amountsIn,
  //     amountsOut,
  //     iks,
  //     tokenC.address,
  //     tokenA.address,
  //     accounts[0],
  //     futureTs
  //   );
  // });

  // it("Should revert on swap A to C on pool A/C with insuficient input amount", async () => {
  //   const poolAddress = await vPairFactoryInstance.getPair(
  //     tokenA.address,
  //     tokenC.address
  //   );

  //   let pools = [poolAddress];
  //   let amountsIn = web3.utils.toWei("10", "ether");

  //   const amountOut = await vRouterInstance.getAmountOut(
  //     tokenA.address,
  //     tokenC.address,
  //     amountsIn
  //   );

  //   amountsIn = web3.utils.toWei("8", "ether");

  //   const futureTs = await getFutureBlockTimestamp();
  //   let reverted = false;
  //   try {
  //     await vRouterInstance.swap(
  //       pools,
  //       [amountsIn],
  //       [amountOut],
  //       ["0x0000000000000000000000000000000000000000"],
  //       tokenA.address,
  //       tokenC.address,
  //       accounts[0],
  //       futureTs
  //     );
  //   } catch {
  //     reverted = true;
  //   }

  //   assert(reverted);
  // });

  // it("Should remove 1/4 liquidity", async () => {
  //   const poolAddress = await vPairFactoryInstance.getPair(
  //     tokenA.address,
  //     tokenB.address
  //   );
  //   const pool = await vPair.at(poolAddress);
  //   let lpBalanceBefore = await pool.balanceOf(accounts[0]);

  //   let reserve0 = await pool.reserve0();
  //   let reserve1 = await pool.reserve1();

  //   reserve0 = fromWeiToNumber(reserve0);
  //   reserve1 = fromWeiToNumber(reserve1);

  //   const withdrawAmount = fromWeiToNumber(lpBalanceBefore) / 4;

  //   await pool.approve(vRouterInstance.address, lpBalanceBefore);

  //   //get account0 balance before
  //   let tokenABalanceBefore = await tokenA.balanceOf(accounts[0]);
  //   let tokenBBalanceBefore = await tokenB.balanceOf(accounts[0]);

  //   const tokenAMin = reserve0 / 4;
  //   const tokenBMin = reserve1 / 4;

  //   const cResrveRatio = await pool.reservesBaseValue(tokenC.address);

  //   const cResrve = await pool.reserves(tokenC.address);

  //   const futureTs = await getFutureBlockTimestamp();
  //   await vRouterInstance.removeLiquidity(
  //     tokenA.address,
  //     tokenB.address,
  //     web3.utils.toWei(withdrawAmount.toString(), "ether"),
  //     web3.utils.toWei(tokenAMin.toString(), "ether"),
  //     web3.utils.toWei(tokenBMin.toString(), "ether"),
  //     accounts[0],
  //     futureTs
  //   );

  //   const cResrveAfter = await pool.reserves(tokenC.address);

  //   const cResrveRatioAfter = await pool.reservesBaseValue(tokenC.address);

  //   //get account0 balance before
  //   let tokenABalanceAfter = await tokenA.balanceOf(accounts[0]);
  //   let tokenBBalanceAfter = await tokenB.balanceOf(accounts[0]);

  //   tokenABalanceBefore = fromWeiToNumber(tokenABalanceBefore);
  //   tokenBBalanceBefore = fromWeiToNumber(tokenBBalanceBefore);
  //   tokenABalanceAfter = fromWeiToNumber(tokenABalanceAfter);
  //   tokenBBalanceAfter = fromWeiToNumber(tokenBBalanceAfter);

  //   let reserve0After = await pool.reserve0();
  //   let reserve1After = await pool.reserve1();

  //   reserve0After = fromWeiToNumber(reserve0After);
  //   reserve1After = fromWeiToNumber(reserve1After);

  //   expect(tokenABalanceAfter).to.be.above(tokenABalanceBefore);
  //   expect(tokenBBalanceAfter).to.be.above(tokenBBalanceBefore);

  //   assert.equal(
  //     (reserve0 * 0.75).toFixed(3),
  //     reserve0After.toFixed(3),
  //     "Pool reserve did not decrease by 1/4"
  //   );

  //   assert.equal(
  //     (reserve1 * 0.75).toFixed(3),
  //     reserve1After.toFixed(3),
  //     "Pool reserve did not decrease by 1/4"
  //   );
  // });

  // it("Should add liquidity", async () => {
  //   let amountADesired = web3.utils.toWei("1", "ether");

  //   const amountBDesired = await vRouterInstance.quote(
  //     tokenA.address,
  //     tokenB.address,
  //     amountADesired
  //   );

  //   const pool = await vPair.at(
  //     await vPairFactoryInstance.getPair(tokenA.address, tokenB.address)
  //   );

  //   let reserve0 = await pool.reserve0();
  //   let reserve1 = await pool.reserve1();

  //   let totalBalanceBefore0 = reserve0;
  //   let totalBalanceBefore1 = reserve1;

  //   const futureTs = await getFutureBlockTimestamp();

  //   let lpBalance = await pool.balanceOf(accounts[0]);

  //   let poolRR = await pool.calculateReserveRatio();

  //   await vRouterInstance.addLiquidity(
  //     tokenA.address,
  //     tokenB.address,
  //     amountADesired,
  //     amountBDesired,
  //     amountADesired,
  //     amountBDesired,
  //     accounts[0],
  //     futureTs
  //   );

  //   lpBalance = await pool.balanceOf(accounts[0]);

  //   reserve0 = await pool.reserve0();
  //   reserve1 = await pool.reserve1();

  //   let totalBalanceAfter0 = reserve0;
  //   let totalBalanceAfter1 = reserve1;

  //   expect(Number(totalBalanceBefore0.toString())).to.lessThan(
  //     Number(totalBalanceAfter0.toString())
  //   );

  //   expect(Number(totalBalanceBefore1.toString())).to.lessThan(
  //     Number(totalBalanceAfter1.toString())
  //   );
  // });

  // it("Should revert when trying to provide unbalanced A amount", async function () {
  //   const amountADesired = web3.utils.toWei("12", "ether");

  //   const amountBDesired = web3.utils.toWei("10", "ether");
  //   const futureTs = await getFutureBlockTimestamp();
  //   await catchRevert(
  //     vRouterInstance.addLiquidity(
  //       tokenA.address,
  //       tokenB.address,
  //       amountADesired,
  //       amountBDesired,
  //       amountADesired,
  //       amountBDesired,
  //       accounts[0],
  //       futureTs
  //     )
  //   );
  // });

  // it("Should revert when trying to provide unbalanced B amount", async function () {
  //   const amountADesired = web3.utils.toWei("1", "ether");

  //   const amountBDesired = web3.utils.toWei("4", "ether");
  //   const futureTs = await getFutureBlockTimestamp();
  //   await catchRevert(
  //     vRouterInstance.addLiquidity(
  //       tokenA.address,
  //       tokenB.address,
  //       amountADesired,
  //       amountBDesired,
  //       amountADesired,
  //       amountBDesired,
  //       accounts[0],
  //       futureTs
  //     )
  //   );
  // });

  // it("Should remove all pool liquidity", async () => {
  //   const poolAddress = await vPairFactoryInstance.getPair(
  //     tokenA.address,
  //     tokenB.address
  //   );
  //   const pool = await vPair.at(poolAddress);
  //   let lpBalance = await pool.balanceOf(accounts[0]);

  //   let tokenABalanceBefore = await tokenA.balanceOf(accounts[0]);
  //   let tokenBBalanceBefore = await tokenB.balanceOf(accounts[0]);

  //   let token0 = await pool.token0();
  //   let token1 = await pool.token1();
  //   let amountADesired = await pool.reserve0();

  //   let amountBDesired = await vRouterInstance.quote(
  //     token0,
  //     token1,
  //     amountADesired
  //   );

  //   //TBD: FIX THIS
  //   amountADesired = web3.utils.toWei(
  //     (fromWeiToNumber(amountADesired) * 0.99).toString(),
  //     "ether"
  //   );

  //   amountBDesired = web3.utils.toWei(
  //     (fromWeiToNumber(amountBDesired) * 0.99).toString(),
  //     "ether"
  //   );

  //   const cResrveRatio = await pool.reservesBaseValue(tokenC.address);
  //   const userTokenCBalance = await tokenC.balanceOf(accounts[0]);

  //   let reserve0 = await pool.reserve0();
  //   let reserve1 = await pool.reserve1();

  //   await pool.approve(vRouterInstance.address, lpBalance);

  //   const poolRRbefore = await pool.calculateReserveRatio();

  //   const cResrve = await pool.reserves(tokenC.address);
  //   const futureTs = await getFutureBlockTimestamp();
  //   await vRouterInstance.removeLiquidity(
  //     tokenA.address,
  //     tokenB.address,
  //     lpBalance,
  //     amountADesired,
  //     amountBDesired,
  //     accounts[0],
  //     futureTs
  //   );

  //   const cResrveRatioAfter = await pool.reservesBaseValue(tokenC.address);

  //   const cResrveAfter = await pool.reserves(tokenC.address);

  //   const poolRRAfter = await pool.calculateReserveRatio();

  //   tokenABalanceBefore = fromWeiToNumber(tokenABalanceBefore);
  //   tokenBBalanceBefore = fromWeiToNumber(tokenBBalanceBefore);

  //   lpBalanceBefore = fromWeiToNumber(lpBalance);
  //   let lpBalanceAfter = await pool.balanceOf(accounts[0]);
  //   lpBalanceAfter = fromWeiToNumber(lpBalanceAfter);

  //   let tokenABalanceAfter = await tokenA.balanceOf(accounts[0]);
  //   let tokenBBalanceAfter = await tokenB.balanceOf(accounts[0]);

  //   tokenABalanceAfter = fromWeiToNumber(tokenABalanceAfter);
  //   tokenBBalanceAfter = fromWeiToNumber(tokenBBalanceAfter);

  //   let reserve0After = await pool.reserve0();
  //   let reserve1After = await pool.reserve1();

  //   const userTokenCBalanceAfter = await tokenC.balanceOf(accounts[0]);

  //   assert.equal(lpBalanceAfter, 0, "LP tokens not zero");
  //   expect(tokenABalanceBefore).to.lessThan(tokenABalanceAfter);
  //   expect(tokenBBalanceBefore).to.lessThan(tokenBBalanceAfter);

  //   expect(fromWeiToNumber(reserve0After)).to.lessThan(
  //     fromWeiToNumber(reserve0)
  //   );
  //   expect(fromWeiToNumber(reserve1After)).to.lessThan(
  //     fromWeiToNumber(reserve1)
  //   );

  //   expect(fromWeiToNumber(userTokenCBalance)).to.lessThan(
  //     fromWeiToNumber(userTokenCBalanceAfter)
  //   );

  //   // check C reserve was updated in pool
  //   expect(fromWeiToNumber(cResrveRatioAfter)).to.lessThan(
  //     fromWeiToNumber(cResrveRatio)
  //   );
  // });

  // it("Should re-add liquidity", async () => {
  //   const pool = await vPair.at(
  //     await vPairFactoryInstance.getPair(tokenA.address, tokenB.address)
  //   );

  //   let reserve0 = await pool.reserve0();
  //   let reserve1 = await pool.reserve1();

  //   let amountADesired = web3.utils.toWei("100", "ether");

  //   const amountBDesired = await vRouterInstance.quote(
  //     tokenA.address,
  //     tokenB.address,
  //     amountADesired
  //   );

  //   let poolRR = await pool.calculateReserveRatio();
  //   const futureTs = await getFutureBlockTimestamp();

  //   let lpBalanceBefore = await pool.balanceOf(accounts[0]);
  //   let poolTs = await pool.totalSupply();
  //   await vRouterInstance.addLiquidity(
  //     tokenA.address,
  //     tokenB.address,
  //     amountADesired,
  //     amountBDesired,
  //     amountADesired,
  //     amountBDesired,
  //     accounts[0],
  //     futureTs
  //   );

  //   let poolTsAfter = await pool.totalSupply();
  //   let lpBalanceAfter = await pool.balanceOf(accounts[0]);

  //   let reserve0After = await pool.reserve0();
  //   let reserve1After = await pool.reserve1();

  //   let reserve0Eth, reserve1Eth, reserve0AfterEth, reserve1AfterEth;

  //   reserve0Eth = fromWeiToNumber(reserve0);
  //   reserve1Eth = fromWeiToNumber(reserve1);
  //   reserve0AfterEth = fromWeiToNumber(reserve0After);
  //   reserve1AfterEth = fromWeiToNumber(reserve1After);

  //   expect(reserve0Eth).to.lessThan(reserve0AfterEth);
  //   expect(reserve1Eth).to.lessThan(reserve1AfterEth);
  // });

  // it("Should change factory", async () => {
  //   const currentFactory = await vRouterInstance.factory();
  //   await vRouterInstance.changeFactory(tokenA.address);
  //   const newFactory = await vRouterInstance.factory();

  //   assert(
  //     currentFactory != tokenA.address && newFactory == tokenA.address,
  //     "Factory did not changed"
  //   );
  // });
});
