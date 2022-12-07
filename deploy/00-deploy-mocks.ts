import { HardhatRuntimeEnvironment } from "hardhat/types"
import { DeployFunction } from "hardhat-deploy/types"

const deployMocks: DeployFunction = async function (
    hre: HardhatRuntimeEnvironment
) {
    const { deployments, getNamedAccounts, network } = hre
    const { deploy, log } = deployments
    const { deployer } = await getNamedAccounts()
    const chainId = network.config.chainID

    if (chainId == 31337) {
        log("Deploying Mocks...")
        await deploy("WETH9", {
            contract: "WETH9",
            from: deployer,
            log: true,
        })
        log("Mocks deployed!")
    }
}

export default deployMocks
deployMocks.tags = ["all", "mocks"]
