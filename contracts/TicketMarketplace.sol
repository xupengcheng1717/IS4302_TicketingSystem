// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "./FestivalToken.sol";
import "./TicketNFT.sol";

contract TicketMarketplace {
    // Details of a ticket listing
    struct ListingDetails {
        uint256 sellingPrice;
        address seller; // assume tickets can only be sold through marketplace (prevent double selling)
        bool isActive;
    }

    // Contracts
    FestivalToken private festivalToken;
    TicketNFT private ticketNFT;

    // Marketplace details
    address private organiser;
    uint256 private marketplaceFee; // as a percentage of ticket price
    
    // Mapping from ticket ID to listing details
    mapping(uint256 => ListingDetails) private listings;

    event TicketListed(uint256 indexed ticketId, uint256 price, address seller);
    event TicketSold(uint256 indexed ticketId, uint256 price, address seller, address buyer);
    event TicketUnlisted(uint256 indexed ticketId);

    constructor(
        address _festivalTokenAddress,
        address _ticketNFTAddress, 
        address _organiser, 
        uint256 _marketplaceFee
    ) {
        require(_festivalTokenAddress != address(0), "Invalid token contract address");
        festivalToken = FestivalToken(_festivalTokenAddress);

        require(_ticketNFTAddress!= address(0), "Invalid ticket contract address");
        ticketNFT = TicketNFT(_ticketNFTAddress);

        organiser = _organiser;

        require(_marketplaceFee <= 10, "Marketplace fee too high"); // Max 10%
        marketplaceFee = _marketplaceFee;
    }

    // Modifier to check if a ticket is listed for sale
    modifier validListing(uint256 _ticketId) {
        require(listings[_ticketId].isActive, "Ticket not listed for sale");
        _;
    }

    // Lists a ticket for sale on the marketplace
    function listTicket(uint256 _ticketId, uint256 _sellingPrice) external {
        require(ticketNFT.ownerOf(_ticketId) == msg.sender, "Not the ticket owner");
        require(!listings[_ticketId].isActive, "Ticket already listed");
        
        // Get original purchase price
        (uint256 _purchasePrice, ) = ticketNFT.getTicketDetails(_ticketId);
        
        // Check if selling price is within allowed range (110% of purchase price)
        require(
            _sellingPrice <= (_purchasePrice * 110) / 100,
            "Re-selling price exceeds 110%"
        );
        
        // Approve marketplace to transfer the ticket
        ticketNFT.approve(address(this), _ticketId);
        
        // Add to listings
        listings[_ticketId] = ListingDetails({
            sellingPrice: _sellingPrice,
            seller: msg.sender,
            isActive: true
        });
        
        emit TicketListed(_ticketId, _sellingPrice, msg.sender);
    }
    
    // Allows a user to purchase a listed ticket
    function buyTicket(uint256 _ticketId) external validListing(_ticketId) {
        ListingDetails memory listing = listings[_ticketId];
        address _seller = listing.seller;
        uint256 _sellingPrice = listing.sellingPrice;

        // Check if buyer has sufficient tokens
        require(festivalToken.balanceOf(msg.sender) >= _sellingPrice + marketplaceFee, "Insufficient tokens");

        uint256 _fee = (_sellingPrice * marketplaceFee) / 100; // Calculate marketplace fee
        
        // Transfer tokens
        festivalToken.transferFrom(msg.sender, _seller, _sellingPrice);
        festivalToken.transferFrom(msg.sender, organiser, _fee);
        
        // Transfer ticket to buyer
        ticketNFT.transferFrom(_seller, msg.sender, _ticketId);

        // Update customers array in ticketNFT contract
        ticketNFT.updateCustomersArray(_seller, msg.sender);
        
        // Remove listing
        delete listings[_ticketId];
        
        emit TicketSold(_ticketId, _sellingPrice, _seller, msg.sender);
    }
    
    // Allows a seller to remove their ticket from sale
    function unlistTicket(uint256 _ticketId) external validListing(_ticketId) {
        require(listings[_ticketId].seller == msg.sender, "Not the seller");
        
        // Remove listing
        delete listings[_ticketId];
        
        emit TicketUnlisted(_ticketId);
    }
    
    // Returns details about a specific ticket listing
    function getListingDetails(uint256 _ticketId) external view validListing(_ticketId) returns (
        uint256 price, 
        address seller, 
        bool isActive) 
    {
        ListingDetails memory listing = listings[_ticketId];
        return (listing.sellingPrice, listing.seller, listing.isActive);
    }
    
    // Allows the organiser to update the marketplace fee
    function setMarketplaceFee(uint256 _newFee) external {
        require(msg.sender == organiser, "Only organiser can set fee");
        require(_newFee <= 10, "Marketplace fee too high"); // Max 10%
        marketplaceFee = _newFee;
    }

    // Returns marketplace fee
    function getMarketplaceFee() external view returns (uint256) {
        return marketplaceFee;
    }
}