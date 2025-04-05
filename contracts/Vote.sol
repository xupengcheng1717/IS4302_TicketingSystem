// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./FestivalToken.sol";

contract VotingModule {
    FestivalToken public token;

    struct Proposal {
        uint256 id;
        string description;
        uint256 voteCount;
        uint256 deadline;
        bool executed;
    }

    uint256 public proposalCounter;
    mapping(uint256 => Proposal) public proposals;
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

    function createProposal(string memory description, uint256 duration) external {
        require(stakedTokens[msg.sender] >= MIN_STAKE, "Stake required to propose");

        proposalCounter++;
        proposals[proposalCounter] = Proposal({
            id: proposalCounter,
            description: description,
            voteCount: 0,
            deadline: block.timestamp + duration,
            executed: false
        });

        emit ProposalCreated(proposalCounter, description, block.timestamp + duration);
    }

    function vote(uint256 proposalId) external {
        Proposal storage prop = proposals[proposalId];
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
