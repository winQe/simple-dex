# Simple DEX

This project is a decentralized exchange (DEX) prototype implemented using a Constant Product Liquidity Pool Automated Market Maker (AMM) model. It is built with Solidity, Hardhat, and Ethers.

## Table of Contents

- [Simple DEX](#simple-dex)
  - [Table of Contents](#table-of-contents)
  - [Introduction](#introduction)
  - [Features](#features)
  - [Installation](#installation)
  - [Usage](#usage)
    - [Test](#test)
    - [Deployment](#deployment)

## Introduction

This simple DEX allows users to swap between two ERC20 tokens using the Constant Product formula (x * y = k). The liquidity pool ensures that the product of the reserves of the two tokens remains constant, thereby determining the price of the tokens based on the pool's current reserves.

## Features

- **ERC20 Token Deployment**: Deploy ERC20 tokens.
- **Liquidity Pool Management**: Add and remove liquidity from the pool.
- **Token Swapping**: Swap between tokens using the Constant Product formula.
- **Automated Testing**: Comprehensive tests to ensure the functionality of the smart contracts.

## Installation

To install and set up the project, follow these steps:

1. Clone the repository
2. Install dependencies:

``` bash
yarn install
```

3. Compile the smart contracts:

``` bash
yarn hardhat compile
```

## Usage

### Test

``` bash
yarn hardhat test
```

### Deployment

1. Configure the Hardhat network in `hardhat.config.ts`
2. Deploy the contracts

``` bash
yarn hardhat node # for local blockchain
yarn hardhat ignition deploy ./ignition/modules/Pool.ts
```
