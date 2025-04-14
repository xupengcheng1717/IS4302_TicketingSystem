// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import {FunctionsClient} from "@chainlink/contracts/src/v0.8/functions/v1_0_0/FunctionsClient.sol";
import {ConfirmedOwner} from "@chainlink/contracts/src/v0.8/shared/access/ConfirmedOwner.sol";
import {FunctionsRequest} from "@chainlink/contracts/src/v0.8/functions/v1_0_0/libraries/FunctionsRequest.sol";

import "./TicketNFT.sol";
import "./FestivalToken.sol";
import "./FestivalStatusVoting.sol";

contract TicketFactory is FunctionsClient, ConfirmedOwner {
    using FunctionsRequest for FunctionsRequest.Request;

    // State variables to store the last request ID, response, and error
    bytes32 public s_lastRequestId;
    bytes public s_lastResponse;
    bytes public s_lastError;

    // Custom error type
    error UnexpectedRequestID(bytes32 requestId);

    // Router address - Hardcoded for Sepolia
    // Check to get the router address for your supported network https://docs.chain.link/chainlink-functions/supported-networks
    address router = 0xb83E47C2bC239B3bf370bc41e1459A34b41238D0;

    // JavaScript source code
    // Fetch character name from the Star Wars API.
    // Documentation: https://swapi.info/people
    string source =
            "const eventId = args[0];"
            "const url = `https://firestore.googleapis.com/v1/projects/is4302-bfa34/databases/(default)/documents/validEvents/kx3odqFYCSxxlyjPr0Bq`;"
            "const apiKey = secrets.apiKey;"
            "const response = await Functions.makeHttpRequest({ url });"
            "if (response.error) throw Error('Request failed');"
            "const eventData = response.data.fields;"
            "const address = eventData.address.stringValue;" // Extract the address field
            "return Functions.encodeString(address);"; // Return the address as a string

    //Callback gas limit
    uint32 gasLimit = 300000;

    // donID - Hardcoded for Sepolia
    // Check to get the donID for your supported network https://docs.chain.link/chainlink-functions/supported-networks
    bytes32 donID =
        0x66756e2d657468657265756d2d7365706f6c69612d3100000000000000000000;

    // State variable to store the returned character information
    string public fetchedAddress;

    // Contracts
    FestivalToken private festivalToken;
    FestivalStatusVoting private newVotingContract;

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
        string verifiedAddress;
        address organiser;
        uint256 ticketPrice; // I include this too cause it makes sense for the factory to like "make" the contracts with a fixed price and total supply so can track easier (prevent fraud)
        uint256 totalSupply;
        // u can include how you want store the event details here @minghan
        bool isActive; // event status => maybe use voting system to update this status
    }
    
    // Mappings
    mapping(string => Event) public events; // eventId => Event
    mapping(address => string[]) public organiserEvents; // organiser => eventIds
    
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
    event OracleUpdated(address indexed newOracle);
    
     // Event to log responses
    event Response(
        bytes32 indexed requestId,
        string fetchedAddress,
        bytes response,
        bytes err
    );

    /**
     * @notice Initializes the contract with the Chainlink router address and sets the contract owner
     */
    constructor(address _festivalTokenAddress, address _votingContractAddress) FunctionsClient(router) ConfirmedOwner(msg.sender) {
        require(_festivalTokenAddress != address(0), "Invalid voting contract address");
        festivalToken = FestivalToken(_festivalTokenAddress);

        require(_votingContractAddress != address(0), "Invalid voting contract address");
        newVotingContract = FestivalStatusVoting(_votingContractAddress);
    }

    // For oracles
    /**
     * @notice Sends an HTTP request for character information
     * @param subscriptionId The ID for the Chainlink subscription
     * @param args The arguments to pass to the HTTP request
     * @return requestId The ID of the request
     */
    function sendRequest(
        uint64 subscriptionId,
        string[] calldata args
    ) external onlyOwner returns (bytes32 requestId) {
        FunctionsRequest.Request memory req;
        req.initializeRequestForInlineJavaScript(source); // Initialize the request with JS code
        if (args.length > 0) req.setArgs(args); // Set the arguments for the request

        // Send the request and store the request ID
        s_lastRequestId = _sendRequest(
            req.encodeCBOR(),
            subscriptionId,
            gasLimit,
            donID
        );

        return s_lastRequestId;
    }

    /**
     * @notice Callback function for fulfilling a request
     * @param requestId The ID of the request to fulfill
     * @param response The HTTP response data
     * @param err Any errors from the Functions request
     */
    function fulfillRequest(
        bytes32 requestId,
        bytes memory response,
        bytes memory err
    ) internal override {
        if (s_lastRequestId != requestId) {
            revert UnexpectedRequestID(requestId); // Check if request IDs match
        }
        // Update the contract's state variables with the response and any errors
        s_lastResponse = response;
        s_lastError = err;

        if (response.length > 0) {
            try this.tryDecode(response) returns (string memory decodedAddress) {
                fetchedAddress = decodedAddress;
            } catch {
                fetchedAddress = "Decoding failed";
            }
        } else {
            fetchedAddress = "Empty response";
        }

        // Emit an event to log the response
        emit Response(requestId, fetchedAddress, s_lastResponse, s_lastError);
    }
        // External function to safely try decoding
    function tryDecode(bytes memory response) external pure returns (string memory) {
        return abi.decode(response, (string));
    }
    
    
    // Create a new event and NFT ticket contract
    function createEvent(
        string memory _eventId,
        string memory _eventName,
        string memory _eventSymbol,
        string memory _eventLocation,
        string memory _eventDescription,
        string memory _verifiedAddress,
        uint256 _eventDateTime,
        uint256 _ticketPrice,        
        uint256 _totalSupply
    ) external returns (address) {
        require(keccak256(abi.encodePacked(fetchedAddress)) == keccak256(abi.encodePacked(msg.sender)), "Not a verified organiser");
        require(bytes(events[_eventId].eventId).length == 0, "Event ID already exists");
        
        // Create new NFT contract for this event's tickets
        TicketNFT newTicketContract = new TicketNFT(
            _eventName,
            _eventSymbol,
            _eventId,
            _eventDateTime,
            _ticketPrice,
            _totalSupply,
            msg.sender, // Organiser becomes owner
            address(festivalToken), // Pass the festival token address
            address(newVotingContract) // Pass the voting contract address
        );

        // Create new voting contract for this event's status
        newVotingContract.createVoting(_eventId, _eventDateTime, _eventDateTime + 3 days, address(newTicketContract));
        
        // Store event details
        events[_eventId] = Event({
            eventId: _eventId,
            eventName: _eventName,
            eventSymbol: _eventSymbol,
            eventDateTime: _eventDateTime,
            eventLocation: "", // Placeholder for location
            eventDescription: "", // Placeholder for description
            verifiedAddress: "",
            organiser: msg.sender,
            ticketPrice: _ticketPrice,
            totalSupply: _totalSupply,
            isActive: true
        });
        
        // Add to organiser's events list
        organiserEvents[msg.sender].push(_eventId);
        
        emit EventCreated(
            _eventId,
            _eventName,
            _eventSymbol,
            _eventDateTime,
            msg.sender,
            address(newTicketContract),
            _ticketPrice,
            _totalSupply
        );
        
        return address(newTicketContract);
    }
    
    // Get organiser's events
    function getOrganiserEvents(address _organiser) external view returns (string[] memory) {
        return organiserEvents[_organiser];
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
