// const { assert } = require("chai");

// const vRouter = artifacts.require("vRouter");
// const vPair = artifacts.require("vPair");
// const vPairFactory = artifacts.require("vPairFactory");
// const vSwapLibrary = artifacts.require("vSwapLibrary");
// const ERC20 = artifacts.require("ERC20PresetFixedSupply");

// async function getFutureBlockTimestamp() {
//   const blockNumber = await web3.eth.getBlockNumber();
//   const block = await web3.eth.getBlock(blockNumber);
//   return block.timestamp + 1000000;
// }

// contract("vSwapLibrary", (accounts) => {
//   function fromWeiToNumber(number) {
//     return parseFloat(web3.utils.fromWei(number, "ether")).toFixed(6) * 1;
//   }

//   const A_PRICE = 1;
//   const B_PRICE = 3;
//   const C_PRICE = 6;
//   const D_PRICE = 10;

//   let tokenA, tokenB, tokenC, tokenD, WETH;

//   const issueAmount = web3.utils.toWei("100000000000000", "ether");

//   let vPairFactoryInstance, vRouterInstance, vSwapLibraryInstance;

//   before(async () => {
//     tokenA = await ERC20.new("tokenA", "A", issueAmount, accounts[0]);

//     tokenB = await ERC20.new("tokenB", "B", issueAmount, accounts[0]);

//     tokenC = await ERC20.new("tokenC", "C", issueAmount, accounts[0]);

//     tokenD = await ERC20.new("tokenD", "D", issueAmount, accounts[0]);

//     vPairFactoryInstance = await vPairFactory.deployed();
//     vRouterInstance = await vRouter.deployed();
//     vSwapLibraryInstance = await vSwapLibrary.deployed();

//     await tokenA.approve(vRouterInstance.address, issueAmount);
//     await tokenB.approve(vRouterInstance.address, issueAmount);
//     await tokenC.approve(vRouterInstance.address, issueAmount);
//     await tokenD.approve(vRouterInstance.address, issueAmount);

//     const futureTs = await getFutureBlockTimestamp();

//     //create pool A/B with 10,000 A and equivalent B
//     let AInput = 10000 * A_PRICE;
//     let BInput = (B_PRICE / A_PRICE) * AInput;

//     await vRouterInstance.addLiquidity(
//       tokenA.address,
//       tokenB.address,
//       web3.utils.toWei(AInput.toString(), "ether"),
//       web3.utils.toWei(BInput.toString(), "ether"),
//       web3.utils.toWei(AInput.toString(), "ether"),
//       web3.utils.toWei(BInput.toString(), "ether"),
//       accounts[0],
//       futureTs
//     );

//     //create pool A/C
//     //create pool A/B with 10,000 A and equivalent C

//     let CInput = (C_PRICE / A_PRICE) * AInput;
//     await vRouterInstance.addLiquidity(
//       tokenA.address,
//       tokenC.address,
//       web3.utils.toWei(AInput.toString(), "ether"),
//       web3.utils.toWei(CInput.toString(), "ether"),
//       web3.utils.toWei(AInput.toString(), "ether"),
//       web3.utils.toWei(CInput.toString(), "ether"),
//       accounts[0],
//       futureTs
//     );

//     //create pool B/C
//     //create pool B/C with 10,000 B and equivalent C
//     BInput = 20000 * B_PRICE;
//     CInput = (C_PRICE / B_PRICE) * BInput;
//     await vRouterInstance.addLiquidity(
//       tokenB.address,
//       tokenC.address,
//       web3.utils.toWei(BInput.toString(), "ether"),
//       web3.utils.toWei(CInput.toString(), "ether"),
//       web3.utils.toWei(BInput.toString(), "ether"),
//       web3.utils.toWei(CInput.toString(), "ether"),
//       accounts[0],
//       futureTs
//     );

