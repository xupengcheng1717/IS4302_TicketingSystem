// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "./FestivalToken.sol";

interface IVoting {
    function voteFromTicketNFT(
        address voter,
        string memory eventId,
        bool voteChoice
    ) external;

    function getVotingDetail(string memory _eventId) external view returns (
        uint256 noVotes,
        uint256 yesVotes,
        uint256 startDateTime,
        uint256 endDateTime,
        address ticketNFTAddress,
        bool eventCancelStatus
    );
}

contract TicketNFT is AccessControl, ERC721Enumerable {
    // Replaced Counters with simple uint256
    uint256 private ticketId;
    uint256 private saleTicketId;
    
    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");
    bytes32 public constant MARKETPLACE_ROLE = keccak256("MARKETPLACE_ROLE");

    struct TicketDetails {
        uint256 purchasePrice;
        bool isUsed;
    }

    address private organiser;
    string private eventId;
    uint256 private eventDateTime;
    string private eventLocation;
    string private eventDescription;
    string private eventName;
    string private eventSymbol;
    uint256 private ticketPrice;
    uint256 private maxSupply;

    mapping(uint256 => TicketDetails) private ticketDetails;
    address[] private customers;

    FestivalToken private festivalToken;
    IVoting private votingContract;

    /**
     * @notice Initializes the ticket NFT contract with event details and assigns roles
     * @param _eventName The name of the event
     * @param _eventSymbol The symbol for the event's tickets
     * @param _eventId Unique identifier for the event
     * @param _ticketPrice Price of each ticket in wei
     * @param _maxSupply Maximum number of tickets available for the event
     * @param _organiser Address of the event organiser who will have admin and minter roles
     * @param _votingContractAddress Address of the voting contract
     */
    constructor(
        string memory _eventName,
        string memory _eventSymbol,
        string memory _eventId,
        uint256 _eventDateTime,
        string memory _eventLocation,
        string memory _eventDescription,
        uint256 _ticketPrice,
        uint256 _maxSupply,
        address _organiser,
        address _festivalTokenAddress,
        address _votingContractAddress
    ) ERC721(_eventName, _eventSymbol) {
        organiser = _organiser;
        _grantRole(DEFAULT_ADMIN_ROLE, organiser);
        _grantRole(MINTER_ROLE, organiser);

        // Set other variables
        eventId = _eventId;
        eventName = _eventName;
        eventSymbol = _eventSymbol;
        eventDateTime = _eventDateTime;
        eventLocation = _eventLocation;
        eventDescription = _eventDescription;
        ticketPrice = _ticketPrice;
        maxSupply = _maxSupply;
        festivalToken = FestivalToken(_festivalTokenAddress);
        votingContract = IVoting(_votingContractAddress);

        // Grant approval to contract for all organiser's tokens
        _setApprovalForAll(organiser, address(this), true);
    }

    /**
     * @notice Modifier to check if the maximum ticket limit has not been exceeded
     */
    modifier isValidTicketCount() {
        require(ticketId < maxSupply, "Max ticket limit exceeded!");
        _;
    }

    /**
     * @notice Modifier to check if the caller has the minter role
     */
    modifier isMinterRole() {
        require(hasRole(MINTER_ROLE, msg.sender), "Must have minter role");
        _;
    }

    modifier organiserOnly() {
        require(msg.sender == organiser, "Only organiser can call this function");
        _;
    }

    modifier validWithdrawal() {
        require(block.timestamp > eventDateTime, "Event has not occurred yet");

        (, , , uint256 endDateTime, , bool eventCancelStatus) = votingContract.getVotingDetail(eventId);
        require(!eventCancelStatus, "Event is cancelled");
        require(block.timestamp > endDateTime, "Voting has not ended yet");
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
     * @param _operator Address that will receive the minted ticket
     * @return The ID of the newly minted ticket
     * @dev Only callable by addresses with minter role
     */
    function mint(address _operator)
        internal
        virtual
        isMinterRole
        returns (uint256)
    {
        ticketId++;
        uint256 _newTicketId = ticketId;
        _mint(_operator, _newTicketId);

        ticketDetails[_newTicketId] = TicketDetails({
            purchasePrice: ticketPrice,
            isUsed: false
        });

        return _newTicketId;
    }

    /**
     * @notice Mints multiple tickets at once to the specified address
     * @param _numOfTickets Number of tickets to mint
     * @param _operator Address that will receive the minted tickets
     * @dev Only callable by addresses with minter role
     */
    function bulkMintTickets(uint256 _numOfTickets, address _operator)
        public
        virtual
        isValidTicketCount
        isMinterRole
    {
        require(
            ticketCounts() + _numOfTickets <= maxSupply,
            "Exceeds maximum supply"
        );

        for (uint256 i = 0; i < _numOfTickets; i++) {
            mint(_operator);
        }
    }

    /**
     * @notice Override transferFrom to add role-based access control
     * @param _from Current owner of the token
     * @param _to Address to receive the token
     * @param _tokenId ID of the token to transfer
     * @dev Only the token owner, approved addresses, or marketplace can transfer tokens
     */
    function transferFrom(
        address _from,
        address _to,
        uint256 _tokenId
    ) public override(ERC721, IERC721) {
        // Allow transfers if sender is the marketplace, has marketplace role, or is the contract itself
        if (!hasRole(MARKETPLACE_ROLE, msg.sender)) {
            require(
                ownerOf(_tokenId) == msg.sender || 
                getApproved(_tokenId) == msg.sender || 
                isApprovedForAll(_from, msg.sender),
                "ERC721: caller is not token owner or approved"
            );
        }
        
        super.transferFrom(_from, _to, _tokenId);
    }

    /**
     * @notice Allows a user to purchase multiple tickets at once
     * @param _numOfTickets Number of tickets to purchase
     * @return Array of purchased ticket IDs
     * @dev Requires payment equal to or greater than the total ticket price
     */
    function buyTickets(uint256 _numOfTickets) public returns (uint256[] memory) {
        require(saleTicketId + _numOfTickets <= ticketId, "Not enough tickets minted");

        uint256 _totalPrice = ticketPrice * _numOfTickets;
        require(festivalToken.balanceOf(msg.sender) >= _totalPrice, "Insufficient token balance");

        uint256[] memory purchasedTickets = new uint256[](_numOfTickets);

        festivalToken.transferCreditFrom(msg.sender, address(this), _totalPrice);
        
        for (uint256 i = 0; i < _numOfTickets; i++) {
            saleTicketId++;
            require(organiser == ownerOf(saleTicketId), "Only organiser can sell this ticket");
            
            _safeTransfer(organiser, msg.sender, saleTicketId, "");
            purchasedTickets[i] = saleTicketId;
        }

        addCustomer(msg.sender);
        return purchasedTickets;
    }

    /**
     * @notice Returns the price of a ticket
     * @return The ticket price in wei
     */
    function getTicketPrice() public view returns (uint256) {
        return ticketPrice;
    }

    /**
     * @notice Returns the address of the event organiser
     * @return The organiser's address
     */
    function getOrganiser() public view returns (address) {
        return organiser;
    }

    /**
     * @notice Returns the event ID
     * @return The event ID string
     */
    function getEventId() public view returns (string memory) {
        return eventId;
    }

    /**
     * @notice Returns the total number of tickets minted so far
     * @return The count of minted tickets
     */
    function ticketCounts() public view returns (uint256) {
        return ticketId;
    }

    /**
     * @notice Returns the details of a specific ticket
     * @param _ticketId The ID of the ticket to query
     * @return purchasePrice The original purchase price of the ticket
     * @return isUsed Whether the ticket has been used or not
     */
    function getTicketDetails(uint256 _ticketId)
        public
        view
        returns (uint256 purchasePrice, bool isUsed)
    {
        TicketDetails memory t = ticketDetails[_ticketId];
        return (t.purchasePrice, t.isUsed);
    }

    function isCustomerExists(address _customer) public view returns (bool) {
        for (uint256 i = 0; i < customers.length; i++) {
            if (customers[i] == _customer) {
                return true;
            }
        }
        return false;
    }

    function getNumberOfCustomers() public view returns (uint256) {
        return customers.length;
    }
    
    function updateCustomersArray(address seller, address buyer) public {
        require(hasRole(MARKETPLACE_ROLE, msg.sender), "Only marketplace can call this function");
        addCustomer(buyer);
        removeCustomer(seller);
    }

    function addCustomer(address _customer) internal {
        if (!isCustomerExists(_customer)) {
            customers.push(_customer);
        }
    }

    function removeCustomer(address _customer) internal {
        if (balanceOf(_customer) == 0) {
            for (uint256 i = 0; i < customers.length; i++) {
                if (customers[i] == _customer) {
                    customers[i] = customers[customers.length - 1];
                    customers.pop();
                    break;
                }
            }
        }
    }

    /**
     * @notice Scans a ticket NFT and marks it as used, then triggers voting
     * @param _customer Address of the ticket holder
     * @param _ticketId ID of the ticket to scan
     * @return True if the scan was successful
     * @dev Only callable by the organiser
     */
    function scanNFT(address _customer, uint256 _ticketId)
        public
        organiserOnly()
        returns (bool)
    {
        require(
            ownerOf(_ticketId) == _customer,
            "Customer does not hold this ticket"
        );
        require(!ticketDetails[_ticketId].isUsed, "Ticket has already been used");
        
        // Mark ticket as used
        ticketDetails[_ticketId].isUsed = true;
        
        // Trigger voting
        votingContract.voteFromTicketNFT(_customer, eventId, true);
        
        return true;
    }

    function withdrawAllFunds() public organiserOnly() validWithdrawal() {
        uint256 balance = festivalToken.balanceOf(address(this));
        require(balance > 0, "No funds to withdraw");
        festivalToken.transferCredit(organiser, balance);
    }

    function refundAllTickets() public organiserOnly() {
        (, , , , , bool eventCancelStatus) = votingContract.getVotingDetail(eventId);
        require(eventCancelStatus, "Event is not cancelled");

        for (uint256 i = 0; i < customers.length; i++) {
            address customer = customers[i];
            uint256 balance = balanceOf(customer);

            for (uint256 j = 0; j < balance; j++) {
                uint256 tokenId = tokenOfOwnerByIndex(customer, j);
                transferFrom(customer, organiser, tokenId);
                festivalToken.transferCredit(customer, ticketPrice);
            }
        }
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