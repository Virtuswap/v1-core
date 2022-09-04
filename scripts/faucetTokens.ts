import { ethers } from "hardhat";
import { ERC20PresetFixedSupply__factory } from "../typechain-types/index";

async function main() {
    console.log("====================");
    console.log("deploy faucet tokens");
    console.log("====================");

    const issueAmount = ethers.utils.parseEther(
        "100000000000000000000000000000000000"
    );

    // Contracts are deployed using the first signer/account by default
    const accounts = await ethers.getSigners();
    const owner = accounts[0];

    const faucetTokens = {
        "WMATIC": "Wrapped Matic - VirtuSwap Test",
        "USDC": "USD Coin - VirtuSwap Test",
        "WETH": "Wrapped Ether - VirtuSwap Test",
        "WBTC": "Wrapped BTC - VirtuSwap Test",
        "GHST": "Aavegotchi GHST - VirtuSwap Test",
        "QUICK": "Quickswap - VirtuSwap Test",
        "USDT": "USD Tether - VirtuSwap Test",
        "DAI": "Dai Stablecoin - VirtuSwap Test",
        "SUSHI": "SushiToken  - VirtuSwap Test",
        "LINK": "Chainlink Token - VirtuSwap Test",
        "CRV": "CRV - VirtuSwap Test",
        "CPLE": "Carpool Life Economy - VirtuSwap Test",
        "BLOK": "BLOK - VirtuSwap Test",
        "PGEN": "Polygen - VirtuSwap Test",
        "RADIO": "Radio Token - VirtuSwap Test"
    };

    const erc20ContractFactory = await new ERC20PresetFixedSupply__factory(owner);
    for (const [symbol, name] of Object.entries(faucetTokens)) {
        const token = await erc20ContractFactory.deploy(
            name,
            symbol,
            issueAmount,
            owner.address
        );
        //console.log(`Deployed ${symbol} at address ${token.address}`);
        console.log(`"${symbol}": "${token.address}",`);
    }

}

main()
    .then(() => process.exit(0))
    .catch((error) => {
        console.error(error);
        process.exit(1);
    });