// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "./TicketNFT.sol";

contract FestivalStatusVoting is Ownable {
    uint256 constant REFUND_THRESHOLD = 51; // 51% of the total number of customers

    struct Voting {
        uint256 noVotes;
        uint256 yesVotes;
        uint256 startDateTime;
        uint256 endDateTime;
        address ticketNFTAddress; // address of the ticket NFT contract
        bool eventCancelStatus;
    }

    mapping(string => Voting) public votings; // mapping of event id to voting
    mapping(string => mapping(address => bool)) public hasVoted;

    event Voted(address voter, string eventId, bool voteChoice);
    event Refund(string eventId);

    constructor() Ownable(msg.sender) {}

    modifier validVoting(string memory _eventId) {
        require(votings[_eventId].startDateTime != 0, "Voting does not exist");
        require(block.timestamp >= votings[_eventId].startDateTime, "Voting not started");
        require(block.timestamp <= votings[_eventId].endDateTime, "Voting closed");
        _;
    }

    modifier validVote(address _voter, string memory _eventId) {
        require(TicketNFT(votings[_eventId].ticketNFTAddress).isCustomerExists(_voter), "Voter is not a ticket holder");
        require(!hasVoted[_eventId][_voter], "Already voted");
        _;
    }

    function createVoting(string memory _eventId, uint256 _startDateTime, uint256 _endDateTime, address _ticketNFTAddress) external {
        require(_startDateTime > block.timestamp, "Start date time must be in the future");
        require(_endDateTime > _startDateTime, "End date time must be after start date time");
        require(votings[_eventId].startDateTime == 0, "Voting already exists for this event");

        votings[_eventId] = Voting({
            noVotes: 0,
            yesVotes: 0,
            startDateTime: _startDateTime,
            endDateTime: _endDateTime,
            ticketNFTAddress: _ticketNFTAddress,
            eventCancelStatus: false
        });
    }

    function vote(string memory _eventId, bool _voteChoice) external validVoting(_eventId) validVote(msg.sender, _eventId) {
        Voting storage voting = votings[_eventId];

        if (_voteChoice) {
            voting.yesVotes += 1;
        } else {
            voting.noVotes += 1;
        }

        hasVoted[_eventId][msg.sender] = true;
        checkRefund(_eventId); // Check if refund is needed after voting

        emit Voted(msg.sender, _eventId, _voteChoice);
    }
    
    function voteFromTicketNFT(address _voter, string memory _eventId, bool _voteChoice) external validVoting(_eventId) validVote(_voter, _eventId) {
        Voting storage voting = votings[_eventId];
        require(msg.sender == voting.ticketNFTAddress, "Only ticket NFT contract can call this function");

        if (_voteChoice) {
            voting.yesVotes += 1;
        } else {
            voting.noVotes += 1;
        }

        hasVoted[_eventId][_voter] = true;
        checkRefund(_eventId); // Check if refund is needed after voting

        emit Voted(_voter, _eventId, _voteChoice);
    }

    function getVotingDetail(string memory _eventId) external view returns (
        uint256 noVotes,
        uint256 yesVotes,
        uint256 startDateTime,
        uint256 endDateTime,
        address ticketNFTAddress,
        bool eventCancelStatus
    ) {
        Voting storage v = votings[_eventId];
        return (v.noVotes, v.yesVotes, v.startDateTime, v.endDateTime, v.ticketNFTAddress, v.eventCancelStatus);
    }

    function checkRefund(string memory _eventId) internal {
        Voting storage voting = votings[_eventId];
        require(voting.startDateTime != 0, "Voting does not exist");

        uint256 totalNumOfCustomers = TicketNFT(voting.ticketNFTAddress).getNumberOfCustomers();
        if (totalNumOfCustomers == 0) {
            return;
        }

        uint256 percentageNoVotes = (voting.noVotes * 100) / totalNumOfCustomers;
        if (percentageNoVotes >= REFUND_THRESHOLD) {
            votings[_eventId].eventCancelStatus = true; // Set eventCancelStatus to true to indicate that the event is canceled

            // Refund all tickets
            TicketNFT(voting.ticketNFTAddress).refundAllTickets();
            votings[_eventId].startDateTime = 0; // Set startDateTime to 0 to indicate that the voting has ended

            emit Refund(_eventId);
        }
    }
}
