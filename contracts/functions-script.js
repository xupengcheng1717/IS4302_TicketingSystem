const eventId = args[0];
const url = `https://firestore.googleapis.com/v1/projects/is4302-bfa34/databases/(default)/documents/validEvents/${eventId}`;
const apiKey = secrets.apiKey;

const response = await Functions.makeHttpRequest({
  url,
  headers: { Authorization: `Bearer ${apiKey}` },
});
if (response.error) throw Error("Request failed");
const eventData = response.data.fields;
const address = eventData.address.stringValue; // Extract the address field
return Functions.encodeString(address); // Return the address as a string
