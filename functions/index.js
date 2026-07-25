const express = require('express');
const cors = require('cors');
const admin = require('firebase-admin');

const serviceAccountJson = process.env.FIREBASE_SERVICE_ACCOUNT || '';
const databaseUrl = process.env.FIREBASE_DATABASE_URL || '';

if (!serviceAccountJson) {
  throw new Error('FIREBASE_SERVICE_ACCOUNT environment variable is required.');
}

if (!databaseUrl) {
  throw new Error('FIREBASE_DATABASE_URL environment variable is required.');
}

let serviceAccount;
try {
  serviceAccount = JSON.parse(serviceAccountJson);
} catch (err) {
  throw new Error('FIREBASE_SERVICE_ACCOUNT must be valid JSON.');
}

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount),
  databaseURL: databaseUrl,
});

const app = express();
app.use(cors());
app.use(express.json());

app.get('/health', (req, res) => {
  res.json({ status: 'ok' });
});

app.post('/notify', async (req, res) => {
  const { senderId, senderName, text, messageId } = req.body;

  if (!senderId || !senderName || !messageId) {
    return res.status(400).json({ error: 'senderId, senderName, and messageId are required.' });
  }

  const notificationBody = text && text.toString().trim().length > 0
    ? text.toString()
    : 'Sent an attachment';

  const message = {
    topic: 'group_chat',
    notification: {
      title: `${senderName} sent a message`,
      body: notificationBody,
    },
    data: {
      senderId,
      messageId,
      type: 'chat',
    },
  };

  try {
    const response = await admin.messaging().send(message);
    return res.json({ success: true, response });
  } catch (error) {
    console.error('FCM send failed:', error);
    return res.status(500).json({ error: 'Failed to send notification.' });
  }
});

const port = process.env.PORT || 10000;
app.listen(port, () => {
  console.log(`Notification backend listening on port ${port}`);
});
