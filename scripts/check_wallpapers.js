const admin = require('firebase-admin');
const path = require('path');
const sa = require(path.join(__dirname, 'service_account.json'));
admin.initializeApp({ credential: admin.credential.cert(sa) });
const db = admin.firestore();

db.collection('wallpapers').get().then(snap => {
  console.log('Total wallpapers:', snap.size);
  snap.docs.forEach(d => {
    const data = d.data();
    console.log(`  [${d.id}] "${data.title}" | premium: ${data.is_premium}`);
  });
  process.exit(0);
}).catch(e => { console.error(e.message); process.exit(1); });
