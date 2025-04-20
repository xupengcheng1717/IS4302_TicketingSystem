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
    let seller1;
    let seller2;
    let buyer;

    // Test variables
    const eventId = "G5vYZb2n_2V2d";
    const eventSymbol = "ANDY2024";
    const maxSupply = 200;
    const ticketPrice = 100;
    const marketplaceFee = 100; // 1% per transaction
    let eventName, eventDateTime, eventLocation, eventDescription;

    before(async function () {
        [organiser, seller1, seller2, buyer] = await ethers.getSigners();

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
        festivalToken = await FestivalToken.deploy(ethers.parseEther("0.001"));
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
        
        // Get tokens for sellers and buyer
        await festivalToken.connect(seller1).getCredit({ value: ethers.parseEther("1.0") });
        await festivalToken.connect(seller2).getCredit({ value: ethers.parseEther("1.0") });
        await festivalToken.connect(buyer).getCredit({ value: ethers.parseEther("1.0") });
        
        // Approve marketplace for token transfers
        await festivalToken.connect(seller1).approve(await marketplace.getAddress(), ethers.parseEther("10.0"));
        await festivalToken.connect(seller2).approve(await marketplace.getAddress(), ethers.parseEther("10.0"));
        await festivalToken.connect(buyer).approve(await marketplace.getAddress(), ethers.parseEther("10.0"));

        // Mint some tickets to sellers
        await ticketNFT.connect(organiser).bulkMintTickets(1, seller1.address);
        await ticketNFT.connect(organiser).bulkMintTickets(2, seller2.address);
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
            await ticketNFT.connect(seller1).setApprovalForAll(await marketplace.getAddress(), true);
            
            // Then list the ticket
            await marketplace.connect(seller1).listTicket(ticketId, sellingPrice);
            
            const listing = await marketplace.getListingDetails(ticketId);
            expect(listing[0]).to.equal(sellingPrice); // sellingPrice is first element
            expect(listing[1]).to.equal(seller1.address); // seller is second element
            expect(listing[2]).to.be.true; // isActive is third element
        });

        it("Should not allow listing above 110% of original price", async function () {
            const ticketId = 2;
            const sellingPrice = ticketPrice * 2; // 200% of original price
            
            // Approve marketplace (even though the listing will fail)
            await ticketNFT.connect(seller2).setApprovalForAll(await marketplace.getAddress(), true);
            
            await expect(
                marketplace.connect(seller2).listTicket(ticketId, sellingPrice)
            ).to.be.revertedWith("Re-selling price exceeds 110%");
        });
    });

    describe("Ticket Purchase", function () {
        before(async function() {
            // Add customers to customer array
            await marketplace.__testUpdateCustomersArray(organiser.address, seller1.address);
            await marketplace.__testUpdateCustomersArray(organiser.address, seller2.address);
        });

        it("Should allow buyer to purchase a listed ticket", async function () {
            const ticketId = 1;
            await marketplace.connect(buyer).buyTicket(ticketId);
            expect(await ticketNFT.ownerOf(ticketId)).to.equal(buyer.address);

            // Check if customer array is updated
            expect(await ticketNFT.isCustomerExists(buyer.address)).to.be.true;
            expect(await ticketNFT.isCustomerExists(seller1.address)).to.be.false;
        });

        it("Should update token balances of buyer, seller1, and organiser", async function () {
            expect(await festivalToken.balanceOf(buyer.address)).to.equal(900); // 100 tokens deducted
            expect(await festivalToken.balanceOf(seller1.address)).to.equal(1099); // 99 tokens earned (minus 1% fee)
            expect(await festivalToken.balanceOf(organiser.address)).to.equal(1); // 1 token earned from 1% fee
        });

        it("Should not allow purchase of unlisted ticket", async function () {
            const ticketId = 2;
            await expect(
                marketplace.connect(buyer).buyTicket(ticketId)
            ).to.be.revertedWith("Ticket not listed for sale");
        })
    });

    describe("Ticket Unlisting", function () {
        it("Should allow seller to unlist a ticket", async function () {
            const ticketId = 3;
            const sellingPrice = ticketPrice;
            
            await ticketNFT.connect(seller2).approve(await marketplace.getAddress(), ticketId);
            await marketplace.connect(seller2).listTicket(ticketId, sellingPrice);
            await marketplace.connect(seller2).unlistTicket(ticketId);
            
            await expect(
                marketplace.getListingDetails(ticketId)
            ).to.be.revertedWith("Ticket not listed for sale");
        });
    });

    describe("Marketplace Administration", function () {
        it("Should allow organiser to update marketplace fee", async function () {
            const newFee = 70;
            await marketplace.connect(organiser).setMarketplaceFee(newFee);
            
            // verify the fee has been updated
            expect(await marketplace.getMarketplaceFee()).to.equal(newFee); 
        });

        it("Should not allow fee above 1%", async function () {
            await expect(
                marketplace.connect(organiser).setMarketplaceFee(110)
            ).to.be.revertedWith("Marketplace fee too high");
        });
    });
});