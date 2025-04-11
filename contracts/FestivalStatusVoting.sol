// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "./TicketNFT.sol";

contract FestivalStatusVoting is Ownable {
    uint256 constant REFUND_THRESHOLD = 50; // 50% of the total number of tickets sold

    struct Voting {
        uint256 noVotes;
        uint256 yesVotes;
        uint256 deadline;
        address ticketNFTAddress; // address of the ticket NFT contract
    }

    mapping(string => Voting) public votings; // mapping of event id to voting
    mapping(string => mapping(address => bool)) public hasVoted;

    event Voted(address voter, string eventId, bool voteChoice);
    event Refund(string eventId);

    constructor() Ownable(msg.sender) {}

    function createVoting(string memory eventId, uint256 votingDeadline, address ticketNFTAddress) external onlyOwner {
        require(votingDeadline > block.timestamp, "Deadline must be in the future");
        require(votings[eventId].deadline == 0, "Voting already exists for this event");
        votings[eventId] = Voting({
            noVotes: 0,
            yesVotes: 0,
            deadline: votingDeadline,
            ticketNFTAddress: ticketNFTAddress
        });
    }

    function vote(string memory eventId, bool voteChoice) external {
        Voting storage voting = votings[eventId];
        require(voting.deadline != 0, "Voting does not exist");
        require(TicketNFT(voting.ticketNFTAddress).isCustomerExist(msg.sender), "Not a ticket holder");
        require(block.timestamp <= voting.deadline, "Voting closed");
        require(!hasVoted[eventId][msg.sender], "Already voted");

        if (voteChoice) {
            voting.yesVotes += 1;
        } else {
            voting.noVotes += 1;
        }
        hasVoted[eventId][msg.sender] = true;
        checkRefund(eventId); // Check if refund is needed after voting

        emit Voted(msg.sender, eventId, voteChoice);
    }
    
    function voteFromTicketNFT(address voter, string memory eventId, bool voteChoice) external {
        Voting storage voting = votings[eventId];
        require(voting.deadline != 0, "Voting does not exist");
        require(msg.sender == voting.ticketNFTAddress, "Only ticket NFT contract can call this function");
        require(TicketNFT(voting.ticketNFTAddress).isCustomerExist(voter), "Voter is not a ticket holder");
        require(block.timestamp <= voting.deadline, "Voting closed");
        require(!hasVoted[eventId][voter], "Voter already voted");

        if (voteChoice) {
            voting.yesVotes += 1;
        } else {
            voting.noVotes += 1;
        }
        hasVoted[eventId][voter] = true;
        checkRefund(eventId); // Check if refund is needed after voting

        emit Voted(voter, eventId, voteChoice);
    }

    function getVotingDetail(string memory eventId) external view returns (Voting memory) {
        return votings[eventId];
    }

    function checkRefund(string memory eventId) internal {
        Voting storage voting = votings[eventId];
        require(voting.deadline != 0, "Voting does not exist");

        uint256 totalNumOfCustomers = TicketNFT(voting.ticketNFTAddress).getCurrentNumberOfCustomers();
        if (totalNumOfCustomers == 0) {
            return;
        }
        uint256 percentageNoVotes = (voting.noVotes * 100) / totalNumOfCustomers;
        if (percentageNoVotes >= REFUND_THRESHOLD) {
            // @ TODO: trigger refund for this event
            emit Refund(eventId);
        }
    }
}
