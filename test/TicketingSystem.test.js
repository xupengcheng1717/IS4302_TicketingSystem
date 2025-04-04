const { expect } = require("chai");
const { ethers } = require("hardhat");

describe("Ticketing System", function () {
  let EventFactory;
  let TicketNFT;
  let Marketplace;
  let eventFactory;
  let ticketNFT;
  let marketplace;
  let owner;
  let organiser1;
  let organiser2;
  let buyer1;
  let buyer2;
  let buyer3;
  let mockOracle;

  before(async function () {
    // Get signers
    [owner, organiser1, organiser2, buyer1, buyer2, buyer3] = await ethers.getSigners();

    // Deploy mock oracle
    const MockOracle = await ethers.getContractFactory("MockOracle");
    mockOracle = await MockOracle.deploy();
    await mockOracle.waitForDeployment();

    // Deploy EventFactory
    EventFactory = await ethers.getContractFactory("EventFactory");
    eventFactory = await EventFactory.deploy(await mockOracle.getAddress());
    await eventFactory.waitForDeployment();

    // Deploy TicketNFT
    TicketNFT = await ethers.getContractFactory("TicketNFT");
    ticketNFT = await TicketNFT.deploy(await eventFactory.getAddress());
    await ticketNFT.waitForDeployment();

    // Deploy Marketplace
    Marketplace = await ethers.getContractFactory("Marketplace");
    marketplace = await Marketplace.deploy(await ticketNFT.getAddress(), ethers.utils.parseEther("0.01")); // 0.01 ETH commission fee
    await marketplace.waitForDeployment();
  });

  describe("EventFactory", function () {
    it("Should register an organiser", async function () {
      // Set verification result in mock oracle
      await mockOracle.setVerificationResult(true);
      
      // Register organiser
      await eventFactory.connect(organiser1).registerOrganiser("Organiser 1", "org1@example.com");
      
      // Verify organiser data
      const organiserData = await eventFactory.getOrganiser(organiser1.address);
      expect(organiserData.name).to.equal("Organiser 1");
      expect(organiserData.email).to.equal("org1@example.com");
      expect(organiserData.isVerified).to.equal(true);
    });

    it("Should create an event", async function () {      
      // Create event
      const eventDate = Math.floor(Date.now() / 1000) + 86400;
      const ticketPrice = ethers.utils.parseEther("0.1");
      
      await eventFactory.connect(organiser1).createEvent(
        "Concert A",
        eventDate,
        "Stadium A",
        ticketPrice,
        100
      );
      
      // Get event by ID
      const event = await eventFactory.getEvent(1);
      expect(event.name).to.equal("Concert A");
      expect(event.venue).to.equal("Stadium A");
      expect(event.organiser).to.equal(organiser1.address);
    });

    it("Should verify event details", async function () {
      // Set verification result in mock oracle
      await mockOracle.setVerificationResult(true);
      
      // Call verify event function
      await eventFactory.verifyEvent(1);
      
      // Check if event is verified
      const event = await eventFactory.getEvent(1);
      expect(event.isVerified).to.equal(true);
    });

    it("Should get all events", async function () {
      // Register organiser 2
      await eventFactory.connect(organiser2).registerOrganiser("Organiser 2", "org2@example.com");
      
      // Create event B
      const eventDate = Math.floor(Date.now() / 1000) + 86400;
      const ticketPrice = ethers.utils.parseEther("0.1");
      
      await eventFactory.connect(organiser2).createEvent(
        "Concert B",
        eventDate,
        "Stadium B",
        ticketPrice,
        200
      );
      
      // Get all events
      const events = await eventFactory.getAllEvents();
      expect(events.length).to.equal(2);
      expect(events[0].name).to.equal("Concert A");
      expect(events[1].name).to.equal("Concert B");
    });
  });

  describe("TicketNFT", function () {
    it("Should have minted tickets for an event", async function () {
      // Mint tickets for event A by organiser 1
      await ticketNFT.connect(organiser1).mintTickets(1, 10);
      
      // Check ticket details
      const ticketCount = await ticketNFT.getTicketCount();
      expect(ticketCount).to.equal(10);
      
      const ticket = await ticketNFT.getTicket(1);
      expect(ticket.eventId).to.equal(1);
      expect(ticket.purchasePrice).to.equal(await eventFactory.getEventTicketPrice(1));
      expect(ticket.forSale).to.equal(false);
    });

    it("Should allow initial sale of tickets from organiser to buyers", async function () {
      // Buy a ticket for concert A
      await ticketNFT.connect(buyer1).buyTicket(1, { value: ticketPrice });
      
      // Check ownership
      const owner = await ticketNFT.ownerOf(1);
      expect(owner).to.equal(buyer1.address);
      
      // Check ticket details
      const ticket = await ticketNFT.getTicket(1);
      expect(ticket.owner).to.equal(buyer1.address);
    });

    it("Should transfer tickets between owners", async function () {
      // Transfer ticket 1 to another buyer
      await ticketNFT.connect(buyer1).transferFrom(buyer1.address, buyer2.address, 1);
      
      // Check new ownership
      const owner = await ticketNFT.ownerOf(1);
      expect(owner).to.equal(buyer2.address);
    });
  });

  describe("Marketplace", function () {
    it("Should list a ticket for sale", async function () {
      // List ticket 1 for sale
      const resalePrice = ethers.utils.parseEther("0.2");
      await marketplace.connect(buyer1).listTicket(1, resalePrice);
      
      // Check if ticket 1 is listed
      const isListed = await marketplace.isTicketListed(1);
      expect(isListed).to.equal(true);
      
      // Check listing price
      const price = await marketplace.getTicketPrice(1);
      expect(price).to.equal(resalePrice);
    });

    it("Should unlist a ticket", async function () {
      // Unlist ticket 1
      await marketplace.connect(buyer1).unlistTicket(1);
      
      // Check if ticket is unlisted
      const isListed = await marketplace.isTicketListed(1);
      expect(isListed).to.equal(false);
      
      // Check ownership is returned
      const owner = await ticketNFT.ownerOf(1);
      expect(owner).to.equal(buyer1.address);
    });

    it("Should buy a listed ticket", async function () {
      // Buy a ticket for concert A
      await ticketNFT.connect(buyer2).buyTicket(1, { value: ticketPrice });

      // List ticket first
      const resalePrice = ethers.utils.parseEther("0.2");
      await marketplace.connect(buyer1).listTicket(2, resalePrice);
      
      // Get commission fee
      const commissionFee = await marketplace.commissionFee();
      
      // Buy ticket 2
      await marketplace.connect(buyer3).buyTicket(2, { value: resalePrice.add(commissionFee) });
      
      // Check new ownership
      const owner = await ticketNFT.ownerOf(2);
      expect(owner).to.equal(buyer2.address);
      
      // Check if ticket is unlisted after purchase
      const isListed = await marketplace.isTicketListed(2);
      expect(isListed).to.equal(false);
    });
  });
});