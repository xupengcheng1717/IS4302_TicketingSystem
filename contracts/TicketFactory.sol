// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@chainlink/contracts/src/v0.8/shared/interfaces/AggregatorV3Interface.sol";
import "./TicketNFT.sol";

contract TicketFactory is Ownable {
    
    // Chainlink Oracle interface
    AggregatorV3Interface internal oracle;

    // Event organiser structure
    struct Organiser {
        address walletAddress;
        bool isVerified;
        string organiserId; // Firebase/Firestore ID
    }
    
    // Event structure
    struct Event {
        string eventId; // From Firebase/Firestore
        address organiser;
        address ticketContract;
        uint256 ticketPrice; // I include this too cause it makes sense for the factory to like "make" the contracts with a fixed price and total supply so can track easier (prevent fraud)
        uint256 totalSupply;
        string ipfsHash; // IPFS details for the event // concert details
        bool isActive; // event status => maybe use voting system to update this status
    }
    
    // Mappings
    mapping(address => Organiser) public organisers; // walletAdress => Organisers
    mapping(string => Event) public events; // eventId => Event
    mapping(address => string[]) public organiserEvents; // organiser => eventIds
    
    // Events
    event OrganiserVerified(address indexed walletAddress, string organiserId);
    event OrganiserRemoved(address indexed walletAddress);
    event EventCreated(
        string indexed eventId, 
        address indexed organiser, 
        address ticketContract,
        uint256 ticketPrice,
        uint256 totalSupply,
        string ipfsHash
    );
    event OracleUpdated(address indexed newOracle);
    
    // Set the Chainlink oracle address // IDK what this does so uw change can change
    function setOracleAddress(address _oracleAddress) external onlyOwner {
        oracle = AggregatorV3Interface(_oracleAddress);
        emit OracleUpdated(_oracleAddress);
    }
    
    // Verify an organiser (onlyOwner - admin function)
    function verifyOrganiser(
        address _walletAddress, 
        string memory _organiserId
    ) external onlyOwner {
        require(!organisers[_walletAddress].isVerified, "Organiser already verified");
        
        organisers[_walletAddress] = Organiser({
            walletAddress: _walletAddress,
            isVerified: true,
            organiserId: _organiserId
        });
        
        emit OrganiserVerified(_walletAddress, _organiserId);
    }
    
    // Remove organiser verification
    function removeOrganiser(address _walletAddress) external onlyOwner {
        require(organisers[_walletAddress].isVerified, "Organiser not verified");
        delete organisers[_walletAddress];
        emit OrganiserRemoved(_walletAddress);
    }
    
    // Create a new event and NFT ticket contract
    function createEvent(
        string memory _eventId,
        string memory _eventName,
        string memory _eventSymbol,
        uint256 memory _ticketPrice,
        uint256 memory _totalSupply,
        string memory _ipfsHash
    ) external returns (address) {
        require(organisers[msg.sender].isVerified, "Not a verified organiser");
        require(bytes(events[_eventId].eventId).length == 0, "Event ID already exists");
        
        // Create new NFT contract for this event's tickets
        TicketNFT newTicketContract = new TicketNFT(
            _eventName,
            _eventSymbol,
            msg.sender // Organiser becomes owner
        );
        
        // Store event details
        events[_eventId] = Event({
            eventId: _eventId,
            organiser: msg.sender,
            ticketContract: address(newTicketContract),
            ticketPrice: _ticketPrice,
            totalSupply: _totalSupply,
            ipfsHash: _ipfsHash,
            isActive: true
        });
        
        // Add to organiser's events list
        organiserEvents[msg.sender].push(_eventId);
        
        emit EventCreated(_eventId, msg.sender, address(newTicketContract),_ticketPrice, _ticketSupply, _ipfsHash);
        
        return address(newTicketContract);
    }
    
    // Get organiser's events
    function getOrganiserEvents(address _organiser) external view returns (string[] memory) {
        return organiserEvents[_organiser];
    }
    
    // Get event details
    function getEventDetails(string memory _eventId) external view returns (
        address organiser,
        address ticketContract,
        uint256 ticketPrice,
        uint256 totalSupply,
        string memory ipfsHash,
        bool isActive
    ) {
        Event storage e = events[_eventId];
        return (e.organiser, e.ticketContract, e.ticketPrice, e.totalSupply, ipfsHash, e.isActive);
    }
    
    // // Fetch data from Chainlink oracle (example)
    // function fetchEventDataFromOracle(string memory _eventId) external view returns (int) {
    //     // This is a simplified example - you'd customise based on your oracle implementation
    //     (
    //         uint80 roundID, 
    //         int answer,
    //         uint startedAt,
    //         uint updatedAt,
    //         uint80 answeredInRound
    //     ) = oracle.latestRoundData();
    //     return answer;
    // }
}