//     //create pool B/D
//     //create pool B/D with 10,000 B and equivalent C
//     BInput = 50000 * B_PRICE;
//     let DInput = (D_PRICE / B_PRICE) * BInput;
//     await vRouterInstance.addLiquidity(
//       tokenB.address,
//       tokenD.address,
//       web3.utils.toWei(BInput.toString(), "ether"),
//       web3.utils.toWei(DInput.toString(), "ether"),
//       web3.utils.toWei(BInput.toString(), "ether"),
//       web3.utils.toWei(DInput.toString(), "ether"),
//       accounts[0],
//       futureTs
//     );

//     //whitelist tokens in pools

//     //pool 1
//     const address = await vPairFactoryInstance.getPair(
//       tokenA.address,
//       tokenB.address
//     );
//     const pool = await vPair.at(address);

//     //whitelist token C
//     await pool.setWhitelist([tokenC.address, tokenD.address]);

//     let reserve0 = await pool.reserve0();
//     let reserve1 = await pool.reserve1();

//     reserve0 = fromWeiToNumber(reserve0);
//     reserve1 = fromWeiToNumber(reserve1);

//     // console.log("pool1: A/B: " + reserve0 + "/" + reserve1);

//     //pool 2
//     const address2 = await vPairFactoryInstance.getPair(
//       tokenA.address,
//       tokenC.address
//     );
//     const pool2 = await vPair.at(address2);

//     //whitelist token B
//     await pool2.setWhitelist([tokenB.address, tokenD.address]);

//     let reserve0Pool2 = await pool2.reserve0();
//     let reserve1Pool2 = await pool2.reserve1();

//     reserve0Pool2 = fromWeiToNumber(reserve0Pool2);
//     reserve1Pool2 = fromWeiToNumber(reserve1Pool2);

//     // console.log("pool2: A/C: " + reserve0Pool2 + "/" + reserve1Pool2);

//     //pool 3
//     const address3 = await vPairFactoryInstance.getPair(
//       tokenB.address,
//       tokenC.address
//     );
//     const pool3 = await vPair.at(address3);

//     //whitelist token A
//     await pool3.setWhitelist([tokenA.address, tokenD.address]);

//     let reserve0Pool3 = await pool3.reserve0();
//     let reserve1Pool3 = await pool3.reserve1();

//     reserve0Pool3 = fromWeiToNumber(reserve0Pool3);
//     reserve1Pool3 = fromWeiToNumber(reserve1Pool3);

//     // console.log("pool3: B/C: " + reserve0Pool3 + "/" + reserve1Pool3);

//     //pool 4
//     const address4 = await vPairFactoryInstance.getPair(
//       tokenB.address,
//       tokenD.address
//     );
//     const pool4 = await vPair.at(address4);

//     //whitelist token A
//     await pool4.setWhitelist([tokenA.address, tokenC.address]);

//     let reserve0Pool4 = await pool4.reserve0();
//     let reserve1Pool4 = await pool4.reserve1();

//     reserve0Pool4 = fromWeiToNumber(reserve0Pool4);
//     reserve1Pool4 = fromWeiToNumber(reserve1Pool4);

//     // console.log("pool4: B/D: " + reserve0Pool4 + "/" + reserve1Pool4);
//   });

//   it("Should calculate correctly getAmountIn", async () => {
//     const address = await vPairFactoryInstance.getPair(
//       tokenA.address,
//       tokenB.address
//     );

//     const pool = await vPair.at(address);

//     const baseToken = await pool.token0();
//     const reserve0 = await pool.reserve0();
//     const reserve1 = await pool.reserve1();
//     const fee = await pool.fee();

//     let reserves = await vSwapLibraryInstance.sortReserves(
//       tokenB.address,
//       baseToken,
//       reserve0,
//       reserve1
//     );

