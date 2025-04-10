// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "./FestivalNFT.sol";
import "./FestivalMarketplace.sol";
import "./FestToken.sol";  // Ensure this import exists for the token

contract FestiveTicketsFactory is Ownable {
    struct Festival {
        string festName;
        string festSymbol;
        uint256 ticketPrice;
        uint256 totalSupply;
        address marketplace;
    }

    address[] private activeFests;
    mapping(address => Festival) private activeFestsMapping;

    event Created(address indexed nftAddress, address indexed marketplaceAddress);

    // Constructor initializes the Ownable contract with msg.sender as the owner
    constructor() Ownable(msg.sender) {
        transferOwnership(msg.sender); // Explicitly set the deployer as the owner
    }

    // Creates new NFT and a marketplace for its purchase
    function createNewFest(
        FestToken token,
        string memory festName,
        string memory festSymbol,
        uint256 ticketPrice,
        uint256 totalSupply
    ) public onlyOwner returns (address) {
        // Create a new FestivalNFT contract instance
        FestivalNFT newFest = new FestivalNFT(
            festName,
            festSymbol,
            ticketPrice,
            totalSupply,
            msg.sender
        );

        // Create a new FestivalMarketplace contract instance
        FestivalMarketplace newMarketplace = new FestivalMarketplace(token, newFest);

        address newFestAddress = address(newFest);

        // Store the created festival and marketplace details
        activeFests.push(newFestAddress);
        activeFestsMapping[newFestAddress] = Festival({
            festName: festName,
            festSymbol: festSymbol,
            ticketPrice: ticketPrice,
            totalSupply: totalSupply,
            marketplace: address(newMarketplace)
        });

        // Emit an event indicating a new festival has been created
        emit Created(newFestAddress, address(newMarketplace));

        return newFestAddress;
    }

    // Get all active fests
    function getActiveFests() public view returns (address[] memory) {
        return activeFests;
    }

    // Get fest's details
    function getFestDetails(address festAddress)
        public
        view
        returns (
            string memory,
            string memory,
            uint256,
            uint256,
            address
        )
    {
        Festival memory fest = activeFestsMapping[festAddress];
        return (
            fest.festName,
            fest.festSymbol,
            fest.ticketPrice,
            fest.totalSupply,
            fest.marketplace
        );
    }
}
