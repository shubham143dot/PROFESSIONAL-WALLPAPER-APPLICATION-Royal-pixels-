const admin = require('firebase-admin');
const path = require('path');

const sa = require(path.join(__dirname, 'service_account.json'));
if (!admin.apps.length) {
  admin.initializeApp({ credential: admin.credential.cert(sa) });
}
const db = admin.firestore();

async function fixEmptyIds() {
  console.log('--- Starting ID Field Fix ---');

  const snap = await db.collection('wallpapers').get();
  console.log(`Analyzing ${snap.size} wallpapers...`);

  let fixCount = 0;
  const batchSize = 500;
  let batch = db.batch();
  let count = 0;

  for (const doc of snap.docs) {
    const data = doc.data();
    // If the 'id' field is missing or empty, set it to the document ID
    if (data.id === undefined || data.id === '') {
      batch.update(doc.ref, { id: doc.id });
      fixCount++;
    }

    count++;
    if (count % batchSize === 0) {
      await batch.commit();
      batch = db.batch();
      console.log(`Processed ${count} documents...`);
    }
  }

  if (count % batchSize !== 0) {
    await batch.commit();
  }

  console.log(`\nFix complete!`);
  console.log(`Total wallpapers processed: ${count}`);
  console.log(`Wallpapers with empty ID field fixed: ${fixCount}`);
  process.exit(0);
}

fixEmptyIds().catch(e => {
  console.error('Error during fix:', e);
  process.exit(1);
});
