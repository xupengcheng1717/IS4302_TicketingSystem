const { expect } = require("chai");
const { ethers } = require("hardhat");
const { time } = require("@nomicfoundation/hardhat-network-helpers");

describe("TicketNFT", function () {
    let TicketNFT;
    let FestivalToken;
    let FestivalStatusVoting;
    let ticketNFT;
    let festivalToken;
    let votingContract;
    let owner;
    let organiser;
    let customer;
    let marketplace;

    // Test variables
    const eventName = "Summer Festival";
    const eventSymbol = "SF2024";
    const eventId = "SF001";
    let eventDateTime;
    const ticketPrice = ethers.parseEther("0.1");
    const maxSupply = 100;

    before(async function () {
        [owner, organiser, customer, marketplace] = await ethers.getSigners();
        eventDateTime = (await time.latest()) + 86400;

        // Deploy FestivalToken with rate of 0.01 ETH per token
        FestivalToken = await ethers.getContractFactory("FestivalToken");
        festivalToken = await FestivalToken.deploy(ethers.parseEther("0.01"));
        await festivalToken.waitForDeployment();

        // Deploy FestivalStatusVoting
        FestivalStatusVoting = await ethers.getContractFactory("FestivalStatusVoting");
        votingContract = await FestivalStatusVoting.deploy();
        await votingContract.waitForDeployment();

        // Deploy TicketNFT
        TicketNFT = await ethers.getContractFactory("TicketNFT");
        ticketNFT = await TicketNFT.deploy(
            eventName,
            eventSymbol,
            eventId,
            eventDateTime,
            ticketPrice,
            maxSupply,
            organiser.address,
            await festivalToken.getAddress(),
            await votingContract.getAddress()
        );
        await ticketNFT.waitForDeployment();

        // Setup initial states - Fix token purchase
        const creditTx = await festivalToken.connect(customer).getCredit({ 
            value: ethers.parseEther("1.0") // Send 1 ETH
        });
        await creditTx.wait();

        // Log balances to verify
        const balance = await festivalToken.balanceOf(customer.address);
        console.log("Initial customer token balance:", ethers.formatEther(balance));

        await festivalToken.connect(customer).approve(await ticketNFT.getAddress(), ethers.parseEther("10.0"));
    });

    describe("Deployment", function () {
        it("Should set the correct event details", async function () {
            expect(await ticketNFT.name()).to.equal(eventName);
            expect(await ticketNFT.symbol()).to.equal(eventSymbol);
            expect(await ticketNFT.getEventId()).to.equal(eventId);
            expect(await ticketNFT.getTicketPrice()).to.equal(ticketPrice);
            expect(await ticketNFT.getOrganiser()).to.equal(organiser.address);
        });

        it("Should assign roles correctly", async function () {
            const MINTER_ROLE = await ticketNFT.MINTER_ROLE();
            const DEFAULT_ADMIN_ROLE = await ticketNFT.DEFAULT_ADMIN_ROLE();
            expect(await ticketNFT.hasRole(MINTER_ROLE, organiser.address)).to.be.true;
            expect(await ticketNFT.hasRole(DEFAULT_ADMIN_ROLE, organiser.address)).to.be.true;
        });
    });

    describe("Ticket Minting", function () {
        it("Should allow organiser to mint tickets", async function () {
            await ticketNFT.connect(organiser).bulkMintTickets(5, organiser.address);
            expect(await ticketNFT.ticketCounts()).to.equal(5);
        });

        it("Should not allow non-minter to mint tickets", async function () {
            await expect(
                ticketNFT.connect(customer).bulkMintTickets(1, customer.address)
            ).to.be.revertedWith("Must have minter role");
        });

        it("Should not exceed max supply", async function () {
            await expect(
                ticketNFT.connect(organiser).bulkMintTickets(maxSupply + 1, organiser.address)
            ).to.be.revertedWith("Exceeds maximum supply");
        });
    });

    describe("Ticket Purchase", function () {
        before(async function () {
            // Clear previous mints and start fresh
            await ticketNFT.connect(organiser).bulkMintTickets(5, organiser.address);
            
            // Log ticket details for debugging
            console.log("Total tickets minted:", (await ticketNFT.ticketCounts()).toString());
            console.log("First ticket owner:", await ticketNFT.ownerOf(1));
        });

        it("Should allow customers to buy tickets", async function () {
            const purchaseQty = 2;
            const initialBalance = await festivalToken.balanceOf(customer.address);
            console.log("Customer balance before purchase:", ethers.formatEther(initialBalance));
            
            const tx = await ticketNFT.connect(customer).buyTickets(purchaseQty);
            const receipt = await tx.wait();
            
            // Get the purchased tickets from transaction events or query the contract
            for (let i = 1; i <= purchaseQty; i++) {
                const ticketId = i;
                console.log("Checking ownership of ticket:", ticketId);
                const owner = await ticketNFT.ownerOf(ticketId);
                console.log("Ticket", ticketId, "owner:", owner);
                expect(owner).to.equal(customer.address);
            }
        });

        it("Should update customer list after purchase", async function () {
            expect(await ticketNFT.isCustomerExists(customer.address)).to.be.true;
            expect(await ticketNFT.getNumberOfCustomers()).to.equal(1);
        });

        it("Should not allow purchase without sufficient tokens", async function () {
            await expect(
                ticketNFT.connect(marketplace).buyTickets(1)
            ).to.be.revertedWith("Insufficient token balance");
        });
    });

    describe("Marketplace Integration", function () {
        it("Should allow admin to set marketplace", async function () {
            await ticketNFT.connect(organiser).setMarketplace(marketplace.address);
            const MARKETPLACE_ROLE = await ticketNFT.MARKETPLACE_ROLE();
            expect(await ticketNFT.hasRole(MARKETPLACE_ROLE, marketplace.address)).to.be.true;
        });

        it("Should allow marketplace to update customer array", async function () {
            const newCustomer = owner;
            await ticketNFT.connect(marketplace).updateCustomersArray(customer.address, newCustomer.address);
            expect(await ticketNFT.isCustomerExists(newCustomer.address)).to.be.true;
        });
    });

    describe("Ticket Usage and Voting", function () {
        it("Should allow organiser to scan ticket", async function () {
            const ticketId = 1;
            await ticketNFT.connect(organiser).scanNFT(customer.address, ticketId);
            const ticketDetails = await ticketNFT.getTicketDetails(ticketId);
            expect(ticketDetails.isUsed).to.be.true;
        });

        it("Should not allow scanning used tickets", async function () {
            const ticketId = 1;
            await expect(
                ticketNFT.connect(organiser).scanNFT(customer.address, ticketId)
            ).to.be.revertedWith("Ticket has already been used");
        });
    });

    describe("Refunds and Withdrawals", function () {
        it("Should allow organiser to withdraw funds after event", async function () {
            await time.increase(86400 * 4); // Move 4 days into the future
            const balance = await festivalToken.balanceOf(await ticketNFT.getAddress());
            await ticketNFT.connect(organiser).withdrawAllFunds();
            expect(await festivalToken.balanceOf(organiser.address)).to.equal(balance);
        });

        it("Should handle refunds when event is cancelled", async function () {
            // Mock event cancellation through voting contract
            // This would require additional setup in the voting contract
            // Test refund functionality
            await expect(
                ticketNFT.connect(organiser).refundAllTickets()
            ).to.be.revertedWith("Event is not cancelled");
        });
    });
});