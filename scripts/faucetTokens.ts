import { ethers } from "hardhat";
import { ERC20PresetFixedSupply__factory } from "../typechain-types/index";

async function main() {
    console.log("====================");
    console.log("deploy faucet tokens");
    console.log("====================");

    const issueAmount = ethers.utils.parseEther(
        "100000000000000000000000000000000000"
    );

    const wsUrl = "http://127.0.0.1:8545";
    const pk = process.env.MATIC_LOCALHOST_PK || "0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80"; // Known Account #0
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

    const customProvider = new ethers.providers.WebSocketProvider(wsUrl);
    const wallet = new ethers.Wallet(pk);
    const owner = wallet.connect(customProvider);

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