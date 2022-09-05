# README #

Implementation of the [Virtuswap Whitepaper]( https://virtuswap.io/wp-content/uploads/2021/11/WP-Virtuswap-Oct-18-2021.pdf) using Solidity for EVM-compatible blockchains.  
More in-depth documentation is available at [docs.virtuswap.io](https://docs.virtuswap.io).  


#  Local development #
Hardhat requires `node@>=16.0`


#  Installation #

```
git clone git@github.com:Virtuswap/v1-core.git
cd v1-core
npm i
```


# Compilation #
```
npx hardhat compile
```

# Running tests #
```
npx hardhat test
```

# Deploy #
## Deploy locally ##
First kick off the local network to stay running in one terminal:
```
npx hardhat node
```
then deploy some contracts, and run transactions in a different terminal:
```
npx hardhat run scripts/deploy.ts --network localhost
```

## Deploy faucet tokens to testnet (untested) ##
Export MATIC_TESTNET_WS in your ~/.bash_profile or equivalent to the value in the RPC WSS Provider field.
```
npx hardhat run scripts/faucetTokens.ts --network matic_testnet
```
