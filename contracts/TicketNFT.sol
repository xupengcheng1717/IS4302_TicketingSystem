// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";

contract TicketNFT is AccessControl, ERC721Enumerable {
    // Replaced Counters with simple uint256
    uint256 private _ticketIds;
    
    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");
    bytes32 public constant MARKETPLACE_ROLE = keccak256("MARKETPLACE_ROLE");

    struct TicketDetails {
        uint256 purchasePrice;
        bool isUsed;
    }

    address private _organiser;
    string private _eventId;
    uint256 private _ticketPrice;
    uint256 private _totalSupply;

    mapping(uint256 => TicketDetails) private _ticketDetails;

    /**
     * @notice Initializes the ticket NFT contract with event details and assigns roles
     * @param eventName The name of the event
     * @param eventSymbol The symbol for the event's tickets
     * @param eventId Unique identifier for the event
     * @param ticketPrice Price of each ticket in wei
     * @param totalSupply Maximum number of tickets available for the event
     * @param organiser Address of the event organiser who will have admin and minter roles
     */
    constructor(
        string memory eventName,
        string memory eventSymbol,
        string memory eventId,
        uint256 ticketPrice,
        uint256 totalSupply,
        address organiser
    ) ERC721(eventName, eventSymbol) {
        _grantRole(DEFAULT_ADMIN_ROLE, organiser);
        _grantRole(MINTER_ROLE, organiser);

        _eventId = eventId;
        _ticketPrice = ticketPrice;
        _totalSupply = totalSupply;
        _organiser = organiser;
    }

    /**
     * @notice Modifier to check if the maximum ticket limit has not been exceeded
     */
    modifier isValidTicketCount() {
        require(_ticketIds < _totalSupply, "Max ticket limit exceeded!");
        _;
    }

    /**
     * @notice Modifier to check if the caller has the minter role
     */
    modifier isMinterRole() {
        require(hasRole(MINTER_ROLE, msg.sender), "Must have minter role");
        _;
    }

    /**
     * @notice Grants marketplace role to a specified address
     * @param marketplaceAddress Address of the marketplace contract
     * @dev Only callable by admin
     */
    function setMarketplace(address marketplaceAddress) external {
        require(hasRole(DEFAULT_ADMIN_ROLE, msg.sender), "Must be admin");
        _grantRole(MARKETPLACE_ROLE, marketplaceAddress);
    }

    /**
     * @notice Mints a new ticket to the specified address
     * @param operator Address that will receive the minted ticket
     * @return The ID of the newly minted ticket
     * @dev Only callable by addresses with minter role
     */
    function mint(address operator)
        internal
        virtual
        isMinterRole
        returns (uint256)
    {
        _ticketIds++;
        uint256 newTicketId = _ticketIds;
        _mint(operator, newTicketId);

        _ticketDetails[newTicketId] = TicketDetails({
            purchasePrice: _ticketPrice,
            isUsed: false
        });

        return newTicketId;
    }

    /**
     * @notice Mints multiple tickets at once to the specified address
     * @param numOfTickets Number of tickets to mint
     * @param operator Address that will receive the minted tickets
     * @dev Only callable by addresses with minter role
     */
    function bulkMintTickets(uint256 numOfTickets, address operator)
        public
        virtual
        isValidTicketCount
        isMinterRole
    {
        require(
            ticketCounts() + numOfTickets <= _totalSupply,
            "Exceeds maximum supply"
        );

        for (uint256 i = 0; i < numOfTickets; i++) {
            mint(operator);
        }
    }

    /**
     * @notice Allows a user to purchase a ticket directly from the contract
     * @return The ID of the purchased ticket
     * @dev Requires payment equal to or greater than the ticket price
     */
    function buyTicket() public payable returns (uint256) {
        require(_ticketIds < _totalSupply, "All tickets sold out");
        require(msg.value >= _ticketPrice, "Insufficient payment");
        
        // Mint a new ticket to the buyer
        uint256 newTicketId = mint(msg.sender);
        
        // Transfer payment to organiser
        payable(_organiser).transfer(msg.value);
        
        return newTicketId;
    }

    /**
     * @notice Returns the price of a ticket
     * @return The ticket price in wei
     */
    function getTicketPrice() public view returns (uint256) {
        return _ticketPrice;
    }

    /**
     * @notice Returns the address of the event organiser
     * @return The organiser's address
     */
    function getOrganiser() public view returns (address) {
        return _organiser;
    }

    /**
     * @notice Returns the event ID
     * @return The event ID string
     */
    function getEventId() public view returns (string memory) {
        return _eventId;
    }

    /**
     * @notice Returns the total number of tickets minted so far
     * @return The count of minted tickets
     */
    function ticketCounts() public view returns (uint256) {
        return _ticketIds;
    }

    /**
     * @notice Returns the details of a specific ticket
     * @param ticketId The ID of the ticket to query
     * @return purchasePrice The original purchase price of the ticket
     * @return isUsed Whether the ticket has been used or not
     */
    function getTicketDetails(uint256 ticketId)
        public
        view
        returns (uint256 purchasePrice, bool isUsed)
    {
        TicketDetails memory t = _ticketDetails[ticketId];
        return (t.purchasePrice, t.isUsed);
    }

    /**
     * @notice Implements the supportsInterface function from both parent contracts
     * @param interfaceId The interface identifier to check
     * @return bool True if the interface is supported
     */
    function supportsInterface(bytes4 interfaceId)
        public
        view
        override(AccessControl, ERC721Enumerable)
        returns (bool)
    {
        return super.supportsInterface(interfaceId);
    }
}