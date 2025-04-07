// SPDX-License-Identifier: MIT
pragma solidity ^0.8.7;

import "@chainlink/contracts/src/v0.8/functions/v1_3_0/FunctionsClient.sol";

contract FestivalTicketFactory is FunctionsClient {
    using FunctionsRequest for FunctionsRequest.Request;

    bytes32 public latestRequestId;
    string public eventData;

    constructor(address oracleAddress) FunctionsClient(oracleAddress) {}

    // Request event data from Chainlink Functions
    // hard-coded the eventID
    function requestEventData(string calldata eventId) external {
        // Initialize the request
        FunctionsRequest.Request memory req;
        req.initializeRequestForInlineJavaScript(
            "const eventId = args[0];"
            "const url = `https://firestore.googleapis.com/v1/projects/is4302-bfa34/databases/(default)/documents/validEvents/${eventId}`;"
            "const apiKey = secrets.apiKey;"
            "const response = await Functions.makeHttpRequest({ url, headers: { 'Authorization': `Bearer ${apiKey}` } });"
            "if (response.error) throw Error('Request failed');"
            "const eventData = response.data.fields;"
            "const address = eventData.address.stringValue;" // Extract the address field
            "return Functions.encodeString(address);" // Return the address as a string
        );

        // Set the arguments for the request
        string[] memory args = new string[](1);
        args[0] = eventId;
        req.setArgs(args);

        // Send the request to the Chainlink Functions oracle
        latestRequestId = _sendRequest(
            req.encodeCBOR(), // Encode the request as CBOR
            123,              // Subscription ID 
            100_000,          // Gas limit for the callback
            bytes32(0)        // DON ID 
        );
    }

    // Callback function called by the oracle with the result
    function _fulfillRequest(bytes32 requestId, bytes memory response, bytes memory err) internal override {
        latestRequestId = requestId;
        if (err.length > 0) {
            // Handle error
            eventData = string(err);
        } else {
            // Handle success
            eventData = string(response);
        }
    }
}