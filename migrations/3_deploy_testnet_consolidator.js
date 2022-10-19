const ConsolidateERC20Txs = artifacts.require("ConsolidateERC20Txs");

module.exports = async function (deployer, network) {
  await deployer.deploy(
    ConsolidateERC20Txs,
    "0xEa3CB070566CA083e3316c5b45CaB4A25d969ee7"
  );
};
