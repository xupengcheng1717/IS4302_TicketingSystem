// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";



contract TicketNFT is AccessControl, ERC721 {
    // Replaced Counters with simple uint256
    uint256 private _ticketIds;
    uint256 private _saleTicketId;

    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");

    struct TicketDetails {
        uint256 purchasePrice;
        uint256 sellingPrice;
        bool forSale;
    }

    address private _organiser;
    address[] private customers;
    uint256[] private ticketsForSale;
    string private _eventId;
    uint256 private _ticketPrice;
    uint256 private _totalSupply;

    mapping(uint256 => TicketDetails) private _ticketDetails;
    mapping(address => uint256[]) private purchasedTickets;

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

    modifier isValidTicketCount() {
        require(_ticketIds < _totalSupply, "Max ticket limit exceeded!");
        _;
    }

    modifier isMinterRole() {
        require(hasRole(MINTER_ROLE, msg.sender), "Must have minter role");
        _;
    }

    modifier isValidSellAmount(uint256 ticketId) {
        uint256 purchasePrice = _ticketDetails[ticketId].purchasePrice;
        uint256 sellingPrice = _ticketDetails[ticketId].sellingPrice;
        require(
            sellingPrice <= purchasePrice + ((purchasePrice * 110) / 100),
            "Re-selling price exceeds 110%"
        );
        _;
    }

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
            sellingPrice: 0,
            forSale: false
        });

        return newTicketId;
    }

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

    function transferTicket(address buyer) public {
        _saleTicketId++;
        uint256 saleTicketId = _saleTicketId;

        require(msg.sender == ownerOf(saleTicketId), "Only owner can transfer");

        transferFrom(msg.sender, buyer, saleTicketId);

        if (!isCustomerExist(buyer)) {
            customers.push(buyer);
        }

        purchasedTickets[buyer].push(saleTicketId);
    }

    function secondaryTransferTicket(address buyer, uint256 saleTicketId)
        public
        isValidSellAmount(saleTicketId)
    {
        address seller = ownerOf(saleTicketId);
        uint256 sellingPrice = _ticketDetails[saleTicketId].sellingPrice;

        transferFrom(seller, buyer, saleTicketId);

        if (!isCustomerExist(buyer)) {
            customers.push(buyer);
        }

        purchasedTickets[buyer].push(saleTicketId);

        removeTicketFromCustomer(seller, saleTicketId);
        removeTicketFromSale(saleTicketId);

        _ticketDetails[saleTicketId] = TicketDetails({
            purchasePrice: sellingPrice,
            sellingPrice: 0,
            forSale: false
        });
    }

    function setSaleDetails(
        uint256 ticketId,
        uint256 sellingPrice,
        address operator
    ) public {
        uint256 purchasePrice = _ticketDetails[ticketId].purchasePrice;

        require(
            sellingPrice <= purchasePrice + ((purchasePrice * 110) / 100),
            "Re-selling price exceeds 110%"
        );

        require(
            !hasRole(MINTER_ROLE, msg.sender),
            "Organiser cannot set resale details"
        );

        _ticketDetails[ticketId].sellingPrice = sellingPrice;
        _ticketDetails[ticketId].forSale = true;

        if (!isSaleTicketAvailable(ticketId)) {
            ticketsForSale.push(ticketId);
        }

        approve(operator, ticketId);
    }

    function getTicketPrice() public view returns (uint256) {
        return _ticketPrice;
    }

    function getOrganiser() public view returns (address) {
        return _organiser;
    }

    function ticketCounts() public view returns (uint256) {
        return _ticketIds;
    }

    function getNextSaleTicketId() public view returns (uint256) {
        return _saleTicketId;
    }

    function getSellingPrice(uint256 ticketId) public view returns (uint256) {
        return _ticketDetails[ticketId].sellingPrice;
    }

    function getTicketsForSale() public view returns (uint256[] memory) {
        return ticketsForSale;
    }

    function getTicketDetails(uint256 ticketId)
        public
        view
        returns (
            uint256 purchasePrice,
            uint256 sellingPrice,
            bool forSale
        )
    {
        TicketDetails memory t = _ticketDetails[ticketId];
        return (t.purchasePrice, t.sellingPrice, t.forSale);
    }

    function getTicketsOfCustomer(address customer)
        public
        view
        returns (uint256[] memory)
    {
        return purchasedTickets[customer];
    }

    function getCurrentNumberOfCustomers()
        public
        view
        returns (uint256)
    {
        return customers.length;
    }

    function isCustomerExist(address buyer) internal view returns (bool) {
        for (uint256 i = 0; i < customers.length; i++) {
            if (customers[i] == buyer) {
                return true;
            }
        }
        return false;
    }

    function isSaleTicketAvailable(uint256 ticketId) internal view returns (bool) {
        for (uint256 i = 0; i < ticketsForSale.length; i++) {
            if (ticketsForSale[i] == ticketId) {
                return true;
            }
        }
        return false;
    }

    function removeTicketFromCustomer(address customer, uint256 ticketId) internal {
        uint256[] storage tickets = purchasedTickets[customer];
        for (uint256 i = 0; i < tickets.length; i++) {
            if (tickets[i] == ticketId) {
                tickets[i] = tickets[tickets.length - 1];
                tickets.pop();
                break;
            }
        }

        // remove customer from customers array if they have no tickets
        if (tickets.length == 0) {
            for (uint256 i = 0; i < customers.length; i++) {
                if (customers[i] == customer) {
                    customers[i] = customers[customers.length - 1];
                    customers.pop();
                    break;
                }
            }
        }
    }

    function removeTicketFromSale(uint256 ticketId) internal {
        for (uint256 i = 0; i < ticketsForSale.length; i++) {
            if (ticketsForSale[i] == ticketId) {
                ticketsForSale[i] = ticketsForSale[ticketsForSale.length - 1];
                ticketsForSale.pop();
                break;
            }
        }
    }

    function supportsInterface(bytes4 interfaceId)
        public
        view
        override(AccessControl, ERC721)
        returns (bool)
    {
        return super.supportsInterface(interfaceId);
    }

}