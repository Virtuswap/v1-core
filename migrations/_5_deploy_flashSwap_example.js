const FlashSwapExample = artifacts.require("flashSwapExample");

module.exports = async function (deployer) {
  await connectDB();

  await deployer.deploy(vSwapMath);

  await deployer.link(vSwapMath, FlashSwapExample);
  await deployer.deploy(FlashSwapExample);
};
