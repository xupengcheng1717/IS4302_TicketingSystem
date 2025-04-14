// server.js
const express = require("express");
const admin = require("firebase-admin");
require("dotenv").config(); // For environment variables

const port = process.env.PORT || 3000; // attempts to read the PORT environment variable in cloud hosting platforms
// if port not defined, default to 3000

// Initialize Firebase Admin SDK
admin.initializeApp({
  credential: admin.credential.cert({
    // Use your Firebase service account key (downloaded from Firebase Console)
    projectId: process.env.FIREBASE_PROJECT_ID,
    privateKey: process.env.FIREBASE_PRIVATE_KEY,
    clientEmail: process.env.FIREBASE_CLIENT_EMAIL,
  }),
  databaseURL: process.env.FIREBASE_DATABASE_URL,
});

// expose API endpoint to get event data
app.get("/api/event/:eventId", async (req, res) => {
  const { eventId } = req.params;

  try {
    // Query Firestore
    const eventDoc = await admin
      .firestore()
      .collection("validEvents")
      .doc(eventId)
      .get();

    if (!eventDoc.exists) {
      return res.status(404).json({ error: "Event not found" });
    }

    // Return event data
    res.json({
      address: eventDoc.data().address,
      event_id: eventDoc.data().event_id,
      name: eventDoc.data().name,
    });
  } catch (error) {
    console.error("Error fetching event:", error);
    res.status(500).json({ error: "Internal server error" });
  }
});

// Start server
app.listen(port, () => {
  console.log(`Server running on port ${port}`);
});
