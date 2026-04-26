const admin = require('firebase-admin');
const path = require('path');
const sa = require(path.join(__dirname, 'service_account.json'));
admin.initializeApp({ credential: admin.credential.cert(sa) });
const db = admin.firestore();

async function inspectNotifications() {
  const snap = await db.collection('notifications_broadcast').get();
  snap.docs.forEach(doc => {
    console.log(`Notification: ${doc.id}`);
    console.log(JSON.stringify(doc.data(), null, 2));
    console.log('------------------');
  });
  process.exit(0);
}
inspectNotifications();
