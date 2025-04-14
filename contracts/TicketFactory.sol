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

    /**
     * @notice Initializes the contract with the Chainlink router address and sets the contract owner
     */
    constructor(address _festivalTokenAddress, address _votingContractAddress, address _oracleAddress) {
        oracle = MockOracle(_oracleAddress);

        require(_festivalTokenAddress != address(0), "Invalid voting contract address");
        festivalToken = FestivalToken(_festivalTokenAddress);

        require(_votingContractAddress != address(0), "Invalid voting contract address");
        newVotingContract = FestivalStatusVoting(_votingContractAddress);
    }

    // Event organiser structure
    struct Organiser {
        address walletAddress;
        bool isVerified;
        string organiserId; // Firebase/Firestore ID
    }
    
    // Event structure
    struct Event {
        string eventId; // From Firebase/Firestore
        string eventName;
        string eventSymbol;
        uint256 eventDateTime;
        string eventLocation;
        string eventDescription;
        address verifiedAddress;
        address organiser;
        uint256 ticketPrice; // I include this too cause it makes sense for the factory to like "make" the contracts with a fixed price and total supply so can track easier (prevent fraud)
        uint256 totalSupply;
        // u can include how you want store the event details here @minghan
        bool isActive; // event status => maybe use voting system to update this status
    }
    
    // Mappings
    mapping(string => Event) public events; // eventId => Event - local database to store the events
    
    // Events
    event EventCreated(
        string eventId,
        string eventName,
        string eventSymbol,
        uint256 eventDateTime,
        address organiser,
        address ticketContract,
        uint256 ticketPrice,        
        uint256 totalSupply
    );
    
     // Event to log responses
    event Response(
        bytes32 indexed requestId,
        string fetchedAddress,
        bytes response,
        bytes err
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
            msg.sender, // Organiser becomes owner
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
                verifiedAddress: verifiedAddress, // assuming you want to store address as string
                organiser: msg.sender,
                ticketPrice: _ticketPrice,
                totalSupply: _totalSupply,
                isActive: true
            });
        
        emit EventCreated(
                _eventId,
                eventName,
                _eventSymbol,
                eventDateTime,
                msg.sender,
                address(newTicketContract),
                _ticketPrice,
                _totalSupply
        );
        
        return address(newTicketContract);
    }
    
    // Get event details
    function getEventDetails(string memory _eventId) external view returns (
        string memory eventName,
        string memory eventSymbol,
        uint256 eventDateTime,
        address organiser,
        uint256 ticketPrice,
        uint256 totalSupply,
        bool isActive
    ) {
        Event storage e = events[_eventId];
        return (e.eventName, e.eventSymbol, e.eventDateTime, e.organiser, e.ticketPrice, e.totalSupply, e.isActive);
    }
}
