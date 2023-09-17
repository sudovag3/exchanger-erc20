# Exchanger Project Documentation

## Introduction

The Exchanger project provides a decentralized platform for exchanging ERC-20 tokens and native currency. It also includes a vault system for securely storing tokens and native currency.

## Installation and Usage

### Clone and install requirements

```shell
$ git clone 
$ cd 
$ forge install OpenZeppelin/openzeppelin-contracts --no-commit
```

### Build

```shell
$ forge build
```

### Test

```shell
$ forge test
```

## Contracts Overview

### Exchanger.sol
The `Exchanger` contract provides the core functionality for exchanging tokens and native currency. It uses a whitelist system to set exchange rates for specific tokens.

**Key Features:**

- Set and remove exchange rates for tokens.
- Execute exchanges between tokens and native currency.
- Withdraw tokens.
- Calculate fees for exchanges.
- Get exchange rates and other contract details.

### Vault.sol

The `Vault` contract allows for depositing and withdrawing of ERC-20 tokens and native ether. It also mints NFT receipts for each deposit.

**Key Features:**

- Deposit ERC-20 tokens and native ether.
- Withdraw ERC-20 tokens and native ether.
- Mint NFT receipts for deposits.
