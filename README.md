# Escrow Marketplace 🤝

> A trustless, decentralized escrow system built on Solidity — enabling secure peer-to-peer transactions on the blockchain.

---

## Table of Contents

- [About](#about)
- [How It Works](#how-it-works)
- [Features](#features)
- [Tech Stack](#tech-stack)
- [Getting Started](#getting-started)
  - [Prerequisites](#prerequisites)
  - [Installation](#installation)
  - [Build](#build)
  - [Test](#test)
  - [Deploy](#deploy)
- [Project Structure](#project-structure)
- [Contract Overview](#contract-overview)
- [CI / GitHub Actions](#ci--github-actions)
- [Security Considerations](#security-considerations)
- [Contributing](#contributing)
- [License](#license)

---

## About

**Escrow Marketplace** is a smart contract-based escrow system written in Solidity. It enables buyers and sellers to transact securely without needing to trust each other — the contract acts as a neutral third party, holding funds until the agreed conditions are met.

Built and tested with [Foundry](https://book.getfoundry.sh/), the project is designed to be lightweight, gas-efficient, and easy to integrate into any marketplace or freelance platform.

---

## How It Works

The escrow lifecycle follows three simple steps:

```
Buyer deposits funds
       ↓
  Funds held in escrow (smart contract)
       ↓
  Seller delivers / Buyer confirms
       ↓
  Funds released to seller  ──OR──  Funds refunded to buyer (dispute)
```

1. **Buyer** creates an escrow and deposits ETH (or tokens)
2. **Seller** fulfills the order or service
3. **Buyer** confirms delivery → funds are released to the seller
4. If there's a dispute, a designated **arbiter** can resolve it and decide where the funds go

---

## Features

- 🔒 **Trustless escrow** — funds are locked in the contract, not held by any party
- ⚖️ **Dispute resolution** — an arbiter can be assigned to mediate conflicts
- 💸 **ETH support** — native Ether used for payments
- 🧪 **Fully tested** — comprehensive test suite using Forge
- ⚡ **Gas efficient** — lean contract with no unnecessary dependencies
- 🤖 **CI/CD pipeline** — automated testing via GitHub Actions
- 🔗 **EVM compatible** — deployable on Ethereum and any EVM chain

---

## Tech Stack

| Layer           | Technology                                                        |
|-----------------|-------------------------------------------------------------------|
| Smart Contracts | Solidity                                                          |
| Dev Toolchain   | [Foundry](https://book.getfoundry.sh/) (Forge, Cast, Anvil, Chisel) |
| CI              | GitHub Actions                                                    |
| Network         | EVM-compatible (Ethereum, Sepolia, Polygon, etc.)                 |

---

## Getting Started

### Prerequisites

Install [Foundry](https://book.getfoundry.sh/getting-started/installation):

```bash
curl -L https://foundry.paradigm.xyz | bash
foundryup
```

### Installation

1. Clone the repository with submodules:

```bash
git clone --recurse-submodules https://github.com/Yashmevada2807/Escrow_Marketplace.git
cd Escrow_Marketplace
```

2. If you already cloned without submodules:

```bash
git submodule update --init --recursive
```

### Build

Compile the contracts:

```bash
forge build
```

### Test

Run the full test suite:

```bash
forge test
```

Run with verbose output to see logs and traces:

```bash
forge test -vvvv
```

### Format

```bash
forge fmt
```

### Gas Snapshots

```bash
forge snapshot
```

### Local Node (Anvil)

Spin up a local Ethereum node for development:

```bash
anvil
```

### Deploy

Deploy the escrow contract to a network:

```bash
forge script script/EscrowMarketplace.s.sol:EscrowMarketplaceScript \
  --rpc-url <your_rpc_url> \
  --private-key <your_private_key> \
  --broadcast
```

### Cast

Interact with a deployed contract:

```bash
# Create an escrow (buyer deposits ETH)
cast send <contract_address> "createEscrow(address,address)" <seller> <arbiter> \
  --value 0.1ether --private-key <your_private_key>

# Confirm delivery and release funds
cast send <contract_address> "confirmDelivery(uint256)" <escrow_id> \
  --private-key <your_private_key>
```

---

## Project Structure

```
Escrow_Marketplace/
├── src/                          # Solidity smart contracts
│   └── EscrowMarketplace.sol     # Core escrow contract
├── test/                         # Forge test files
├── script/                       # Deployment scripts
├── lib/                          # Git submodule dependencies
├── .github/
│   └── workflows/                # GitHub Actions CI pipeline
├── foundry.toml                  # Foundry configuration
├── foundry.lock                  # Locked dependency versions
└── .gitignore
```

---

## Contract Overview

### `EscrowMarketplace.sol`

The core contract managing escrow creation, fund custody, and settlement.

| Function                          | Access     | Description                                           |
|-----------------------------------|------------|-------------------------------------------------------|
| `createEscrow(seller, arbiter)`   | Buyer      | Create a new escrow and deposit ETH                   |
| `confirmDelivery(escrowId)`       | Buyer      | Confirm order received — releases funds to seller     |
| `refundBuyer(escrowId)`           | Arbiter    | Refund the buyer in case of dispute                   |
| `releaseFunds(escrowId)`          | Arbiter    | Release funds to seller after arbiter resolves dispute|
| `getEscrow(escrowId)`             | Anyone     | View details of a specific escrow                     |

**Escrow States:**

```
PENDING → COMPLETED (buyer confirms)
PENDING → DISPUTED  (dispute raised)
DISPUTED → RESOLVED (arbiter decides)
```

> Contract addresses will be updated here upon testnet/mainnet deployment.

---

## CI / GitHub Actions

Every push and pull request triggers an automated workflow that:

1. Sets up Foundry
2. Initializes git submodules
3. Compiles contracts with `forge build`
4. Runs the full test suite with `forge test`

See `.github/workflows/` for the pipeline configuration.

---

## Security Considerations

- **Reentrancy** — ensure checks-effects-interactions pattern is followed in all fund-releasing functions
- **Access control** — only the designated buyer or arbiter can trigger state changes
- **Arbiter trust** — the arbiter is a trusted party; choose wisely or use a DAO/multisig for production
- **Audit** — this contract has not been formally audited; use on mainnet at your own risk

---

## Contributing

Contributions are welcome! To get started:

1. Fork the repository
2. Create a new branch: `git checkout -b feature/your-feature-name`
3. Write tests for any new functionality
4. Run `forge test` to make sure everything passes
5. Open a Pull Request

---

## License

This project is licensed under the [MIT License](LICENSE).

---

_Made with ❤️ by [Yash Mevada](https://github.com/Yashmevada2807)_
