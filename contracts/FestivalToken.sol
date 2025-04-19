// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract FestivalToken is ERC20, Ownable {
    uint256 rate;

    event CreditReceived(address indexed recipient, uint256 amount);
    event CreditTransferred(address indexed from, address indexed to, uint256 amount);
    event ETHWithdrawn(address indexed owner, uint256 amount);

    constructor(uint256 _rate) ERC20("TicketCurrency", "TICK") Ownable(msg.sender) {
        require(_rate > 0, "Rate must be positive");
        rate = _rate;
    }

    // Get credit by sending ETH
    function getCredit() public payable returns(uint256) {
        require(msg.value > 0, "Must send ETH to receive tokens");
        uint256 amount = msg.value / rate;
        _mint(msg.sender, amount);
        emit CreditReceived(msg.sender, amount);
        return amount;
    }

    // Check credit balance
    function checkCredit() public view returns(uint256) {
        return balanceOf(msg.sender);
    }

    // Transfer credit to another address
    function transferCredit(address recipient, uint256 amount) public {
        // Balance check is not needed as the transfer function will revert if the balance is insufficient
        require(recipient != address(0), "Invalid recipient address");
        require(balanceOf(msg.sender) >= amount, "Insufficient balance");
        _transfer(msg.sender, recipient, amount);
        emit CreditTransferred(msg.sender, recipient, amount);
    }

    // Transfer credit from one address to another
    function transferCreditFrom(address sender, address recipient, uint256 amount) public {
        require(sender == tx.origin, "Only the original sender can transfer");
        require(recipient != address(0), "Invalid recipient address");
        require(balanceOf(sender) >= amount, "Insufficient balance");
        // Balance check is not needed as the transfer function will revert if the balance is insufficient
        _transfer(sender, recipient, amount);
        emit CreditTransferred(sender, recipient, amount);
    }

    // Withdraw ETH by burning tokens, for token holders
    function withdrawCredit(uint256 amount) public {
        require(balanceOf(msg.sender) >= amount, "Insufficient balance");
        _burn(msg.sender, amount);
        uint256 ethAmount = amount * rate;
        payable(msg.sender).transfer(ethAmount);
        emit ETHWithdrawn(msg.sender, ethAmount);
    }

    // Get the current rate
    function getRate() public view returns(uint256) {
        return rate;
    }

    // Allow the owner to set a new rate
    function setRate(uint256 newRate) external onlyOwner {
        require(newRate > 0, "Rate must be positive");
        rate = newRate;
    }

    // Allow the owner to withdraw ETH from the contract
    function withdrawETH() external onlyOwner {
        uint256 balance = address(this).balance;
        require(balance > 0, "No ETH to withdraw");
        payable(owner()).transfer(balance);
        emit ETHWithdrawn(owner(), balance);
    }

}