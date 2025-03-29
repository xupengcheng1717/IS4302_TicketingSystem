// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol"; // provides ownership controls (admin-only functions).
//import "@chainlink/contracts/src/v0.8/ChainlinkClient.sol";
import "./MockOracle.sol";
import "./TicketNFT.sol"; // Imports the NFT contract that represents tickets.

// TicketMaster consumer keys: Oir31QFJA45RrJNN7lHX4S8cLqBYYLvC
// TickerMaster consumer secret: 6WzFEqdBIfT2bWyf

// cannot make API calls in blockchains
// instead, we need a decentralized network of chain like oracles
/*
1. Organizer (verified) calls createEvent with:
    Venue ID: "stadium_123"
    Max Tickets: 1000
2. Oracle fetches venue capacity (e.g. 1000) and returns it.
3. Factory validates 1000 <= 1000 → deploys TicketNFT contract.
4. Organizer gains ownership of the new NFT contract and can mint tickets.

TEST:
1. Verify organizer access control.
2. Test venue capacity edge cases (e.g., exact match, over-limit).
3. Simulate oracle failures and retries.
*/

// create mock oracle because we are not fetching from real API. can i do this? 
// or must fetch from real API which needs money
// Need to create another JS file with API/ mock data

// ticketNFT minted. can view the previous price of the ticket from the transaction hash to see how much
// did the buyer buy / sell for
// can check the original issuer if it is the FestivalTicketFactory itself

// mapping eventid -> walletAddress
// need oracle for the eventID 
// eventID will need to be 

contract FestivalTicketFactory is Ownable {
    MockOracle public mockOracle; // reference to MockOracle
    mapping(address => bool) public verifiedOrganisers; // dictionary mapping to store verified organisers
    // only these people can deploy this contract
    event EventCreated(address indexed organizer, address ticketContract); // event to emit after successful event creation
    
    constructor(address _mockOracleAddress) {
        mockOracle = MockOracle(_mockOracleAddress); // casts the address _mockOracleAddress to MockOracle type
    }

    // modifier to restrict verified organisers
    modifier onlyVerifiedOrganiser() {
        require(verifiedOrganisers[msg.sender], "Not Verified");
        _;
    }

    // function to add/ remove verified organizers (admin-only)
    function addOrganiser(address _organiser) external onlyOwner {
        verifiedOrganisers[_organiser] = false;
    }

    function removeOrganiser(address _organiser) external onlyOwner {
        verifiedOrganisers[_organiser] = false;
    }

    // MIGHT NEED A FUNCTION TO USE ORACLE TO CHECK ON THE 

    // Create event function using the Mock Oracle
    function createEvent(string memory, // supposed to be venue_id here if using real ChainLink Oracle
    string memory _eventName, 
    uint256 _maxTickets, // ownself define how many max tickets organisers want to give
    uint256 _eventTimestamp, // need Oracle to fetch the time
    string memory _eventDetailsURI) external onlyVerifiedOrganiser {
        // Fetch venue capacity from MockOracle
        uint256 venueCapacity = mockOracle.getCapacity();
        require(_maxTickets <= venueCapacity, "Exceeds venue capacity");
        require(_eventTimestamp > block.timestamp, "Event in past"); // need to fetch the start and end of sales

        // Deploy TicketNFT contract
        TicketNFT newEvent = new TicketNFT(
            _eventName,
            "FEST",
            _eventTimestamp,
            _eventDetailsURI, // offchain metadata about the event in JSON (optional)
            /*
            {
            "name": "G-Dragon Ubermensch 2025",
            "date": "2025-05-12T18:00:00Z",
            "venue": "Singapore Stadium",
            "description": "Concert by G-Dragon",
            }
            */
            _maxTickets
        );

        // Transfer ownership to organizer
        newEvent.transferOwnership(msg.sender); // ERC721 standard that ensures organizer (not the factory) controls the event's tickets.
        // TicketNFT will handle minting the amount of tickets required
        emit EventCreated(msg.sender, address(newEvent));
    }
}