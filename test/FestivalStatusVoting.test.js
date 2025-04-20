const { expect } = require("chai");
const { ethers } = require("hardhat");

describe("FestivalStatusVoting", function () {
    let voting;
    let ticketNFT1, ticketNFT2, ticketNFT3;
    let festivalToken;
    let organiser, ticketHolder1, ticketHolder2, ticketHolder3, outsider;

    const now = Math.floor(Date.now() / 1000); // current Unix time
    
    // Test variables
    const eventName1 = "Testing Event";
    const eventDateTime1 = now + 3600; // 1 hour in the future
    const eventLocation = "Test Location";
    const eventDescription = "Test Description";
    const eventId1 = "G5vYZb2n_2V2d";
    const eventSymbol1 = "ANDY2024";
    const ticketPrice = 100;
    const maxSupply = 200;
    const eventId2 = "G5vYZb2n_2V2e";
    const eventSymbol2 = "ANDY2025";
    const eventName2 = "Testing Event 2";
    const eventDateTime2 = now + 86400 + 3600; // 1 day and 1 hour in the future
    const eventId3 = "G5vYZb2n_2V2f";
    const eventSymbol3 = "ANDY2026";
    const eventName3 = "Testing Event 3";
    const eventDateTime3 = now + 86400 + 3600; // 1 day and 1 hour in the future

    before(async function () {
        [owner, organiser, ticketHolder1, ticketHolder2, ticketHolder3, outsider] = await ethers.getSigners();

        // Deploy dummy FestivalToken
        const FestivalTokenContract = await ethers.getContractFactory("FestivalToken");
        festivalToken = await FestivalTokenContract.deploy(ethers.parseEther("0.001"));
        await festivalToken.waitForDeployment();

        await festivalToken.connect(ticketHolder1).getCredit({ value: ethers.parseEther("1.0") });
        await festivalToken.connect(ticketHolder2).getCredit({ value: ethers.parseEther("0.5") });
        await festivalToken.connect(ticketHolder3).getCredit({ value: ethers.parseEther("0.5") });
        await festivalToken.connect(outsider).getCredit({ value: ethers.parseEther("0.5") });

        // Deploy Voting contract
        VotingContract = await ethers.getContractFactory("FestivalStatusVoting");
        voting = await VotingContract.deploy();
        await voting.waitForDeployment();

        // Deploy TicketNFT with testing data
        const TicketNFTContract = await ethers.getContractFactory("TicketNFT");
        ticketNFT1 = await TicketNFTContract.deploy(
            eventName1,
            eventSymbol1,
            eventId1,
            eventDateTime1,
            eventLocation,
            eventDescription,
            ticketPrice,
            maxSupply,
            organiser.address,
            await festivalToken.getAddress(),
            await voting.getAddress()
        );
        await ticketNFT1.waitForDeployment();

        ticketNFT2 = await TicketNFTContract.deploy(
            eventName2,
            eventSymbol2,
            eventId2,
            eventDateTime2,
            eventLocation,
            eventDescription,
            ticketPrice,
            maxSupply,
            organiser.address,
            await festivalToken.getAddress(),
            await voting.getAddress()
        );
        await ticketNFT2.waitForDeployment();

        ticketNFT3 = await TicketNFTContract.deploy(
            eventName3,
            eventSymbol3,
            eventId3,
            eventDateTime3,
            eventLocation,
            eventDescription,
            ticketPrice,
            maxSupply,
            organiser.address,
            await festivalToken.getAddress(),
            await voting.getAddress()
        );
        await ticketNFT3.waitForDeployment();

        await ticketNFT1.connect(organiser).bulkMintTickets(10, organiser.address);
        await ticketNFT1.connect(ticketHolder1).buyTickets(1)
        await ticketNFT1.connect(ticketHolder2).buyTickets(1);
        await ticketNFT1.connect(ticketHolder3).buyTickets(1)

        await ticketNFT2.connect(organiser).bulkMintTickets(10, organiser.address);
        await ticketNFT2.connect(ticketHolder1).buyTickets(1)
        await ticketNFT2.connect(ticketHolder2).buyTickets(1);
        await ticketNFT2.connect(ticketHolder3).buyTickets(1)

        await ticketNFT3.connect(organiser).bulkMintTickets(10, organiser.address);
        await ticketNFT3.connect(ticketHolder1).buyTickets(1)
        await ticketNFT3.connect(ticketHolder2).buyTickets(1);
        await ticketNFT3.connect(ticketHolder3).buyTickets(1)
    });

    describe('Voting Creation', function () {
        const votingEndTime1 = Number(eventDateTime1) + 86400; // Convert to number and add 1 day
        const votingEndTime2 = Number(eventDateTime2) + 86400; // Convert to number and add 1 day
        const votingEndTime3 = Number(eventDateTime3) + 86400; // Convert to number and add 1 day
        it('Should revert if start time is in the past', async function () {
            const pastStartTime = Math.floor(Date.now() / 1000) - 3600; // 1 hour in the past
            await expect(voting.connect(organiser).createVoting(eventId1, pastStartTime, eventDateTime1, await ticketNFT1.getAddress())).to.be.revertedWith("Start date time must be in the future");
            await expect(voting.connect(organiser).createVoting(eventId2, pastStartTime, eventDateTime2, await ticketNFT2.getAddress())).to.be.revertedWith("Start date time must be in the future");
            await expect(voting.connect(organiser).createVoting(eventId3, pastStartTime, eventDateTime3, await ticketNFT3.getAddress())).to.be.revertedWith("Start date time must be in the future");
        });

        it('Should revert if end time is before start time', async function () {
            const pastEndTime = eventDateTime1 - 3600; // 1 hour before start time
            await expect(voting.connect(organiser).createVoting(eventId1, eventDateTime1, pastEndTime, await ticketNFT1.getAddress())).to.be.revertedWith("End date time must be after start date time");
            await expect(voting.connect(organiser).createVoting(eventId2, eventDateTime2, pastEndTime, await ticketNFT2.getAddress())).to.be.revertedWith("End date time must be after start date time");
            await expect(voting.connect(organiser).createVoting(eventId3, eventDateTime3, pastEndTime, await ticketNFT3.getAddress())).to.be.revertedWith("End date time must be after start date time");
        });
        
        it('Should allow the creation of a voting session', async function () {
            await expect(
                voting.connect(organiser).createVoting(eventId1, eventDateTime1, votingEndTime1, await ticketNFT1.getAddress())
              ).to.not.be.reverted;
            const votingDetails = await voting.getVotingDetail(eventId1);
            expect(votingDetails.startDateTime).to.equal(eventDateTime1);
            expect(votingDetails.endDateTime).to.equal(votingEndTime1);
            expect(votingDetails.ticketNFTAddress).to.equal(await ticketNFT1.getAddress());

            await expect(
                voting.connect(organiser).createVoting(eventId2, eventDateTime2, votingEndTime2, await ticketNFT2.getAddress())
              ).to.not.be.reverted;
            const votingDetails2 = await voting.getVotingDetail(eventId2);
            expect(votingDetails2.startDateTime).to.equal(eventDateTime2);
            expect(votingDetails2.endDateTime).to.equal(votingEndTime2);
            expect(votingDetails2.ticketNFTAddress).to.equal(await ticketNFT2.getAddress());

            await expect(
                voting.connect(organiser).createVoting(eventId3, eventDateTime3, votingEndTime3, await ticketNFT3.getAddress())
              ).to.not.be.reverted;
            const votingDetails3 = await voting.getVotingDetail(eventId3);
            expect(votingDetails3.startDateTime).to.equal(eventDateTime3);
            expect(votingDetails3.endDateTime).to.equal(votingEndTime3);
            expect(votingDetails3.ticketNFTAddress).to.equal(await ticketNFT3.getAddress());
        })

        it('Should revert if voting already exists', async function () {
            await expect(voting.connect(organiser).createVoting(eventId1, eventDateTime1, votingEndTime1, await ticketNFT1.getAddress())).to.be.revertedWith("Voting already exists for this event");
            await expect(voting.connect(organiser).createVoting(eventId2, eventDateTime2, votingEndTime2, await ticketNFT2.getAddress())).to.be.revertedWith("Voting already exists for this event");
            await expect(voting.connect(organiser).createVoting(eventId3, eventDateTime3, votingEndTime3, await ticketNFT3.getAddress())).to.be.revertedWith("Voting already exists for this event");
        });
    })

    // Fast-forward time by 1 hour
    describe('Voting', function () {
        it('Should not allow voting and voting from for non-existent event', async function () {
            // As eventId is always an uuid, we can use a random string for testing non-existent event
            await expect(voting.connect(ticketHolder1).vote("nonExistentEvent", true)).to.be.revertedWith("Voting does not exist");
        });

        it('Should not allow voting before start time', async function () {
            await expect(voting.connect(ticketHolder1).vote(eventId1, true)).to.be.revertedWith("Voting not started");
            await expect(voting.connect(ticketHolder2).vote(eventId2, true)).to.be.revertedWith("Voting not started");
            await expect(voting.connect(ticketHolder3).vote(eventId3, true)).to.be.revertedWith("Voting not started");
        })

        it('Should allow ticket holders to vote between start time and end time', async function () {
            await network.provider.send("evm_setNextBlockTimestamp", [eventDateTime1 + 7200]); // fast forward 2 hours, at this time only eventId1 is valid
            await network.provider.send("evm_mine");

            expect(await voting.connect(ticketHolder1).vote(eventId1, false)).to.not.be.reverted;
            const votingDetails = await voting.getVotingDetail(eventId1);
            expect(votingDetails.noVotes).to.equal(1);
        });

        it('Should not allow non-ticket holders to vote', async function () {
            await expect(voting.connect(outsider).vote(eventId1, false)).to.be.revertedWith("Voter is not a ticket holder");
        });

        it('Should not allow double voting', async function () {
            await expect(voting.connect(ticketHolder1).vote(eventId1, true)).to.be.revertedWith("Already voted");
        });

        it('Should not allow voting after end time', async function () {
            await network.provider.send("evm_setNextBlockTimestamp", [eventDateTime1 + 86400]); // set time to end time
            await network.provider.send("evm_mine");

            await expect(voting.connect(ticketHolder1).vote(eventId1, true)).to.be.revertedWith("Voting closed");
        });
    })

    describe('Voting getter', function () {
        it('Should allow ticket holders to check voting details', async function () {
            const votingStatus1 = await voting.getVotingDetail(eventId1);
            const [noVotes1, yesVotes1, startDateTime1, endDateTime1, ticketNFTAddress1, eventCancelStatus1] = votingStatus1;
            expect(noVotes1).to.equal(1);
            expect(yesVotes1).to.equal(0);
            expect(startDateTime1).to.equal(eventDateTime1);
            expect(endDateTime1).to.equal(eventDateTime1 + 86400);
            expect(ticketNFTAddress1).to.equal(await ticketNFT1.getAddress());
            expect(eventCancelStatus1).to.equal(false);

            const votingDetails2 = await voting.getVotingDetail(eventId2);
            const [noVotes2, yesVotes2, startDateTime2, endDateTime2, ticketNFTAddress2, eventCancelStatus2] = votingDetails2;
            expect(noVotes2).to.equal(0);
            expect(yesVotes2).to.equal(0);
            expect(startDateTime2).to.equal(eventDateTime2);
            expect(endDateTime2).to.equal(eventDateTime2 + 86400);
            expect(ticketNFTAddress2).to.equal(await ticketNFT2.getAddress());
            expect(eventCancelStatus2).to.equal(false);
        });
    })

    describe('Refunding', function () {
        it('Should refund to ticket holders if event is cancelled (noVotes >= REFUND_THRESHOLD)', async function () {
            await network.provider.send('evm_setNextBlockTimestamp', [eventDateTime2 + 3600]); // fast forward to 1 hour after eventDateTime2 and eventDateTime3
            await network.provider.send('evm_mine');

            expect(await festivalToken.connect(ticketHolder1).checkCredit()).to.equal(700); // initial credit after buying 3 tickets
            expect(await festivalToken.connect(ticketHolder2).checkCredit()).to.equal(200);
            expect(await festivalToken.connect(ticketHolder3).checkCredit()).to.equal(200);
            expect(await voting.connect(ticketHolder1).vote(eventId2, false)).to.not.emit(voting, 'Refund'); // only 1/3 votes for cancellation, no refund
            expect(await voting.connect(ticketHolder2).vote(eventId2, false)).to.emit(voting, 'Refund').withArgs(eventId2); // 2/3 votes for cancellation, SHOULD REFUND
            expect(await festivalToken.connect(ticketHolder1).checkCredit()).to.equal(800); // after refund of 1 ticket of event 2
            expect(await festivalToken.connect(ticketHolder2).checkCredit()).to.equal(300); // after refund of 1 ticket of event 2
            expect(await festivalToken.connect(ticketHolder3).checkCredit()).to.equal(300); // after refund of 1 ticket of event 2
            const [, , , , , eventCancelStatus] = await voting.getVotingDetail(eventId2);
            expect(eventCancelStatus).to.equal(true); // event is cancelled
        })

        it('Should not refund if event is not cancelled (noVotes < REFUND_THRESHOLD)', async function () {
            expect(await voting.connect(ticketHolder1).vote(eventId3, false)).to.not.emit(voting, 'Refund'); // only 1/3 votes for cancellation, no refund
            expect(await voting.connect(ticketHolder2).vote(eventId3, true)).to.not.emit(voting, 'Refund'); // only 1/3 votes for cancellation, no refund
            expect(await voting.connect(ticketHolder3).vote(eventId3, true)).to.not.emit(voting, 'Refund'); // only 1/3 votes for cancellation, no refund
            expect(await festivalToken.connect(ticketHolder1).checkCredit()).to.equal(800);
            expect(await festivalToken.connect(ticketHolder2).checkCredit()).to.equal(300);
            expect(await festivalToken.connect(ticketHolder3).checkCredit()).to.equal(300);
            const [, , , , , eventCancelStatus] = await voting.getVotingDetail(eventId3);
            expect(eventCancelStatus).to.equal(false); // event is not cancelled
        })
    })
    
});
