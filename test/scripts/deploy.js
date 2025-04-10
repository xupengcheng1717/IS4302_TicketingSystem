const hre = require("hardhat");
const YOUR_ORACLE_ADDRESS = 0x447fd5ec2d383091c22b8549cb231a3bad6d3faf;

async function main() {
  const oracleAddress = YOUR_ORACLE_ADDRESS; // Replace with your Sepolia oracle address
  const FestivalTicketFactory = await hre.ethers.getContractFactory(
    "FestivalTicketFactory"
  );
  const festivalTicketFactory = await FestivalTicketFactory.deploy(
    oracleAddress
  );
  await festivalTicketFactory.deployed();
  console.log(
    "FestivalTicketFactory deployed to:",
    festivalTicketFactory.address
  );
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
