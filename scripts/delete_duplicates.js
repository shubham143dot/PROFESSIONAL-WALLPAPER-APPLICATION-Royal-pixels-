const admin = require('firebase-admin');
const fs = require('fs');
const path = require('path');

const sa = require(path.join(__dirname, 'service_account.json'));

if (!admin.apps.length) {
  admin.initializeApp({ credential: admin.credential.cert(sa) });
}

const db = admin.firestore();

async function cleanDatabase() {
  console.log("Fetching all wallpapers...");
  const snapshot = await db.collection('wallpapers').get();
  const docs = snapshot.docs;
  console.log(`Found ${docs.length} wallpapers in database.`);

  // --- AUTOMATIC BACKUP ---
  const allWallpapers = docs.map(d => ({ id: d.id, ...d.data() }));
  const backupPath = path.join(__dirname, 'wallpapers_before_dedup_backup.json');
  fs.writeFileSync(backupPath, JSON.stringify(allWallpapers, null, 2));
  console.log(`✅ Pre-dedup backup created at ${backupPath}`);
  // -------------------------

  const titleToIds = {};
  const urlToIds = {};
  const idsToDelete = new Set();
  const orphanedIds = [];

  for (const doc of docs) {
    const data = doc.data();
    const id = doc.id;
    const title = (data.title || '').trim().toLowerCase();
    const imageUrl = (data.image_url || '').trim();

    // 1. Identify orphaned/broken documents
    if (!title || !imageUrl || !imageUrl.startsWith('http')) {
      orphanedIds.push(id);
      idsToDelete.add(id);
      continue;
    }

    // 2. Map Titles
    if (!titleToIds[title]) {
      titleToIds[title] = [];
    }
    titleToIds[title].push(id);

    // 3. Map URLs
    if (!urlToIds[imageUrl]) {
      urlToIds[imageUrl] = [];
    }
    urlToIds[imageUrl].push(id);
  }

  // 4. Gather duplicate IDs (Title)
  for (const [title, ids] of Object.entries(titleToIds)) {
    if (ids.length > 1) {
      // Keep the first one found (oldest usually), delete others
      for (let i = 1; i < ids.length; i++) {
        idsToDelete.add(ids[i]);
      }
    }
  }

  // 5. Gather duplicate IDs (URL)
  for (const [url, ids] of Object.entries(urlToIds)) {
    if (ids.length > 1) {
      // Keep the first one found, delete others
      for (let i = 1; i < ids.length; i++) {
        idsToDelete.add(ids[i]);
      }
    }
  }

  if (idsToDelete.size === 0) {
    console.log("No orphaned or duplicate wallpapers found to delete.");
    return;
  }

  console.log(`Found ${orphanedIds.length} orphaned/broken documents.`);
  console.log(`Found ${idsToDelete.size} total documents to delete.`);

  // 6. Delete in batches
  const batchSize = 500;
  const deleteIds = Array.from(idsToDelete);
  
  for (let i = 0; i < deleteIds.length; i += batchSize) {
    const batch = db.batch();
    const chunk = deleteIds.slice(i, i + batchSize);
    
    for (const id of chunk) {
      console.log(`Deleting Firestore Doc ID: ${id}`);
      batch.delete(db.collection('wallpapers').doc(id));
    }
    
    await batch.commit();
  }

  console.log("Database cleanup complete!");
}

cleanDatabase().then(() => process.exit(0)).catch(e => {
  console.error("Error:", e);
  process.exit(1);
});