//     const amountIn = await vSwapLibraryInstance.getAmountIn(
//       web3.utils.toWei("1", "ether"),
//       reserves._reserve0,
//       reserves._reserve1,
//       fee
//     );
//     // console.log("to buy 1 A, pays " + fromWeiToNumber(amountIn) + " B");
//     assert.equal(fromWeiToNumber(amountIn).toFixed(3), "3.009"); // (B / A) * fee;
//   });

//   it("Should calculate correctly getAmountOut", async () => {
//     const address = await vPairFactoryInstance.getPair(
//       tokenA.address,
//       tokenB.address
//     );

//     const pool = await vPair.at(address);

//     const baseToken = await pool.token0();
//     const reserve0 = await pool.reserve0();
//     const reserve1 = await pool.reserve1();
//     const fee = await pool.fee();

//     let reserves = await vSwapLibraryInstance.sortReserves(
//       tokenA.address,
//       baseToken,
//       reserve0,
//       reserve1
//     );

//     const amountOut = await vSwapLibraryInstance.getAmountOut(
//       web3.utils.toWei("1", "ether"),
//       reserves._reserve0,
//       reserves._reserve1,
//       fee
//     );
//     // console.log("to sell 1 A, gets " + fromWeiToNumber(amountOut) + " B");
//     assert.equal(fromWeiToNumber(amountOut).toFixed(3), "2.991"); // (B / A) * (1 - fee);
//   });

//   it("Should calculate percents", async () => {
//     let nominator = web3.utils.toWei("10", "ether");
//     let denominator = web3.utils.toWei("20", "ether");
//     let percent = await vSwapLibraryInstance.percent(nominator, denominator);
//     percent = fromWeiToNumber(percent);

//     assert.equal(percent, 0.5);

//     nominator = web3.utils.toWei("100", "ether");
//     denominator = web3.utils.toWei("500", "ether");
//     percent = await vSwapLibraryInstance.percent(nominator, denominator);
//     percent = fromWeiToNumber(percent);

//     assert.equal(percent, 0.2);
//   });

//   it("Should reserve ratio is larger than 0", async () => {
//     const address = await vPairFactoryInstance.getPair(
//       tokenA.address,
//       tokenB.address
//     );

//     const pool = await vPair.at(address);
//     const baseReserve = await pool.reserve0();
//     const rRatio = 0;
//     _rReserve = web3.utils.toWei("10", "ether");

//     const reserveRatio = await vSwapLibraryInstance.calculateReserveRatio(
//       0,
//       _rReserve,
//       baseReserve
//     );

//     assert(reserveRatio > 0, "Wrong reserve ratio calculation");
//   });

//   it("Should (amountIn(amountOut(x)) = x)", async () => {
//     const X = web3.utils.toWei("3", "ether");
//     const fee = 997;

//     const address = await vPairFactoryInstance.getPair(
//       tokenA.address,
//       tokenB.address
//     );

//     const pool = await vPair.at(address);

//     const reserve0 = await pool.reserve0();
//     const reserve1 = await pool.reserve1();

//     const amountIn = await vSwapLibraryInstance.getAmountIn(
//       X,
//       reserve0,
//       reserve1,
//       fee
//     );

//     const amountOut = await vSwapLibraryInstance.getAmountOut(
//       amountIn,
//       reserve0,
//       reserve1,
//       fee
//     );

//     assert.equal(amountOut, X, "Invalid getAmountIn / getAmountOut");
//   });

//   it("Should sort pool reserves", async () => {
//     const address = await vPairFactoryInstance.getPair(
//       tokenB.address,
//       tokenA.address
//     );

//     const pool = await vPair.at(address);

//     let poolReserves = await pool.getReserves();
//     let poolToken0 = await pool.token0();
//     let poolToken1 = await pool.token1();

//     let reserves = await vSwapLibraryInstance.sortReserves(
//       poolToken0,
//       poolToken0,
//       poolReserves._reserve0,
//       poolReserves._reserve1
//     );

//     assert.equal(
//       fromWeiToNumber(poolReserves._reserve0),
//       fromWeiToNumber(reserves._reserve0),
//       "Reserve not in order"
//     );

