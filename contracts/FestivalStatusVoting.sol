// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";

contract FestivalStatusVoting is Ownable {
    uint256 constant REFUND_THRESHOLD = 50; // 50% of the total number of tickets sold

    struct Voting {
        uint256 noVotes;
        uint256 yesVotes;
        uint256 deadline;
    }

    mapping(uint256 => Voting) public votings; // mapping of event id to voting
    mapping(uint256 => mapping(address => bool)) public hasVoted;

    event Voted(address voter, uint256 eventId, bool voteChoice);
    event Refund(uint256 eventId);

    constructor() Ownable(msg.sender) {}

    function createVoting(uint256 eventId, uint256 eventDeadline) external onlyOwner {
        require(eventDeadline > block.timestamp, "Deadline must be in the future");
        require(votings[eventId].deadline == 0, "Voting already exists for this event");
        votings[eventId] = Voting({
            noVotes: 0,
            yesVotes: 0,
            deadline: eventDeadline
        });
    }

    function vote(uint256 eventId, bool voteChoice) external {
        Voting storage voting = votings[eventId];
        require(voting.deadline != 0, "Voting does not exist");
        require(block.timestamp <= voting.deadline, "Voting closed");
        require(!hasVoted[eventId][msg.sender], "Already voted");

        if (voteChoice) {
            voting.yesVotes += 1;
        } else {
            voting.noVotes += 1;
        }
        hasVoted[eventId][msg.sender] = true;

        emit Voted(msg.sender, eventId, voteChoice);
    }

    function getVotingDetail(uint256 eventId) external view returns (Voting memory) {
        return votings[eventId];
    }

    function checkRefund(uint256 eventId) internal {
        Voting storage voting = votings[eventId];
        require(voting.deadline != 0, "Voting does not exist");

        uint256 totalTickets = 100; // @ TODO: replace with ticket factory' count
        if (totalTickets == 0) {
            return;
        }
        uint256 percentageNoVotes = (voting.noVotes * 100) / totalTickets;
        if (percentageNoVotes >= REFUND_THRESHOLD) {
            // trigger refund for this event
            emit Refund(eventId);
        }
    }
}
