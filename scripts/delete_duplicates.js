const admin = require('firebase-admin');
const path = require('path');
const sa = require(path.join(__dirname, 'service_account.json'));
admin.initializeApp({ credential: admin.credential.cert(sa) });
const db = admin.firestore();

const duplicatesToDelete = [
  "kc31BmI6YdbDjM5thHjq",
  "rFJDg84bfcamX6gT5L8e"
];

async function deleteDuplicates() {
  for (const id of duplicatesToDelete) {
    console.log(`Deleting duplicate wallpaper with ID: ${id}`);
    await db.collection('wallpapers').doc(id).delete();
  }
  console.log("Successfully deleted duplicates!");
}

deleteDuplicates().then(() => process.exit(0)).catch(e => { console.error(e.message); process.exit(1); });
