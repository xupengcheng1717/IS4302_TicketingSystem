// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./FestivalToken.sol";

contract VotingModule {
    FestivalToken public token;

    struct Proposal {
        string description;
        uint256 voteCount;
        uint256 deadline;
        bool executed;
    }

    mapping(uint256 => Proposal) public proposals; // mapping of event id to proposal
    mapping(address => mapping(uint256 => bool)) public hasVoted;
    mapping(address => uint256) public stakedTokens;

    uint256 public constant MIN_STAKE = 100 * 10 ** 18; // Can be changed

    event ProposalCreated(uint256 id, string description, uint256 deadline);
    event Voted(address voter, uint256 proposalId, uint256 weight);
    event TokensStaked(address user, uint256 amount);
    event TokensUnstaked(address user, uint256 amount);

    constructor(FestivalToken _token) {
        token = _token;
    }

    function stakeTokens(uint256 amount) external {
        require(amount > 0, "Cannot stake 0");
        token.transferFrom(msg.sender, address(this), amount);
        stakedTokens[msg.sender] += amount;
        emit TokensStaked(msg.sender, amount);
    }

    function unstakeTokens(uint256 amount) external {
        require(stakedTokens[msg.sender] >= amount, "Not enough staked");
        stakedTokens[msg.sender] -= amount;
        token.transfer(msg.sender, amount);
        emit TokensUnstaked(msg.sender, amount);
    }

    function createProposal(uint256 eventId, string memory description, uint256 duration) external {
        require(stakedTokens[msg.sender] >= MIN_STAKE, "Stake required to propose");
        Proposal storage existingProposal = proposals[eventId];
        require(existingProposal.deadline == 0, "Proposal already exists"); // existence of proposal can be checked by checking the deadline
        // need to do a check for the status of the event (to be integrate with the factory contract)

        proposals[eventId] = Proposal({
            description: description,
            voteCount: 0,
            deadline: block.timestamp + duration,
            executed: false
        });

        emit ProposalCreated(eventId, description, block.timestamp + duration);
    }

    function vote(uint256 proposalId) external {
        Proposal storage prop = proposals[proposalId];
        require(prop.deadline != 0, "Proposal does not exist");
        require(block.timestamp <= prop.deadline, "Voting closed");
        require(!hasVoted[msg.sender][proposalId], "Already voted");
        require(stakedTokens[msg.sender] > 0, "No staked tokens");

        prop.voteCount += stakedTokens[msg.sender];
        hasVoted[msg.sender][proposalId] = true;

        emit Voted(msg.sender, proposalId, stakedTokens[msg.sender]);
    }

    function getProposal(uint256 id) external view returns (Proposal memory) {
        return proposals[id];
    }
}
