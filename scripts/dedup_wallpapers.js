/**
 * Dedup cleanup: removes duplicate wallpapers by title, keeping one per title.
 */
const admin = require('firebase-admin');
const path = require('path');
const sa = require(path.join(__dirname, 'service_account.json'));
admin.initializeApp({ credential: admin.credential.cert(sa) });
const db = admin.firestore();

async function dedupWallpapers() {
  const snap = await db.collection('wallpapers').get();
  console.log('Total before dedup:', snap.size);

  // Group by title
  const seen = {};
  const toDelete = [];

  for (const doc of snap.docs) {
    const title = doc.data().title;
    if (seen[title]) {
      toDelete.push(doc.id);
      console.log(`  Duplicate found: "${title}" → will delete ${doc.id}`);
    } else {
      seen[title] = doc.id;
      console.log(`  Keep: "${title}" (${doc.id}) | premium: ${doc.data().is_premium}`);
    }
  }

  if (toDelete.length === 0) {
    console.log('\nNo duplicates found. All good!');
  } else {
    console.log(`\nDeleting ${toDelete.length} duplicate(s)...`);
    const batch = db.batch();
    for (const id of toDelete) {
      batch.delete(db.collection('wallpapers').doc(id));
    }
    await batch.commit();
    console.log('Done. Duplicates removed.');
  }

  // Final count
  const snapAfter = await db.collection('wallpapers').get();
  console.log('Total after dedup:', snapAfter.size);

  process.exit(0);
}

dedupWallpapers().catch(e => { console.error(e.message); process.exit(1); });
