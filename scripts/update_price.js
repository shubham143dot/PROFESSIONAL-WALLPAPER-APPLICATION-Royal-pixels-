const admin = require('firebase-admin');
const path = require('path');
const sa = require(path.join(__dirname, 'service_account.json'));
admin.initializeApp({ credential: admin.credential.cert(sa) });
const db = admin.firestore();

async function updatePrice() {
  const snap = await db.collection('wallpapers')
    .where('title', '==', 'Lord Krishna')
    .limit(1)
    .get();

  if (snap.empty) {
    console.log('❌ Lord Krishna wallpaper not found.');
    process.exit(1);
  }

  const doc = snap.docs[0];
  await doc.ref.update({ price: 30.0 });
  console.log(`✅ "Lord Krishna" (${doc.id}) price updated to ₹30.`);
  process.exit(0);
}

updatePrice().catch(e => { console.error(e.message); process.exit(1); });
