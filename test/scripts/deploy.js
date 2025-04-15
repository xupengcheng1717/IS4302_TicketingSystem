const hre = require("hardhat");

async function main() {
    // Deploy FestivalToken first
    const FestivalToken = await hre.ethers.getContractFactory("FestivalToken");
    const festivalToken = await FestivalToken.deploy(ethers.parseEther("0.01")); // 0.01 ETH per token
    await festivalToken.waitForDeployment();
    console.log("FestivalToken deployed to:", await festivalToken.getAddress());

    // Deploy FestivalStatusVoting
    const FestivalStatusVoting = await hre.ethers.getContractFactory("FestivalStatusVoting");
    const votingContract = await FestivalStatusVoting.deploy();
    await votingContract.waitForDeployment();
    console.log("FestivalStatusVoting deployed to:", await votingContract.getAddress());

    // Deploy TicketFactory with required constructor arguments
    const TicketFactory = await hre.ethers.getContractFactory("TicketFactory");
    const ticketFactory = await TicketFactory.deploy(
        await festivalToken.getAddress(),
        await votingContract.getAddress()
    );
    await ticketFactory.waitForDeployment();
    console.log("TicketFactory deployed to:", await ticketFactory.getAddress());
}

main().catch((error) => {
    console.error(error);
    process.exitCode = 1;
});
