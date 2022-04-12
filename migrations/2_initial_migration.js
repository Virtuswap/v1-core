const vPoolsManager = artifacts.require("vPoolsManager");
const VPoolReserveManager = artifacts.require("vPoolReserveManager");
const ComputationsLibrary = artifacts.require("vPoolCalculations");
// const Migrations = artifacts.require("vPool");

module.exports = async function (deployer) {
  // await deployer.deploy(VPoolReserveManager);
  await deployer.deploy(ComputationsLibrary);
  await deployer.link(ComputationsLibrary, vPoolsManager);
  await deployer.deploy(vPoolsManager);
};
