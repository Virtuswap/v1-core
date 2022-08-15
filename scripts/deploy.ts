import { ethers } from "hardhat";
import { deployPools } from "../utilities/deployPools";

async function main() {
    const {
        tokenA,
        tokenB,
        tokenC,
        owner
    } = await deployPools();

    console.log("Deploying contracts with the account:", owner.address);

    console.log("Account balance:", ethers.utils.formatEther(await owner.getBalance()).toString());

    console.log("tokenA address:", tokenA.address);
    console.log("tokenB address:", tokenB.address);
    console.log("tokenC address:", tokenC.address);

}

main()
    .then(() => process.exit(0))
    .catch((error) => {
        console.error(error);
        process.exit(1);
    });