//     let reserves2 = await vSwapLibraryInstance.sortReserves(
//       poolToken1,
//       poolToken0,
//       poolReserves._reserve0,
//       poolReserves._reserve1
//     );

//     assert.equal(
//       fromWeiToNumber(poolReserves._reserve1),
//       fromWeiToNumber(reserves2._reserve0),
//       "Reserve 2 not in order"
//     );
//   });

//   it("Should find common token and assing to ik1 and jk1", async () => {
//     let tokens = await vSwapLibraryInstance.findCommonToken(
//       tokenA.address,
//       tokenB.address,
//       tokenC.address,
//       tokenB.address
//     );

//     assert.equal(tokens.ik1, tokens.jk1, "ik1 not equal to jk1");

//     tokens = await vSwapLibraryInstance.findCommonToken(
//       tokenB.address,
//       tokenA.address,
//       tokenA.address,
//       tokenC.address
//     );

//     assert.equal(tokens.ik1, tokens.jk1, "ik1 not equal to jk1");

//     tokens = await vSwapLibraryInstance.findCommonToken(
//       tokenC.address,
//       tokenA.address,
//       tokenB.address,
//       tokenC.address
//     );

//     assert.equal(tokens.ik1, tokens.jk1, "ik1 not equal to jk1");

//     tokens = await vSwapLibraryInstance.findCommonToken(
//       tokenC.address,
//       tokenA.address,
//       tokenC.address,
//       tokenB.address
//     );

//     assert.equal(tokens.ik1, tokens.jk1, "ik1 not equal to jk1");
//   });

//   // it("Should deduct reserve ratio from lp tokens issue", async () => {
//   //   const address = await vPairFactoryInstance.getPair(
//   //     tokenA.address,
//   //     tokenB.address
//   //   );

//   //   const pool = await vPair.at(address);

//   //   let poolToken0 = await pool.token0();
//   //   let poolToken1 = await pool.token1();

//   //   let token0 = await ERC20.at(poolToken0);
//   //   let token1 = await ERC20.at(poolToken1);

//   //   let poolReserve0 = await pool.reserve0();
//   //   let poolReserve1 = await pool.reserve1();

//   //   let balance0 = await token0.balanceOf(pool.address);
//   //   let balance1 = await token1.balanceOf(pool.address);

//   //   poolReserve0 = fromWeiToNumber(poolReserve0);
//   //   poolReserve1 = fromWeiToNumber(poolReserve1);

//   //   balance0 = fromWeiToNumber(balance0);
//   //   balance1 = fromWeiToNumber(balance1);

//   //   balance0 = balance0 + 30;
//   //   balance1 = balance1 + 10;

//   //   let amount0 = balance0 - poolReserve0;
//   //   let amount1 = balance1 - poolReserve1;

//   //   let _totalSupply = await pool.totalSupply();

//   //   _totalSupply = fromWeiToNumber(_totalSupply);

//   //   let liquidity = Math.min(
//   //     (amount0 * _totalSupply) / poolReserve0,
//   //     (amount1 * _totalSupply) / poolReserve1
//   //   );

//   //   await addCToPoolAB();
//   //   await addDToPoolAB();

//   //   let reserveRatio = await pool.calculateReserveRatio();

//   //   let lpTokens = await vSwapLibraryInstance.substractPCT(
//   //     web3.utils.toWei(liquidity.toString(), "ether"),
//   //     reserveRatio
//   //   );

//   //   lpTokens = fromWeiToNumber(lpTokens);
//   //   let inversedReserveRatio = 1 - fromWeiToNumber(reserveRatio) / 100000;
//   //   let deductedL = (liquidity * inversedReserveRatio).toFixed(2);
//   //   let roundedLpTokens = (lpTokens * 1).toFixed(2);

//   //   assert.equal(deductedL, roundedLpTokens);
//   // });
// });
