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
    let MockOracle;
    let oracle;

    // Test variables
    const eventId = "G5vYZb2n_2V2d";
    const eventSymbol = "ANDY2024";
    const ticketPrice = ethers.parseEther("0.1");
    const maxSupply = 100;
    let eventName, eventDateTime, eventLocation, eventDescription;

    before(async function () {
        [owner, organiser, customer, marketplace] = await ethers.getSigners();

        // Deploy MockOracle first
        MockOracle = await ethers.getContractFactory("MockOracle");
        oracle = await MockOracle.deploy();
        await oracle.waitForDeployment();

        // Get event details from oracle
        const oracleData = await oracle.getEventData(eventId);
        eventName = oracleData[1];
        eventDateTime = oracleData[2];
        eventLocation = oracleData[3];
        eventDescription = oracleData[4];

        // Deploy FestivalToken with rate of 0.01 ETH per token
        FestivalToken = await ethers.getContractFactory("FestivalToken");
        festivalToken = await FestivalToken.deploy(ethers.parseEther("0.01"));
        await festivalToken.waitForDeployment();

        // Deploy FestivalStatusVoting
        FestivalStatusVoting = await ethers.getContractFactory("FestivalStatusVoting");
        votingContract = await FestivalStatusVoting.deploy();
        await votingContract.waitForDeployment();

        // Deploy TicketNFT with oracle data
        TicketNFT = await ethers.getContractFactory("TicketNFT");
        ticketNFT = await TicketNFT.deploy(
            eventName,
            eventSymbol,
            eventId,
            eventDateTime,
            eventLocation,
            eventDescription,
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
        });

        it("Should allow customers to buy tickets", async function () {
            const purchaseQty = 2;
            const tx = await ticketNFT.connect(customer).buyTickets(purchaseQty);
            
            // Get the purchased tickets from transaction events or query the contract
            for (let i = 1; i <= purchaseQty; i++) {
                const ticketId = i;
                const owner = await ticketNFT.ownerOf(ticketId);
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
        before(async function () {
            // Create voting for the event
            const votingEndTime = Number(eventDateTime) + 86400; // Convert to number and add 1 day
            console.log("Voting end time:", votingEndTime); // Log the value for debugging purpose
            await votingContract.connect(organiser).createVoting(
                eventId,
                eventDateTime,
                votingEndTime,
                ticketNFT.getAddress()
            );
        });

        it("Should allow organiser to scan ticket", async function () {
            // Move time to after event start
            await time.increaseTo(eventDateTime + BigInt(1)); // 1 second after event starts
            
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
            // Move time to after the event (event time + 4 days)
            await time.increaseTo(eventDateTime + BigInt(86400 * 4));
            
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