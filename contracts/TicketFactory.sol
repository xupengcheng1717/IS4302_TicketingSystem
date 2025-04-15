// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "./MockOracle.sol"; 
import "./TicketNFT.sol";
import "./FestivalToken.sol";
import "./FestivalStatusVoting.sol";

contract TicketFactory {

    // Contracts
    FestivalToken private festivalToken;
    FestivalStatusVoting private newVotingContract;
    MockOracle private oracle;

    constructor(address _festivalTokenAddress, address _votingContractAddress, address _oracleAddress) {
        oracle = MockOracle(_oracleAddress);

        require(_festivalTokenAddress != address(0), "Invalid voting contract address");
        festivalToken = FestivalToken(_festivalTokenAddress);

        require(_votingContractAddress != address(0), "Invalid voting contract address");
        newVotingContract = FestivalStatusVoting(_votingContractAddress);
    }

    
    // Event structure
    struct Event {
        string eventId; // from oracle
        string eventName; // from oracle
        string eventSymbol;
        uint256 eventDateTime; // from oracle
        string eventLocation; // from oracle
        string eventDescription; // from oracle
        address organiser; // verified address from oracle
        uint256 ticketPrice; 
        uint256 totalSupply;
    }
    
    // Mappings
    mapping(string => Event) public events; // eventId => Event - local database to store the events
    
    // Events // indexed for easier searching
    event EventCreated(
        string indexed eventId,
        string eventName,
        string eventSymbol,
        uint256 eventDateTime,
        string eventLocation,
        string eventDescription,
        address indexed organiser,
        address ticketContractAddress,
        uint256 ticketPrice,
        uint256 totalSupply
    );
    
    
    // Create a new event and NFT ticket contract
    function createEvent(
        string memory _eventId,
        string memory _eventSymbol,
        uint256 _ticketPrice,        
        uint256 _totalSupply
    ) external returns (address) {
        (
            address verifiedAddress,
            string memory eventName,
            uint256 eventDateTime,
            string memory eventLocation,
            string memory eventDescription
        ) = oracle.getEventData(_eventId);

        // uses eventID to see if he is a verified organiser
        require(msg.sender == verifiedAddress, "Not a verified organiser");
        require(bytes(events[_eventId].eventId).length == 0, "Event ID already exists");
        
        // Create new NFT contract for this event's tickets
        TicketNFT newTicketContract = new TicketNFT(
            eventName,  
            _eventSymbol,
            _eventId,
            eventDateTime,
            _ticketPrice,
            _totalSupply,
            verifiedAddress, // Organiser becomes owner
            address(festivalToken), // Pass the festival token address
            address(newVotingContract) // Pass the voting contract address
        );

        // Create new voting contract for this event's status
        newVotingContract.createVoting(_eventId, eventDateTime, eventDateTime + 3 days, address(newTicketContract));
        
        // Store event details
        events[_eventId] = Event({
                eventId: _eventId,
                eventName: eventName,
                eventSymbol: _eventSymbol,
                eventDateTime: eventDateTime,
                eventLocation: eventLocation,
                eventDescription: eventDescription,
                organiser: verifiedAddress,
                ticketPrice: _ticketPrice,
                totalSupply: _totalSupply
            });
        
        emit EventCreated(
                _eventId,
                eventName,
                _eventSymbol,
                eventDateTime,
                eventLocation,
                eventDescription,
                verifiedAddress,
                address(newTicketContract),
                _ticketPrice,
                _totalSupply
        );
        
        return address(newTicketContract);
    }
    
    // Get event details
    function getEventDetails(string memory _eventId) external view returns (
        string memory eventId,
        string memory eventName,
        string memory eventSymbol,
        uint256 eventDateTime,
        string memory eventLocation,
        string memory eventDescription,
        address organiser,
        uint256 ticketPrice,
        uint256 totalSupply
    ) {
        Event storage e = events[_eventId];
        require(bytes(e.eventId).length != 0, "Event ID does not exist");
        return (
            e.eventId,
            e.eventName,
            e.eventSymbol,
            e.eventDateTime,
            e.eventLocation,
            e.eventDescription,
            e.organiser,
            e.ticketPrice,
            e.totalSupply
        );
    }
}
