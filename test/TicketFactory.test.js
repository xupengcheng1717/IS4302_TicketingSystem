const { expect } = require("chai");
const { ethers } = require("hardhat");
const { time } = require("@nomicfoundation/hardhat-network-helpers");

describe("TicketFactory", function () {
    let FestivalToken;
    let TicketFactory;
    let FestivalStatusVoting;
    let festivalToken;
    let ticketFactory;
    let votingContract;
    let owner;
    let organiser;
    let addr1;
    
    // Test variables
    let eventName;
    let eventSymbol;
    let eventId;
    let eventDateTime;
    let ticketPrice;
    let totalSupply;
    let ticketNFTAddress;

    // Chainlink Functions variables
    const router = "0xb83E47C2bC239B3bf370bc41e1459A34b41238D0";
    const subscriptionId = 1; // Replace with your actual subscription ID

    // Add these variables at the top with other test variables
    let s_lastRequestId;
    let mockResponse;

    before(async function () {
        [owner, organiser, addr1] = await ethers.getSigners();

        // Deploy FestivalToken with required constructor argument (token price)
        FestivalToken = await ethers.getContractFactory("FestivalToken");
        festivalToken = await FestivalToken.deploy(ethers.parseEther("0.01")); // 0.01 ETH per token
        await festivalToken.waitForDeployment();

        // Rest of the deployments remain the same
        FestivalStatusVoting = await ethers.getContractFactory("FestivalStatusVoting");
        votingContract = await FestivalStatusVoting.deploy();
        await votingContract.waitForDeployment();

        TicketFactory = await ethers.getContractFactory("TicketFactory");
        ticketFactory = await TicketFactory.deploy(
            await festivalToken.getAddress(),
            await votingContract.getAddress()
        );
        await ticketFactory.waitForDeployment();

        // Initialize test variables
        eventName = "Summer Festival";
        eventSymbol = "SF2024";
        eventId = "SF001";
        eventDateTime = (await time.latest()) + 86400; // 1 day from now
        ticketPrice = ethers.parseEther("0.1");
        totalSupply = 100;

        // Mock the oracle response
        mockResponse = ethers.AbiCoder.defaultAbiCoder().encode(
            ['string'],
            [organiser.address]
        );
    });

    describe("Event Creation", function () {
        it("Should not allow creating event with past datetime", async function () {
            const pastTime = await time.latest() - 86400; // 1 day ago

            await expect(ticketFactory.connect(organiser).createEvent(
                "Past Event",
                "PAST",
                "PE001",
                pastTime,
                ethers.parseEther("0.1"),
                100
            )).to.be.revertedWith("Event datetime must be in the future");
        });

        it("Should create a new event and NFT contract successfully", async function () {
            // Skip the oracle verification for testing
            // Directly set the fetchedAddress to match organiser's address
            await ticketFactory.connect(owner).fulfillRequest(
                ethers.randomBytes(32), // random requestId
                mockResponse,
                "0x" // empty error
            );
            
            const tx = await ticketFactory.connect(organiser).createEvent(
                eventId,
                eventName,
                eventSymbol,
                eventDateTime,
                ticketPrice,
                totalSupply
            );
            
            const receipt = await tx.wait();
            const event = receipt.events.find(e => e.event === 'EventCreated');
            ticketNFTAddress = event.args.ticketContract;

            // Verify event details
            const eventDetails = await ticketFactory.getEventDetails(eventId);
            expect(eventDetails.eventName).to.equal(eventName);
            expect(eventDetails.organiser).to.equal(organiser.address);
            expect(eventDetails.isActive).to.be.true;

            // Verify NFT contract
            const ticketContract = await ethers.getContractAt("TicketNFT", ticketNFTAddress);
            expect(await ticketContract.name()).to.equal(eventName);
            expect(await ticketContract.symbol()).to.equal(eventSymbol);
            expect(await ticketContract.getEventId()).to.equal(eventId);
            expect(await ticketContract.getTicketPrice()).to.equal(ticketPrice);
            expect(await ticketContract.getOrganiser()).to.equal(organiser.address);

            // Verify voting initialization
            const votingDetails = await votingContract.getVotingDetail(eventId);
            expect(votingDetails.startDateTime).to.equal(eventDateTime);
            expect(votingDetails.endDateTime).to.equal(eventDateTime + (3 * 24 * 60 * 60));
            expect(votingDetails.ticketNFTAddress).to.equal(ticketNFTAddress);
        });

        it("Should not allow duplicate event IDs", async function () {
            await expect(ticketFactory.connect(organiser).createEvent(
                eventName,
                eventSymbol,
                eventId, // Same eventId as previous test
                eventDateTime + 86400,
                ticketPrice,
                totalSupply
            )).to.be.revertedWith("Event ID already exists");
        });
    });

    describe("Event Queries", function () {
        it("Should get event details correctly", async function () {
            const eventDetails = await ticketFactory.getEventDetails(eventId);
            expect(eventDetails.eventName).to.equal(eventName);
            expect(eventDetails.eventSymbol).to.equal(eventSymbol);
            expect(eventDetails.organiser).to.equal(organiser.address);
            expect(eventDetails.ticketPrice).to.equal(ticketPrice);
            expect(eventDetails.totalSupply).to.equal(totalSupply);
        });

        it("Should get events by organiser", async function () {
            const organiserEvents = await ticketFactory.getOrganiserEvents(organiser.address);
            expect(organiserEvents.length).to.equal(1);
            expect(organiserEvents[0]).to.equal(eventId);
        });
    });
});