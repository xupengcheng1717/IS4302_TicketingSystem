// represents the JSON data received from external API
const eventDetails = {
  /*
    eventId : { 
        venueId : int
        venueCapacity : int
        // #### eventPrice : float #### Maybe dont do this here, settled by TicketNFT
        ticketSalesStart : _timestamp
        ticketSalesEnd : _timestamp
        }
    */
};

module.exports = {
  getVenueCapacity: (eventId) => {
    return venueDetails[eventId] || null;
  },
};
