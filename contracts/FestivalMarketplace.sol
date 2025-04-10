// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./FestivalNFT.sol";
import "./FestToken.sol";

contract FestivalMarketplace {
    FestToken private _token;
    FestivalNFT private _festival;

    address private _organiser;

    // Constructor without the 'public' visibility (default is public in Solidity ^0.8.0)
    constructor(FestToken token, FestivalNFT festival) {
        _token = token;
        _festival = festival;
        _organiser = _festival.getOrganiser();
    }

    event Purchase(address indexed buyer, address indexed seller, uint256 ticketId);

    // Purchase tickets from the organiser directly
    function purchaseTicket() public {
        address buyer = msg.sender;

        // Safe transfer using safeTransferFrom method
        _token.transferFrom(buyer, _organiser, _festival.getTicketPrice());

        _festival.transferTicket(buyer);
    }

    // Purchase ticket from the secondary market hosted by organiser
    function secondaryPurchase(uint256 ticketId) public {
        address seller = _festival.ownerOf(ticketId);
        address buyer = msg.sender;
        uint256 sellingPrice = _festival.getSellingPrice(ticketId);
        uint256 commission = (sellingPrice * 10) / 100;

        // Safe transfer using safeTransferFrom method
        _token.transferFrom(buyer, seller, sellingPrice - commission);
        _token.transferFrom(buyer, _organiser, commission);

        // Call the secondary transfer method from FestivalNFT contract
        _festival.secondaryTransferTicket(buyer, ticketId);

        // Emit the purchase event
        emit Purchase(buyer, seller, ticketId);
    }
}
