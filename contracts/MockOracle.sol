// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.0;

contract MockOracle {
    uint256 private venueCapacity;

    //set capacity (only called by tests)
    function setVenueCapacity(uint256 _capacity) external {
        venueCapacity = _capacity;
    }

    // get capacity (used by FestivalTicketFactory)
    function getCapacity() external view returns (uint256) {
        return venueCapacity;
    }
}