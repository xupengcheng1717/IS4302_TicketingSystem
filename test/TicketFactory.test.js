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
    let MockOracle;
    let oracle;
    
    // Test variables
    const eventId = "G5vYZb2n_2V2d"; // Use the predefined event ID from MockOracle
    const eventSymbol = "ANDY2024";
    const ticketPrice = 10;
    const totalSupply = 100;

    before(async function () {
        [owner, organiser, addr1] = await ethers.getSigners();

        // Deploy MockOracle first
        MockOracle = await ethers.getContractFactory("MockOracle");
        oracle = await MockOracle.deploy();
        await oracle.waitForDeployment();

        // Deploy other contracts
        FestivalToken = await ethers.getContractFactory("FestivalToken");
        festivalToken = await FestivalToken.deploy(ethers.parseEther("0.01"));
        await festivalToken.waitForDeployment();

        FestivalStatusVoting = await ethers.getContractFactory("FestivalStatusVoting");
        votingContract = await FestivalStatusVoting.deploy();
        await votingContract.waitForDeployment();

        TicketFactory = await ethers.getContractFactory("TicketFactory");
        ticketFactory = await TicketFactory.deploy(
            await festivalToken.getAddress(),
            await votingContract.getAddress(),
            await oracle.getAddress()
        );
        await ticketFactory.waitForDeployment();

        // Impersonate the verified organiser address
        const organiserAddress = "0x400322347ad8fF4c9e899044e3aa335F53fFA42B";
        await network.provider.request({
            method: "hardhat_impersonateAccount",
            params: [organiserAddress],
        });

        // Fund the organiser account with ETH
        await owner.sendTransaction({
            to: organiserAddress,
            value: ethers.parseEther("10.0"), // Send 10 ETH
        });

        organiser = await ethers.getSigner(organiserAddress);
    });

    describe("Event Creation", function () {
        it("Should create a new event and NFT contract successfully", async function () {
            const tx = await ticketFactory.connect(organiser).createEvent(
                eventId,
                eventSymbol,
                ticketPrice,
                totalSupply
            );
            
            const receipt = await tx.wait();
            // Get event data from the emitted event
            const eventCreated = receipt.logs.find(
                log => log.fragment && log.fragment.name === 'EventCreated'
            );
            const ticketNFTAddress = eventCreated.args.ticketContractAddress;

            // Get oracle data for comparison
            const oracleData = await oracle.getEventData(eventId);
            const eventName = oracleData[1];
            const eventDateTime = oracleData[2];
            const eventLocation = oracleData[3];
            const eventDescription = oracleData[4];

            // Verify event details
            const eventDetails = await ticketFactory.getEventDetails(eventId);
            expect(eventDetails[0]).to.equal(eventId);
            expect(eventDetails[1]).to.equal(eventName);
            expect(eventDetails[2]).to.equal(eventSymbol);
            expect(eventDetails[3]).to.equal(eventDateTime);
            expect(eventDetails[4]).to.equal(eventLocation);
            expect(eventDetails[5]).to.equal(eventDescription);
            expect(eventDetails[6]).to.equal(organiser.address);
            expect(eventDetails[7]).to.equal(ticketPrice);
            expect(eventDetails[8]).to.equal(totalSupply);

            // Verify NFT contract
            const ticketContract = await ethers.getContractAt("TicketNFT", ticketNFTAddress);
            expect(await ticketContract.name()).to.equal(eventName);
            expect(await ticketContract.symbol()).to.equal(eventSymbol);
            expect(await ticketContract.getEventId()).to.equal(eventId);
            expect(await ticketContract.getTicketPrice()).to.equal(ticketPrice);
            expect(await ticketContract.getOrganiser()).to.equal(organiser.address);

            // Verify voting created
            const votingDetails = await votingContract.getVotingDetail(eventId);
            expect(votingDetails[4]).to.equal(ticketNFTAddress);
        });

        it("Should not allow unverified organiser to create event", async function () {
            await expect(
                ticketFactory.connect(addr1).createEvent(
                    "NewEvent",
                    "NEW",
                    ticketPrice,
                    totalSupply
                )
            ).to.be.revertedWith("Not a verified organiser");
        });

        it("Should not allow duplicate event IDs", async function () {
            await expect(
                ticketFactory.connect(organiser).createEvent(
                    eventId,
                    "DUP",
                    ticketPrice,
                    totalSupply
                )
            ).to.be.revertedWith("Event ID already exists");
        });
    });

    describe("Event Queries", function () {
        let eventName, eventDateTime, eventLocation, eventDescription;

        before(async function() {
            // Get oracle data for comparison
            const oracleData = await oracle.getEventData(eventId);
            eventName = oracleData[1];
            eventDateTime = oracleData[2];
            eventLocation = oracleData[3];
            eventDescription = oracleData[4];
        });

        it("Should get event details correctly", async function () {
            const eventDetails = await ticketFactory.getEventDetails(eventId);
            expect(eventDetails[0]).to.equal(eventId);
            expect(eventDetails[1]).to.equal(eventName);
            expect(eventDetails[2]).to.equal(eventSymbol);
            expect(eventDetails[3]).to.equal(eventDateTime);
            expect(eventDetails[4]).to.equal(eventLocation);
            expect(eventDetails[5]).to.equal(eventDescription);
            expect(eventDetails[6]).to.equal(organiser.address);
            expect(eventDetails[7]).to.equal(ticketPrice);
            expect(eventDetails[8]).to.equal(totalSupply);
        });
    });
});