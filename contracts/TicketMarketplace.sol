// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
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
        address seller;
        bool isActive;
    }

    TicketNFT private ticketNFT;
    address private _organiser;
    uint256 private _marketplaceFee; // Fee percentage (e.g., 1 = 1%)
    
    mapping(uint256 => ListingDetails) private _listings;
    uint256[] private _activeListings;

    event TicketListed(uint256 indexed ticketId, uint256 price, address seller);
    event TicketSold(uint256 indexed ticketId, uint256 price, address seller, address buyer);
    event TicketUnlisted(uint256 indexed ticketId);

    /**
     * @notice Initializes the marketplace with a reference to the ticket NFT contract
     * @param _ticketNFTAddress Address of the TicketNFT contract
     * @param organiser Address of the event organiser who will manage the marketplace
     * @param marketplaceFee Fee percentage charged by the marketplace on sales (1 = 1%)
     */
    constructor(address _ticketNFTAddress, address organiser, uint256 marketplaceFee) {
        ticketNFT = TicketNFT(_ticketNFTAddress);
        _organiser = organiser;
        _marketplaceFee = marketplaceFee;
    }

    /**
     * @notice Lists a ticket for sale on the marketplace
     * @param ticketId ID of the ticket to list
     * @param sellingPrice Price at which to list the ticket (in wei)
     * @dev Price cannot exceed 110% of the original purchase price
     */
    function listTicket(uint256 ticketId, uint256 sellingPrice) external {
        require(ticketNFT.ownerOf(ticketId) == msg.sender, "Not the ticket owner");
        
        // Get original purchase price
        (uint256 purchasePrice, ) = ticketNFT.getTicketDetails(ticketId);
        
        // Check if selling price is within allowed range (110% of purchase price)
        require(
            sellingPrice <= purchasePrice + ((purchasePrice * 110) / 100),
            "Re-selling price exceeds 110%"
        );
        
        // Approve marketplace to transfer the ticket
        ticketNFT.approve(address(this), ticketId);
        
        // Add to listings
        _listings[ticketId] = ListingDetails({
            sellingPrice: sellingPrice,
            seller: msg.sender,
            isActive: true
        });
        
        _activeListings.push(ticketId);
        
        emit TicketListed(ticketId, sellingPrice, msg.sender);
    }
    
    /**
     * @notice Allows a user to purchase a listed ticket
     * @param ticketId ID of the ticket to purchase
     * @dev Requires payment equal to or greater than the listing price
     * A marketplace fee is deducted from the payment before transferring to the seller
     */
    function buyTicket(uint256 ticketId) external payable {
        ListingDetails memory listing = _listings[ticketId];
        
        require(listing.isActive, "Ticket not for sale");
        require(msg.value >= listing.sellingPrice, "Insufficient payment");
        
        address seller = listing.seller;
        uint256 sellingPrice = listing.sellingPrice;
        
        // Calculate marketplace fee
        uint256 fee = (sellingPrice * _marketplaceFee) / 100;
        uint256 sellerAmount = sellingPrice - fee;
        
        // Transfer ticket to buyer
        ticketNFT.transferFrom(seller, msg.sender, ticketId);
        
        // Transfer payment to seller
        payable(seller).transfer(sellerAmount);
        
        // Remove from active listings
        removeFromActiveListings(ticketId);
        
        // Update listing status
        _listings[ticketId].isActive = false;
        
        emit TicketSold(ticketId, sellingPrice, seller, msg.sender);
    }
    
    /**
     * @notice Allows a seller to remove their ticket from sale
     * @param ticketId ID of the ticket to unlist
     * @dev Only the seller of the ticket can unlist it
     */
    function unlistTicket(uint256 ticketId) external {
        require(_listings[ticketId].seller == msg.sender, "Not the seller");
        require(_listings[ticketId].isActive, "Not listed");
        
        // Remove from active listings
        removeFromActiveListings(ticketId);
        
        // Update listing status
        _listings[ticketId].isActive = false;
        
        emit TicketUnlisted(ticketId);
    }
    
    /**
     * @notice Returns all tickets currently listed for sale
     * @return Array of ticket IDs that are actively listed
     */
    function getActiveListings() external view returns (uint256[] memory) {
        return _activeListings;
    }
    
    /**
     * @notice Returns details about a specific ticket listing
     * @param ticketId ID of the ticket to query
     * @return price The selling price of the ticket
     * @return seller The address of the seller
     * @return isActive Whether the listing is currently active
     */
    function getListingDetails(uint256 ticketId) external view returns (uint256 price, address seller, bool isActive) {
        ListingDetails memory listing = _listings[ticketId];
        return (listing.sellingPrice, listing.seller, listing.isActive);
    }
    
    /**
     * @notice Internal function to remove a ticket from the active listings array
     * @param ticketId ID of the ticket to remove
     */
    function removeFromActiveListings(uint256 ticketId) internal {
        for (uint256 i = 0; i < _activeListings.length; i++) {
            if (_activeListings[i] == ticketId) {
                _activeListings[i] = _activeListings[_activeListings.length - 1];
                _activeListings.pop();
                break;
            }
        }
    }
    
    /**
     * @notice Allows the organiser to update the marketplace fee
     * @param newFee New fee percentage (1 = 1%)
     * @dev Fee cannot exceed 10%
     */
    function setMarketplaceFee(uint256 newFee) external {
        require(msg.sender == _organiser, "Only organiser can set fee");
        require(newFee <= 10, "Fee too high"); // Max 10%
        _marketplaceFee = newFee;
    }
    
    /**
     * @notice Allows the organiser to withdraw accumulated marketplace fees
     * @dev Only the organiser can withdraw fees
     */
    function withdrawFees() external {
        require(msg.sender == _organiser, "Only organiser can withdraw fees");
        payable(_organiser).transfer(address(this).balance);
    }
}