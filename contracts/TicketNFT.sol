// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "./FestivalToken.sol";

// Voting interface to interact with the voting contract
interface IVoting {
    // Cast a yesVote on behalf of ticket holder when ticket is scanned
    function voteFromTicketNFT(
        address voter,
        string memory eventId,
        bool voteChoice
    ) external;

    // Get voting details for a given event
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
    // Counters to track ticket IDs and sale ticket IDs
    uint256 private ticketId;
    uint256 private saleTicketId;
    
    // Roles
    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");
    bytes32 public constant MARKETPLACE_ROLE = keccak256("MARKETPLACE_ROLE");

    // Ticket details structure
    struct TicketDetails {
        uint256 purchasePrice;
        bool isUsed;
    }

    // Event details
    address private organiser;
    string private eventId;
    uint256 private eventDateTime;
    string private eventLocation;
    string private eventDescription;
    string private eventName;
    string private eventSymbol;
    uint256 private ticketPrice;
    uint256 private maxSupply;

    // Mapping to store ticket details and customers
    mapping(uint256 => TicketDetails) private ticketDetails;
    address[] private customers;

    // Contracts
    FestivalToken private festivalToken;
    IVoting private votingContract;

    event TicketPurchased(uint256 indexed ticketId, address buyer);
    event TicketScanned(uint256 indexed ticketId, address customer);

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
        // Only organiser can mint tickets
        organiser = _organiser;
        _grantRole(DEFAULT_ADMIN_ROLE, organiser);
        _grantRole(MINTER_ROLE, organiser);

        // Set event variables
        eventId = _eventId;
        eventName = _eventName;
        eventSymbol = _eventSymbol;
        eventDateTime = _eventDateTime;
        eventLocation = _eventLocation;
        eventDescription = _eventDescription;
        ticketPrice = _ticketPrice;
        maxSupply = _maxSupply;

        require(_festivalTokenAddress != address(0), "Invalid token contract address");
        festivalToken = FestivalToken(_festivalTokenAddress);

        require(_votingContractAddress != address(0), "Invalid voting contract address");
        votingContract = IVoting(_votingContractAddress);

