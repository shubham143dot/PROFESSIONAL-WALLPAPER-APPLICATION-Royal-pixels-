const admin = require('firebase-admin');
const path = require('path');
const sa = require(path.join(__dirname, 'service_account.json'));
admin.initializeApp({ credential: admin.credential.cert(sa) });
const db = admin.firestore();

async function inspectAppConfig() {
  const snap = await db.collection('app_config').get();
  snap.docs.forEach(doc => {
    console.log(`Config: ${doc.id}`);
    console.log(JSON.stringify(doc.data(), null, 2));
    console.log('------------------');
  });
  process.exit(0);
}
inspectAppConfig();
