const admin = require('firebase-admin');
const path = require('path');

const sa = require(path.join(__dirname, 'service_account.json'));
if (!admin.apps.length) {
  admin.initializeApp({ credential: admin.credential.cert(sa) });
}
const db = admin.firestore();

async function cleanViewCounts() {
  console.log('--- Starting View Count Cleanup (Deduplication) ---');

  const snap = await db.collection('wallpapers').get();
  console.log(`Analyzing ${snap.size} wallpapers...`);

  const batchSize = 500;
  let batch = db.batch();
  let count = 0;
  let resetCount = 0;

  for (const doc of snap.docs) {
    const data = doc.data();
    const currentViews = data.view_count || 0;

    if (currentViews > 1) {
      // Reset to 1 (assuming at least one unique view happened)
      // This "deletes" the duplicates caused by repeated views from the same user
      batch.update(doc.ref, { view_count: 1 });
      resetCount++;
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

  console.log(`\nCleanup complete!`);
  console.log(`Total wallpapers processed: ${count}`);
  console.log(`Wallpapers with views deduplicated (reset to 1): ${resetCount}`);
  process.exit(0);
}

cleanViewCounts().catch(e => {
  console.error('Error during cleanup:', e);
  process.exit(1);
});
