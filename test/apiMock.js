// represents the JSON data received from external API
const eventDetails = {
  /*
    eventId : { 
        venueId : 
        venueCapacity : int
        // #### eventPrice : float #### Maybe dont do this here, settled by TicketNFT
        ticketSalesStart : _timestamp
        ticketSalesEnd : _timestamp
        }
    */

  1: {
    venueId: "stadium_123",
    venueCapacity: 1000,
    ticketSalesStart: "2016-03-18T14:00:00Z", // written in the ISO8601 standard format
    ticketSalesEnd: "2016-07-27T21:30:00Z",
  },
};

module.exports = {
  getVenueCapacity: (eventId) => {
    return eventDetails[eventId]["venueCapacity"] || null;
  },
};
