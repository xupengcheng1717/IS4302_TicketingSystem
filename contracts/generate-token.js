const admin = require("firebase-admin");
const serviceAccount = require("../contracts/is4302-bfa34-firebase-adminsdk-fbsvc-42c83ac78f.json");

// Initialize the Firebase Admin SDK with the service account credentials
admin.initializeApp({
  credential: admin.credential.cert(serviceAccount),
});

// Generate the Bearer token
admin.credential
  .cert(serviceAccount)
  .getAccessToken()
  .then((accessToken) => {
    console.log("Bearer Token:", accessToken.access_token);
  })
  .catch((error) => {
    console.error("Error generating token:", error);
  });
