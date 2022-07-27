const vRouter = artifacts.require("vRouter");
const vPairFactory = artifacts.require("vPairFactory");
const vSwapLibrary = artifacts.require("vSwapLibrary");
const SafeERC20 = artifacts.require("SafeERC20");
const Address = artifacts.require("Address");

module.exports = async function (deployer, network) {
  console.log("network name: " + network);

  //libraries
  await deployer.deploy(vSwapLibrary);
  await deployer.deploy(SafeERC20);
  await deployer.deploy(Address);

  await deployer.link(Address, vPairFactory);
  await deployer.link(SafeERC20, vPairFactory);
  await deployer.link(vSwapLibrary, vPairFactory);
  await deployer.deploy(vPairFactory);

  await deployer.link(Address, vRouter);
  await deployer.link(SafeERC20, vRouter);
  await deployer.link(vSwapLibrary, vRouter);
  let vPairFactoryAddress =
    vPairFactory.networks[Object.keys(vPairFactory.networks)[0]].address;

  await deployer.deploy(vRouter, vPairFactoryAddress);

};
