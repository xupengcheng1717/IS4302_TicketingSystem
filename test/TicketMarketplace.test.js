const { expect } = require("chai");
const { ethers } = require("hardhat");
const { time } = require("@nomicfoundation/hardhat-network-helpers");

describe("TicketMarketplace", function () {
    let TicketNFT;
    let FestivalToken;
    let TicketFactory;
    let TicketMarketplace;
    let FestivalStatusVoting;
    let ticketNFT;
    let festivalToken;
    let ticketFactory;
    let marketplace;
    let votingContract;
    let owner;
    let organiser;
    let seller;
    let buyer;

    // Test variables
    const eventName = "Summer Festival";
    const eventSymbol = "SF2024";
    const eventId = "SF001";
    let eventDateTime;
    const ticketPrice = ethers.parseEther("0.1");
    const maxSupply = 100;
    const marketplaceFee = 5; // 5% fee

    before(async function () {
        [owner, organiser, seller, buyer] = await ethers.getSigners();
        eventDateTime = (await time.latest()) + 86400;

        // Deploy FestivalToken
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
            await votingContract.getAddress()
        );
        await ticketFactory.waitForDeployment();

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

        // Deploy TicketMarketplace
        TicketMarketplace = await ethers.getContractFactory("TicketMarketplace");
        marketplace = await TicketMarketplace.deploy(
            await festivalToken.getAddress(),
            await ticketFactory.getAddress(),
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
            const sellingPrice = ticketPrice * BigInt(2); // 200% of original price
            
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
            const listing = await marketplace.getListingDetails(ticketId);
            const totalPrice = listing[0] + (listing[0] * BigInt(marketplaceFee)) / 100n;
            
            await marketplace.connect(buyer).buyTicket(ticketId);
            
            expect(await ticketNFT.ownerOf(ticketId)).to.equal(buyer.address);
        });

        it("Should transfer fees to organiser", async function () {
            const initialBalance = await festivalToken.balanceOf(organiser.address);
            const ticketId = 3;
            const sellingPrice = ticketPrice;
            
            await ticketNFT.connect(seller).approve(await marketplace.getAddress(), ticketId);
            await marketplace.connect(seller).listTicket(ticketId, sellingPrice);
            await marketplace.connect(buyer).buyTicket(ticketId);
            
            const finalBalance = await festivalToken.balanceOf(organiser.address);
            expect(finalBalance).to.be.gt(initialBalance);
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
            const newFee = 7; // 7%
            await marketplace.connect(organiser).setMarketplaceFee(newFee);
            
            // We would need a getter function to verify the new fee
            // For now, we can verify through a purchase
            const ticketId = 5;
            const sellingPrice = ticketPrice;
            
            await ticketNFT.connect(seller).approve(await marketplace.getAddress(), ticketId);
            await marketplace.connect(seller).listTicket(ticketId, sellingPrice);
            
            // The purchase should succeed with the new fee
            await marketplace.connect(buyer).buyTicket(ticketId);
        });

        it("Should not allow fee above 10%", async function () {
            await expect(
                marketplace.connect(organiser).setMarketplaceFee(11)
            ).to.be.revertedWith("Fee too high");
        });
    });
});