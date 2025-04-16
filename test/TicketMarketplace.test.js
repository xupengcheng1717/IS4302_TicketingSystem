const { expect } = require("chai");
const { ethers } = require("hardhat");
const { time } = require("@nomicfoundation/hardhat-network-helpers");

describe("TicketMarketplace", function () {
    let TicketNFT;
    let FestivalToken;
    let TicketFactory;
    let TicketMarketplace;
    let FestivalStatusVoting;
    let MockOracle;
    let oracle;
    let ticketNFT;
    let festivalToken;
    let ticketFactory;
    let marketplace;
    let votingContract;
    let organiser;
    let seller;
    let buyer;

    // Test variables
    const eventId = "G5vYZb2n_2V2d";
    const eventSymbol = "ANDY2024";
    const ticketPrice = 10;
    const maxSupply = 100;
    const marketplaceFee = 10; // 10% per transaction
    let eventName, eventDateTime, eventLocation, eventDescription;

    before(async function () {
        [organiser, seller, buyer] = await ethers.getSigners();

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

        // Deploy TicketFactory
        TicketFactory = await ethers.getContractFactory("TicketFactory");
        ticketFactory = await TicketFactory.deploy(
            await festivalToken.getAddress(),
            await votingContract.getAddress(),
            await oracle.getAddress()
        );
        await ticketFactory.waitForDeployment();

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

        // Deploy TicketMarketplace with all required parameters
        TicketMarketplace = await ethers.getContractFactory("TicketMarketplace");
        marketplace = await TicketMarketplace.deploy(
            await festivalToken.getAddress(),
            await ticketNFT.getAddress(),
            organiser.address,
            marketplaceFee
        );
        await marketplace.waitForDeployment();
        
        // Setup initial states
        await ticketNFT.connect(organiser).setMarketplace(await marketplace.getAddress());
        
        // Get tokens for seller and buyer
        await festivalToken.connect(seller).getCredit({ value: ethers.parseEther("1.0") });
        await festivalToken.connect(buyer).getCredit({ value: ethers.parseEther("1.0") });
        
        // Approve marketplace for token transfers
        await festivalToken.connect(seller).approve(await marketplace.getAddress(), ethers.parseEther("10.0"));
        await festivalToken.connect(buyer).approve(await marketplace.getAddress(), ethers.parseEther("10.0"));

        // Mint some tickets to seller
        await ticketNFT.connect(organiser).bulkMintTickets(5, seller.address);
    });

    describe("Marketplace Setup", function () {
        it("Should set the correct marketplace address in TicketNFT", async function () {
            const MARKETPLACE_ROLE = await ticketNFT.MARKETPLACE_ROLE();
            expect(await ticketNFT.hasRole(MARKETPLACE_ROLE, await marketplace.getAddress())).to.be.true;
        });
    });

    describe("Ticket Listing", function () {
        it("Should allow seller to list a ticket", async function () {
            const ticketId = 1;
            const sellingPrice = ticketPrice; // Selling at original price
            
            // First approve the marketplace to handle the NFT
            await ticketNFT.connect(seller).setApprovalForAll(await marketplace.getAddress(), true);
            
            // Then list the ticket
            await marketplace.connect(seller).listTicket(ticketId, sellingPrice);
            
            const listing = await marketplace.getListingDetails(ticketId);
            expect(listing[0]).to.equal(sellingPrice); // sellingPrice is first element
            expect(listing[1]).to.equal(seller.address); // seller is second element
            expect(listing[2]).to.be.true; // isActive is third element
        });

        it("Should not allow listing above 110% of original price", async function () {
            const ticketId = 2;
            const sellingPrice = ticketPrice * 2; // 200% of original price
            
            // Approve marketplace (even though the listing will fail)
            await ticketNFT.connect(seller).setApprovalForAll(await marketplace.getAddress(), true);
            
            await expect(
                marketplace.connect(seller).listTicket(ticketId, sellingPrice)
            ).to.be.revertedWith("Re-selling price exceeds 110%");
        });
    });

    describe("Ticket Purchase", function () {
        it("Should allow buyer to purchase a listed ticket", async function () {
            const ticketId = 1;
            await marketplace.connect(buyer).buyTicket(ticketId);
            expect(await ticketNFT.ownerOf(ticketId)).to.equal(buyer.address);
        });

        it("Should update token balances of buyer, seller, and organiser", async function () {
            expect(await festivalToken.balanceOf(buyer.address)).to.equal(89);
            expect(await festivalToken.balanceOf(seller.address)).to.equal(110);
            expect(await festivalToken.balanceOf(organiser.address)).to.equal(1);
        });
    });

    describe("Ticket Unlisting", function () {
        it("Should allow seller to unlist a ticket", async function () {
            const ticketId = 4;
            const sellingPrice = ticketPrice;
            
            await ticketNFT.connect(seller).approve(await marketplace.getAddress(), ticketId);
            await marketplace.connect(seller).listTicket(ticketId, sellingPrice);
            await marketplace.connect(seller).unlistTicket(ticketId);
            
            await expect(
                marketplace.getListingDetails(ticketId)
            ).to.be.revertedWith("Ticket not listed for sale");
        });
    });

    describe("Marketplace Administration", function () {
        it("Should allow organiser to update marketplace fee", async function () {
            const newFee = 7;
            await marketplace.connect(organiser).setMarketplaceFee(newFee);
            
            // verify the fee has been updated
            expect(await marketplace.getMarketplaceFee()).to.equal(newFee); 
        });

        it("Should not allow fee above 10%", async function () {
            await expect(
                marketplace.connect(organiser).setMarketplaceFee(11)
            ).to.be.revertedWith("Marketplace fee too high");
        });
    });
});