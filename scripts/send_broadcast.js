const admin = require('firebase-admin');
const path  = require('path');

// ── Load service account ──────────────────────────────────────────────────────
const serviceAccount = require(path.join(__dirname, 'service_account.json'));

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount),
});

const db = admin.firestore();

async function sendBroadcast(title, message, imageUrl = null) {
  const broadcast = {
    title: title || 'Congratulations! 🎉',
    message: message || 'Everything is set up correctly! This is a global notification sent from the admin broadcast system.',
    timestamp: admin.firestore.FieldValue.serverTimestamp(),
    type: 'content',
    imageUrl: imageUrl, 
    isRead: false,
  };

  try {
    const docRef = await db.collection('notifications_broadcast').add(broadcast);
    console.log('✅ Broadcast sent successfully!');
    console.log(`   ID: ${docRef.id}`);
    process.exit(0);
  } catch (error) {
    console.error('❌ Failed to send broadcast:', error);
    process.exit(1);
  }
}

// Support command line arguments: node send_broadcast.js "Title" "Message" "ImgUrl"
const args = process.argv.slice(2);
sendBroadcast(args[0], args[1], args[2]);
