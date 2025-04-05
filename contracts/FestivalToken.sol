// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract FestivalToken is ERC20 {
    address owner;
    uint256 rate;

    event CreditReceived(address indexed recipient, uint256 amount);
    event CreditTransferred(address indexed from, address indexed to, uint256 amount);

    constructor(uint256 _rate) ERC20("TicketCurrency", "TICK") {
        owner = msg.sender;
        rate = _rate; // Meaning the number of ethers per token
    }

    function getCredit() public payable returns(uint256) {
        uint256 amount = msg.value / (rate * (1 ether));
        _mint(msg.sender, amount);
        emit CreditReceived(msg.sender, amount);
        return amount;
    }

    function checkCredit() public view returns(uint256) {
        return balanceOf(msg.sender);
    }

    function transferCredit(address recipient, uint256 amount) public {
        // Balance check is not needed as the transfer function will revert if the balance is insufficient
        _transfer(msg.sender, recipient, amount);
        emit CreditTransferred(msg.sender, recipient, amount);
    }

    function transferCreditFrom(address sender, address recipient, uint256 amount) public returns (bool) {
        require(sender == tx.origin, "Only the original sender can transfer");
        require(recipient != address(0), "Invalid recipient address");

        _transfer(sender, recipient, amount);
        emit CreditTransferred(sender, recipient, amount);
        return true;
    }
}