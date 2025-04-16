const { expect } = require("chai");
const { ethers } = require("hardhat");

describe("FestivalStatusVoting", function () {
    let voting;
    let ticketNFT;
    let festivalToken;
    let organiser, ticketHolder1, ticketHolder2, outsider;

    const now = Math.floor(Date.now() / 1000); // current Unix time
    
    // Test variables
    const eventName = "Testing Event";
    const eventDateTime = now + 3600; // 1 hour in the future
    const eventLocation = "Test Location";
    const eventDescription = "Test Description";
    const eventId = "G5vYZb2n_2V2d";
    const eventSymbol = "ANDY2024";
    const ticketPrice = 2;
    const maxSupply = 100;

    before(async function () {
        [owner, organiser, ticketHolder1, ticketHolder2, outsider] = await ethers.getSigners();

        // Deploy dummy FestivalToken
        const FestivalTokenContract = await ethers.getContractFactory("FestivalToken");
        festivalToken = await FestivalTokenContract.deploy(ethers.parseEther("0.1"));
        await festivalToken.waitForDeployment();

        await festivalToken.connect(ticketHolder1).getCredit({ value: ethers.parseEther("10") });
        await festivalToken.connect(ticketHolder2).getCredit({ value: ethers.parseEther("5") });

        // Deploy Voting contract
        VotingContract = await ethers.getContractFactory("FestivalStatusVoting");
        voting = await VotingContract.deploy();
        await voting.waitForDeployment();

        // Deploy TicketNFT with testing data
        const TicketNFTContract = await ethers.getContractFactory("TicketNFT");
        ticketNFT = await TicketNFTContract.deploy(
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
            await voting.getAddress()
        );
        await ticketNFT.waitForDeployment();

        // Mint tickets to ticket holders
        await ticketNFT.connect(organiser).bulkMintTickets(10, organiser.address);

        await ticketNFT.connect(ticketHolder1).buyTickets(1)
        await ticketNFT.connect(ticketHolder2).buyTickets(2);
    });

    describe('Voting Creation', function () {
        const votingEndTime = Number(eventDateTime) + 86400; // Convert to number and add 1 day
        it('Should allow the creation of a voting session', async function () {
            await expect(
                voting.connect(organiser).createVoting(eventId, eventDateTime, votingEndTime, await ticketNFT.getAddress())
              ).to.not.be.reverted;
                          const votingDetails = await voting.getVotingDetail(eventId);
            expect(votingDetails.startDateTime).to.equal(eventDateTime);
            expect(votingDetails.endDateTime).to.equal(votingEndTime);
            expect(votingDetails.ticketNFTAddress).to.equal(await ticketNFT.getAddress());
        })

        it('Should revert if start time is in the past', async function () {
            const pastStartTime = Math.floor(Date.now() / 1000) - 3600; // 1 hour in the past
            await expect(voting.connect(organiser).createVoting(eventId, pastStartTime, eventDateTime, await ticketNFT.getAddress())).to.be.revertedWith("Start date time must be in the future");
        });

        it('Should revert if end time is before start time', async function () {
            const pastEndTime = eventDateTime - 3600; // 1 hour before start time
            await expect(voting.connect(organiser).createVoting(eventId, eventDateTime, pastEndTime, await ticketNFT.getAddress())).to.be.revertedWith("End date time must be after start date time");
        });

        it('Should revert if voting already exists', async function () {
            await expect(voting.connect(organiser).createVoting(eventId, eventDateTime, votingEndTime, await ticketNFT.getAddress())).to.be.revertedWith("Voting already exists for this event");
        });
    })

    // Fast-forward time by 1 hour
    describe('Voting', function () {
        it('Should not allow voting and voting from for non-existent event', async function () {
            // As eventId is always an uuid, we can use a random string for testing non-existent event
            await expect(voting.connect(ticketHolder1).vote("nonExistentEvent", true)).to.be.revertedWith("Voting does not exist");
        });

        it('Should not allow voting before start time', async function () {
            await expect(voting.connect(ticketHolder1).vote(eventId, true)).to.be.revertedWith("Voting not started");
        })

        it('Should allow ticket holders to vote between start time and end time', async function () {
            await network.provider.send("evm_setNextBlockTimestamp", [eventDateTime + 7200]); // fast forward 2 hours
            await network.provider.send("evm_mine");

            expect(await voting.connect(ticketHolder1).vote(eventId, false)).to.not.be.reverted;
            const votingDetails = await voting.getVotingDetail(eventId);
            expect(votingDetails.noVotes).to.equal(1);
        });

        it('Should not allow non-ticket holders to vote', async function () {
            await expect(voting.connect(outsider).vote(eventId, false)).to.be.revertedWith("Voter is not a ticket holder");
        });

        it('Should not allow double voting', async function () {
            await expect(voting.connect(ticketHolder1).vote(eventId, true)).to.be.revertedWith("Already voted");
        });

        // it('Should not allow voting after end time', async function () {
        //     await network.provider.send("evm_setNextBlockTimestamp", [eventDateTime + 86400]); // set time to end time
        //     await network.provider.send("evm_mine");

        //     await expect(voting.connect(ticketHolder1).vote(eventId, true)).to.be.revertedWith("Voting closed");
        // });
    })

    describe('Voting getter', function () {
        it('Should allow ticket holders to check their voting status', async function () {
            const votingDetails = await voting.getVotingDetail(eventId);
            const [noVotes, yesVotes, startDateTime, endDateTime, ticketNFTAddress, eventCancelStatus] = votingDetails;
            expect(noVotes).to.equal(1);
            expect(yesVotes).to.equal(0);
        });
    })

    describe('Refunding', function () {
        it('Should refund to ticket holders if event is cancelled (noVotes >= REFUND_THRESHOLD)', async function () {
            expect(await festivalToken.connect(ticketHolder1).checkCredit()).to.equal(98); // initial credit
            expect(await festivalToken.connect(ticketHolder2).checkCredit()).to.equal(46); // initial credit
            expect(await voting.connect(ticketHolder2).vote(eventId, false)).to.emit(voting, 'Refund').withArgs(eventId); // 2 out of 2 votes for cancellation
            expect(await festivalToken.connect(ticketHolder1).checkCredit()).to.equal(100); // initial credit
            expect(await festivalToken.connect(ticketHolder2).checkCredit()).to.equal(50); // initial credit
            const [, , , , , eventCancelStatus] = await voting.getVotingDetail(eventId);
            expect(eventCancelStatus).to.equal(true); // event is cancelled
        })
    })
    
});
