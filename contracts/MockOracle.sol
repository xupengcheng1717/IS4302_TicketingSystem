// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract MockOracle {
    struct EventData {
        string eventAddress;
        string eventId;
        string eventName;
        string createTime;
        string updateTime;
    }

    mapping(string => EventData) private events;

    constructor() {
        // Simulate data from database.json
        events["kx3odqFYCSxxlyjPr0Bq"] = EventData({
            eventAddress: "0x400322347ad8fF4c9e899044e3aa335F53fFA42B",
            eventId: "G5vYZb2n_2V2d",
            eventName: "SACRAMENTO KINGS VS. PHOENIX SUNS",
            createTime: "2025-03-29T11:00:00.998204Z",
            updateTime: "2025-03-29T11:00:00.998204Z"
        });
    }

    function getEventData(string memory key) external view returns (
        string memory eventAddress,
        string memory eventId,
        string memory eventName,
        string memory createTime,
        string memory updateTime
    ) {
        EventData memory data = events[key];
        return (
            data.eventAddress,
            data.eventId,
            data.eventName,
            data.createTime,
            data.updateTime
        );
    }
}
