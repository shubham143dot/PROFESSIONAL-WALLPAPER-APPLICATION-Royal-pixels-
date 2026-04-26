const admin = require('firebase-admin');
const path = require('path');
const sa = require(path.join(__dirname, 'service_account.json'));
admin.initializeApp({ credential: admin.credential.cert(sa) });
const db = admin.firestore();

async function checkHighViewCounts() {
  const snap = await db.collection('wallpapers').where('view_count', '>', 1).get();
  console.log(`Wallpapers with view_count > 1: ${snap.size}`);
  snap.docs.forEach(doc => {
    console.log(`Document ${doc.id} has view_count: ${doc.data().view_count}`);
  });
  process.exit(0);
}
checkHighViewCounts();
