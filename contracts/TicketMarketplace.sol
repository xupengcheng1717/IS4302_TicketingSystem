// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "./FestivalToken.sol";
import "./TicketFactory.sol";
import "./TicketNFT.sol";

/**
 * @title TicketMarketplace
 * @dev A marketplace contract for secondary sales of event tickets
 * Allows users to list, buy, and unlist tickets with price restrictions
 * and marketplace fees
 */
contract TicketMarketplace {
    struct ListingDetails {
        uint256 sellingPrice;
        address seller; // assume tickets can only be sold through marketplace (prevent double selling)
        bool isActive;
    }

    FestivalToken private festivalToken;
    TicketFactory private ticketFactory;
    TicketNFT private ticketNFT;
    address private organiser;
    uint256 private marketplaceFee; // Fee percentage (e.g., 1 = 1%)
    
    mapping(uint256 => ListingDetails) private listings;

    event TicketListed(uint256 indexed ticketId, uint256 price, address seller);
    event TicketSold(uint256 indexed ticketId, uint256 price, address seller, address buyer);
    event TicketUnlisted(uint256 indexed ticketId);

    /**
     * @notice Initializes the marketplace with a reference to the ticket NFT contract
     * @param _ticketNFTAddress Address of the TicketNFT contract
     * @param _organiser Address of the event organiser who will manage the marketplace
     * @param _marketplaceFee Fee percentage charged by the marketplace on sales (1 = 1%)
     */
    constructor(
        address _festivalTokenAddress,
        address _ticketFactoryAddress, 
        address _ticketNFTAddress, 
        address _organiser, 
        uint256 _marketplaceFee
    ) {
        festivalToken = FestivalToken(_festivalTokenAddress);
        ticketFactory = TicketFactory(_ticketFactoryAddress);
        ticketNFT = TicketNFT(_ticketNFTAddress);
        organiser = _organiser;
        marketplaceFee = _marketplaceFee;
    }

    modifier validListing(uint256 _ticketId) {
        require(listings[_ticketId].isActive, "Ticket not listed for sale");
        _;
    }

    /**
     * @notice Lists a ticket for sale on the marketplace
     * @param _ticketId ID of the ticket to list
     * @param _sellingPrice Price at which to list the ticket (in wei)
     * @dev Price cannot exceed 110% of the original purchase price
     */
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
    
    /**
     * @notice Allows a user to purchase a listed ticket
     * @param _ticketId ID of the ticket to purchase
     * @dev Requires payment equal to or greater than the listing price
     * A marketplace fee is deducted from the payment before transferring to the seller
     */
    function buyTicket(uint256 _ticketId) external validListing(_ticketId) {
        ListingDetails memory listing = listings[_ticketId];
        address _seller = listing.seller;
        uint256 _sellingPrice = listing.sellingPrice;

        // Calculate marketplace fee
        uint256 _fee = (_sellingPrice * marketplaceFee) / 100;

        // Check if payment is sufficient
        require(festivalToken.balanceOf(msg.sender) >= _sellingPrice + _fee, "Insufficient payment");

        // Transfer tokens
        festivalToken.transferFrom(msg.sender, _seller, _sellingPrice);
        festivalToken.transferFrom(msg.sender, organiser, _fee);
        
        // Transfer ticket to buyer
        ticketNFT.transferFrom(_seller, msg.sender, _ticketId);
        ticketNFT.updateCustomersArray(_seller, msg.sender);
        
        // Remove listing
        delete listings[_ticketId];
        
        emit TicketSold(_ticketId, _sellingPrice, _seller, msg.sender);
    }
    
    /**
     * @notice Allows a seller to remove their ticket from sale
     * @param _ticketId ID of the ticket to unlist
     * @dev Only the seller of the ticket can unlist it
     */
    function unlistTicket(uint256 _ticketId) external validListing(_ticketId) {
        require(listings[_ticketId].seller == msg.sender, "Not the seller");
        
        // Remove listing
        delete listings[_ticketId];
        
        emit TicketUnlisted(_ticketId);
    }
    
    /**
     * @notice Returns details about a specific ticket listing
     * @param _ticketId ID of the ticket to query
     * @return price The selling price of the ticket
     * @return seller The address of the seller
     * @return isActive Whether the listing is currently active
     */
    function getListingDetails(uint256 _ticketId) external view validListing(_ticketId) returns (
        uint256 price, 
        address seller, 
        bool isActive) 
    {
        ListingDetails memory listing = listings[_ticketId];
        return (listing.sellingPrice, listing.seller, listing.isActive);
    }
    
    /**
     * @notice Allows the organiser to update the marketplace fee
     * @param _newFee New fee percentage (1 = 1%)
     * @dev Fee cannot exceed 10%
     */
    function setMarketplaceFee(uint256 _newFee) external {
        require(msg.sender == organiser, "Only organiser can set fee");
        require(_newFee <= 10, "Fee too high"); // Max 10%
        marketplaceFee = _newFee;
    }
}