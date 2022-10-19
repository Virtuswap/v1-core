const vRouter = artifacts.require("vRouter");
const vPairFactory = artifacts.require("vPairFactory");
const WETH9 = artifacts.require("WETH9");
const vSwapLibrary = artifacts.require("vSwapLibrary");
const PoolAddress = artifacts.require("PoolAddress");
const exchangeReserves = artifacts.require("vExchangeReserves");

const SafeERC20 = artifacts.require("SafeERC20");
const Address = artifacts.require("Address");

module.exports = async function (deployer, network) {
  console.log("network name: " + network);

  //deploy WETH9
  await deployer.deploy(WETH9);

  //libraries
  await deployer.deploy(vSwapLibrary);
  await deployer.deploy(SafeERC20);
  await deployer.deploy(Address);
  await deployer.deploy(PoolAddress);

  await deployer.link(Address, vPairFactory);
  await deployer.link(SafeERC20, vPairFactory);
  await deployer.link(vSwapLibrary, vPairFactory);
  await deployer.link(PoolAddress, vPairFactory);
  await deployer.deploy(vPairFactory);

  await deployer.link(Address, vRouter);
  await deployer.link(SafeERC20, vRouter);
  await deployer.link(vSwapLibrary, vRouter);
  await deployer.link(PoolAddress, vRouter);
  let WETH9Address = WETH9.networks[Object.keys(WETH9.networks)[0]].address;

  let vPairFactoryAddress =
    vPairFactory.networks[Object.keys(vPairFactory.networks)[0]].address;

  await deployer.deploy(vRouter, vPairFactoryAddress, WETH9Address);

  await deployer.link(PoolAddress, exchangeReserves);
  await deployer.deploy(exchangeReserves, vPairFactoryAddress);
};