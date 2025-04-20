const hre = require("hardhat");

async function main() {
    // Define deployment variables
    const eventId = "G5vYZb2n_2V2d";
    const eventSymbol = "ANDY2024";
    const ticketPrice = 100;
    const maxSupply = 200;
    const marketplaceFee = 100; // 1% fee
    let eventName, eventDateTime, eventLocation, eventDescription;

    // Get signers
    const [organiser] = await ethers.getSigners();

    // Deploy FestivalToken first
    const FestivalToken = await hre.ethers.getContractFactory("FestivalToken");
    const festivalToken = await FestivalToken.deploy(ethers.parseEther("0.001")); // 0.001 ETH per token
    await festivalToken.waitForDeployment();
    console.log("FestivalToken deployed to:", await festivalToken.getAddress());

    // Deploy MockOracle
    const MockOracle = await ethers.getContractFactory("MockOracle");
    const oracle = await MockOracle.deploy();
    await oracle.waitForDeployment();
    console.log("MockOracle deployed to:", await oracle.getAddress());

    // Deploy FestivalStatusVoting
    const FestivalStatusVoting = await hre.ethers.getContractFactory("FestivalStatusVoting");
    const votingContract = await FestivalStatusVoting.deploy();
    await votingContract.waitForDeployment();
    console.log("FestivalStatusVoting deployed to:", await votingContract.getAddress());

    // Deploy TicketFactory with required constructor arguments
    const TicketFactory = await ethers.getContractFactory("TicketFactory");
    const ticketFactory = await TicketFactory.deploy(
        await festivalToken.getAddress(),
        await votingContract.getAddress(),
        await oracle.getAddress()
    );
    await ticketFactory.waitForDeployment();
    console.log("TicketFactory deployed to:", await ticketFactory.getAddress());
    
    // Get event details from oracle
    const oracleData = await oracle.getEventData(eventId);
    eventName = oracleData[1];
    eventDateTime = oracleData[2];
    eventLocation = oracleData[3];
    eventDescription = oracleData[4];

    // Deploy TicketNFT with required constructor arguments
    const TicketNFT = await ethers.getContractFactory("TicketNFT");
    const ticketNFT = await TicketNFT.deploy(
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
    console.log("TicketNFT deployed to:", await ticketNFT.getAddress());

    // Deploy TicketMarketplace with required constructor arguments
    const TicketMarketplace = await ethers.getContractFactory("TicketMarketplace");
    const marketplace = await TicketMarketplace.deploy(
        await festivalToken.getAddress(),
        await ticketNFT.getAddress(),
        organiser.address,
        marketplaceFee
    );
    await marketplace.waitForDeployment();
    console.log("TicketMarketplace deployed to:", await marketplace.getAddress());
}

main().catch((error) => {
    console.error(error);
    process.exitCode = 1;
});
