# README #

Virtuswap smart contracts

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
npx hardhat run scripts/deploy.ts --network local
```

## Deploy to testnet (untested) ##
```
npx hardhat run scripts/deploy.ts --network quicknodeTestWS
```

# Sample Hardhat Project

This project demonstrates a basic Hardhat use case. It comes with a sample contract, a test for that contract, and a script that deploys that contract.

Try running some of the following tasks:

```shell
npx hardhat help
npx hardhat test
GAS_REPORT=true npx hardhat test
npx hardhat node
npx hardhat run scripts/deploy.ts
```