        // Grant approval to contract for all organiser's tickets
        _setApprovalForAll(organiser, address(this), true);
    }

    // Modifier to check if the maximum ticket limit has not been exceeded
    modifier isValidTicketCount() {
        require(ticketId < maxSupply, "Max ticket limit exceeded!");
        _;
    }

    // Modifier to check if the caller has the minter role
    modifier isMinterRole() {
        require(hasRole(MINTER_ROLE, msg.sender), "Must have minter role");
        _;
    }

    // Modifier to check if the caller is the organiser
    modifier organiserOnly() {
        require(msg.sender == organiser, "Only organiser can call this function");
        _;
    }

    // Modifier to check if organiser can withdraw funds (the event has occurred successfully)
    modifier validWithdrawal() {
        require(block.timestamp > eventDateTime, "Event has not occurred yet");

        (, , , uint256 endDateTime, , bool eventCancelStatus) = votingContract.getVotingDetail(eventId);
        require(!eventCancelStatus, "Event is cancelled");
        require(block.timestamp > endDateTime, "Voting has not ended yet");
        _;
    }

    // Grants marketplace role to a specified address
    function setMarketplace(address marketplaceAddress) external {
        require(hasRole(DEFAULT_ADMIN_ROLE, msg.sender), "Must be admin");
        _grantRole(MARKETPLACE_ROLE, marketplaceAddress);
    }

    // Mints a new ticket to the specified address
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

    // Mints multiple tickets at once to the specified address
    function bulkMintTickets(uint256 _numOfTickets, address _operator)
        public
        virtual
        isValidTicketCount
        isMinterRole
    {
        require(ticketCounts() + _numOfTickets <= maxSupply, "Exceeds maximum supply");

        for (uint256 i = 0; i < _numOfTickets; i++) {
            mint(_operator);
        }
    }

    // Override transferFrom to add role-based access control
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

    // Allows a user to purchase multiple tickets at once
    function buyTickets(uint256 _numOfTickets) public returns (uint256[] memory) {
        // Check if there are enough minted tickets
        require(saleTicketId + _numOfTickets <= ticketId, "Not enough tickets minted");

        // Check if the caller has enough tokens to purchase the tickets
        uint256 _totalPrice = ticketPrice * _numOfTickets;
        require(festivalToken.balanceOf(msg.sender) >= _totalPrice, "Insufficient token balance");

        // Array to store purchased ticket IDs
        uint256[] memory purchasedTickets = new uint256[](_numOfTickets);

        // Transfer tokens from the caller to the contract
        festivalToken.transferCreditFrom(msg.sender, address(this), _totalPrice);
        
        // Transfer tickets from the organiser to the caller
        for (uint256 i = 0; i < _numOfTickets; i++) {
            saleTicketId++;
            require(organiser == ownerOf(saleTicketId), "Only organiser can sell this ticket");
            
            _safeTransfer(organiser, msg.sender, saleTicketId, "");
            purchasedTickets[i] = saleTicketId;

            emit TicketPurchased(saleTicketId, msg.sender);
        }

        // Add the customer to the list of customers
        addCustomer(msg.sender);

        return purchasedTickets;
    }

    // Checks if customer is a ticket holder
    function isCustomerExists(address _customer) public view returns (bool) {
        for (uint256 i = 0; i < customers.length; i++) {
            if (customers[i] == _customer) {
                return true;
            }
        }
        return false;
    }

    // Returns number of ticket holders in the system
    function getNumberOfCustomers() public view returns (uint256) {
        return customers.length;
    }
    
    // Updates customers array after a secondary resale transaction in marketplace
    function updateCustomersArray(address seller, address buyer) public {
        require(hasRole(MARKETPLACE_ROLE, msg.sender), "Only marketplace can call this function");
        addCustomer(buyer);
        removeCustomer(seller);
    }

    // Adds a customer to the list of customers
    function addCustomer(address _customer) internal {
        if (!isCustomerExists(_customer)) {
            customers.push(_customer);
        }
    }

    // Removes a customer from the list of customers if customer no longer holds tickets to this event
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

    // Scans a ticket NFT and marks it as used, then triggers voting
    function scanNFT(address _customer, uint256 _ticketId)
        public
        organiserOnly()
        returns (bool)
    {
        require(ownerOf(_ticketId) == _customer, "Customer does not hold this ticket");
        require(!ticketDetails[_ticketId].isUsed, "Ticket has already been used");
        
        // Mark ticket as used
        ticketDetails[_ticketId].isUsed = true;
        
        // Trigger voting
        votingContract.voteFromTicketNFT(_customer, eventId, true);

        emit TicketScanned(_ticketId, _customer);
        
        return true;
    }

    // Allows organiser to withdraw all funds from the contract after event is over
    function withdrawFunds() public organiserOnly() validWithdrawal() {
        uint256 balance = festivalToken.balanceOf(address(this));
        require(balance > 0, "No funds to withdraw");
        festivalToken.transferCredit(organiser, balance);
    }

    // Refunds all tokens to the ticket holders if event is voted as cancelled
    function refundAllTickets() public organiserOnly() {
        (, , , , , bool eventCancelStatus) = votingContract.getVotingDetail(eventId);
        require(eventCancelStatus, "Event is not cancelled");

        for (uint256 i = 0; i < customers.length; i++) {
            address customer = customers[i];
            uint256 balance = balanceOf(customer);

            // Transfer tokens from contract to customer for each ticket bought
            for (uint256 j = 0; j < balance; j++) {
                uint256 tokenId = tokenOfOwnerByIndex(customer, j);
                transferFrom(customer, organiser, tokenId);
                festivalToken.transferCredit(customer, ticketPrice);
            }
        }
    }
    
    // Returns the price of a ticket in tokens
    function getTicketPrice() public view returns (uint256) {
        return ticketPrice;
    }

    // Returns the address of the event organiser
    function getOrganiser() public view returns (address) {
        return organiser;
    }

    // Returns event ID
    function getEventId() public view returns (string memory) {
        return eventId;
    }

    // Returns the total number of tickets minted so far
    function ticketCounts() public view returns (uint256) {
        return ticketId;
    }

    // Returns the details of a specific ticket
    function getTicketDetails(uint256 _ticketId)
        public
        view
        returns (uint256 purchasePrice, bool isUsed)
    {
        TicketDetails memory t = ticketDetails[_ticketId];
        return (t.purchasePrice, t.isUsed);
    }

    // Implements the supportsInterface function from both parent contracts
    function supportsInterface(bytes4 interfaceId)
        public
        view
        override(AccessControl, ERC721Enumerable)
        returns (bool)
    {
        return super.supportsInterface(interfaceId);
    }
}