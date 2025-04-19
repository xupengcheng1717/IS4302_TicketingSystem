# 🎟️ Tikex

Welcome to **Tikex**, a decentralized platform for creating, managing, and purchasing event tickets using blockchain technology. This system leverages smart contracts written in Solidity to ensure transparency, security, and efficiency in event ticketing and management.

---

## Table of Contents

1. [📖 Overview](#overview)
2. [✨ Features](#features)
3. [🏗️ System Architecture](#system-architecture)
4. [📸 Screenshots](#screenshots)
5. [🚀 Getting Started](#getting-started)
6. [🤝 Contributors](#contributors)
7. [📜 License](#license)

---

## Overview

The Event Ticketing System is designed to provide a seamless experience for event organizers and attendees. It allows organizers to create events, mint NFT-based tickets, and manage ticket sales. Attendees can purchase tickets, participate in event-related voting, and resell tickets on a regulated secondary marketplace.

This platform ensures transparency and trust by leveraging blockchain technology, with all transactions and event details stored on-chain.

---

## Features

- **🎉 Event Creation**: Organizers can create events and deploy NFT-based ticket contracts.
- **🎫 NFT Tickets**: Tickets are represented as ERC721 tokens, ensuring uniqueness and traceability.
- **🗳️ Voting Mechanism**: Attendees can vote on event-related decisions, such as cancellations.
- **🔄 Secondary Marketplace**: A regulated marketplace for ticket resale with price restrictions.
- **💰 Token Integration**: Transactions are powered by the platform's native token, **FestivalToken**.
- **💸 Refund Mechanism**: Automatic refunds for attendees if an event is canceled.

---

## System Architecture

The system is built on a modular architecture with the following key components:

1. **🏭 TicketFactory**: Manages event creation and ticket contract deployment.
2. **🎟️ TicketNFT**: Handles ticket minting, purchasing, and transfers.
3. **🪙 FestivalToken**: The native token used for transactions within the platform.
4. **🗳️ FestivalStatusVoting**: Enables decentralized voting for event-related decisions.
5. **🔄 TicketMarketplace**: Facilitates ticket resale with enforced price restrictions.
6. **📡 MockOracle**: Provides verified event data for organizers.

---

## Screenshots

Below are some placeholder images from the Figma design of the mobile app:

### 1. 🏠 Login Screen

![iPhone 16 Pro Max - 1](https://github.com/user-attachments/assets/93aae736-b45a-471e-91aa-27bc016edc88)

### 2. 💳 Ticket Purchase

![iPhone 16 Pro Max - 6](https://github.com/user-attachments/assets/6a10f70e-1e01-42a6-8079-3aa1703d55e6)

### 3. 🗳️ Voting Screen

![iPhone 16 Pro Max - 8](https://github.com/user-attachments/assets/b25764ff-89cd-4dea-b33e-db7bafc6e799)

### 4. 🛒 Marketplace

![iPhone 16 Pro Max - 2](https://github.com/user-attachments/assets/caee0ef8-74fb-4fad-977a-a14c0547adf5)


---

## Getting Started

### Prerequisites

- 🖥️ Node.js (v16 or higher)
- 🛠️ Hardhat
- 🔐 A blockchain wallet (e.g., MetaMask)

### Installation

1. Clone the repository:

   ```bash
   git clone https://github.com/your-repo/event-ticketing-system.git
   cd event-ticketing-system
   ```

2. Install dependencies:

   ```bash
   npm install
   ```

3. Compile the smart contracts:

   ```bash
   npx hardhat compile
   ```

4. Deploy the contracts:

   ```bash
   npx hardhat run scripts/deploy.js 
   ```

5. Start the development server:
   ```bash
   npm start
   ```

---

## Contributors

We would like to thank the following contributors for their efforts in building this project:

### 1. [👨‍💻 Jamie Lee](https://github.com/jamielfh)

### 2. [👨‍💻 Xu Pengcheng](https://github.com/xupengcheng1717)

### 3. [👨‍💻 Rishikesh Kadiyala](https://github.com/RishiPrime)

### 4. [👨‍💻 Go Song Ying](https://github.com/gosongying)

### 5. [👨‍💻 Ow Zheng Wei](https://github.com/zzhengweii)

### 6. [👨‍💻 Chia Ming Han](https://github.com/minghan101)

---

## License

This project is licensed under the MIT License. See the [📜 LICENSE](./LICENSE) file for details.
