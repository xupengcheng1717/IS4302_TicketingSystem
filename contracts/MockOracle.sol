// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract MockOracle {
    struct EventData {
        string verifiedAddress;
        string eventId;
        string eventName;
        uint256 eventDateTime;
        string eventLocation;
        string eventDescription;
    }

    mapping(string => EventData) private events;

    constructor() {
        // Simulate data from database.json
        events["kx3odqFYCSxxlyjPr0Bq"] = EventData({
            verifiedAddress: "0x400322347ad8fF4c9e899044e3aa335F53fFA42B",
            eventId: "G5vYZb2n_2V2d",
            eventName: "Today... is the Day",
            eventDateTime: 1746037800,
            eventLocation: "Singapore Indoor Stadium",
            eventDescription: "Andy Lau's 'Today... is the Day' concert tour in Singapore, held at the Singapore Indoor Stadium in October 2024, features a mix of his classic hits and newer songs, accompanied by a grand production with visual effects like mystical beasts and flying dragons. Audiences can expect an immersive experience with state-of-the-art lighting and a performance style that sometimes includes high-stakes stunts on stage. "
        });
    }

    function getEventData(string memory key) external view returns (
        string memory verifiedAddress,
        string memory eventId,
        string memory eventName,
        uint256 eventDateTime,  
        string memory eventLocation,
        string memory eventDescription
    ) {
        EventData memory data = events[key];
        return (
            data.verifiedAddress,
            data.eventId,
            data.eventName,
            data.eventDateTime,
            data.eventLocation,
            data.eventDescription
        );
    }
}
