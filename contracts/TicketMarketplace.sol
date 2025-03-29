// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./TicketFactory.sol";

contract TicketMarketplace {

   TicketFactory ticketFactoryContract;
   uint256 public commissionFee;
   address _owner;
   mapping(uint256 => uint256) listPrice;

   constructor(TicketFactory ticketFactoryAddress, uint256 fee, uint256 organiserAddress)  {
      ticketFactoryContract = ticketFactoryAddress;
      commissionFee = fee;
      _owner = organiserAddress;
   }

   //list a ticket for sale. Price needs to be >0
   function list(uint256 ticketId, uint256 price) public {
      require(price > 0, "Listing price must be greater than 0");
      require(msg.sender == ticketFactoryContract.getTicketOwner(ticketId), "Only ticket owner can list");
      require(!ticketFactoryContract.isTicketUsed(ticketId), "Cannot list used tickets");
      
      // Transfer ticket to marketplace for escrow
      ticketFactoryContract.transferTicket(ticketId, address(this));
      listPrice[ticketId] = price;
   }

   function unlist(uint256 ticketId) public {
      require(listPrice[ticketId] != 0, "Ticket is not listed");
      require(msg.sender == ticketFactoryContract.getPreviousOwner(ticketId), "Only previous owner can unlist");
      
      // Return ticket to original owner
      ticketFactoryContract.transferTicket(ticketId, msg.sender);
      listPrice[ticketId] = 0;
   }

   // get price of ticket
   function checkPrice(uint256 ticketId) public view returns (uint256) {
      return listPrice[ticketId];
   }

   // Buy the ticket at the listed price
   function buy(uint256 ticketId) public payable {
      require(listPrice[ticketId] != 0, "Ticket is not listed"); 
      require(!ticketFactoryContract.isTicketUsed(ticketId), "Cannot buy used tickets");
      require(msg.value >= listPrice[ticketId] + commissionFee, "Insufficient payment");
      
      address payable seller = payable(ticketFactoryContract.getPreviousOwner(ticketId)); // currently uses Ether
      seller.transfer(listPrice[ticketId]); // Transfer price to seller
      
      // Transfer ticket to buyer
      ticketFactoryContract.transferTicket(ticketId, msg.sender);
      
      // Clear listing
      listPrice[ticketId] = 0;
   }

   // Check if a ticket is listed
   function isListed(uint256 ticketId) public view returns (bool) {
      return listPrice[ticketId] > 0;
   }

   function getContractOwner() public view returns(address) {
      return _owner;
   }

   function withdraw() public {
      require(msg.sender == _owner, "Only owner can withdraw");
      payable(msg.sender).transfer(address(this).balance);
   }
}