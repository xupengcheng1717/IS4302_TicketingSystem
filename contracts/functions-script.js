require("dotenv").config(); // Load environment variables

const eventId = args[0];
const url = `https://firestore.googleapis.com/v1/projects/is4302-bfa34/databases/(default)/documents/validEvents/${eventId}`;
const apiKey = process.env.BEARER_TOKEN; // Access the Bearer token from the .env file

const response = await Functions.makeHttpRequest({
  url,
  headers: { Authorization: `Bearer ${apiKey}` },
});
if (response.error) throw Error("Request failed");
const eventData = response.data.fields;
const address = eventData.address.stringValue;
return Functions.encodeString(address);
