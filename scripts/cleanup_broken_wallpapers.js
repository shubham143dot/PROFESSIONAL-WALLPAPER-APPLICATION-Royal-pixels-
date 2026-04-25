const admin = require('firebase-admin');
const cloudinary = require('cloudinary').v2;
const path = require('path');

// Initialize Firebase
const sa = require(path.join(__dirname, 'service_account.json'));
if (!admin.apps.length) {
  admin.initializeApp({ credential: admin.credential.cert(sa) });
}
const db = admin.firestore();

// Cloudinary Credentials
const CLOUDS = [
  { name: 'Free', cloud_name: 'dl00rha3n', api_key: '837238164488567', api_secret: 'bdHDsHE2QyXzqt5UNLJMzxrrpu8' },
  { name: 'Premium', cloud_name: 'dmt6y2k6h', api_key: '174456259398661', api_secret: 'OxI0nRoL8RNK7xRJYVQJtX6cEhs' }
];

function normalizeUrl(url) {
  if (!url) return '';
  return url.replace(/\/v\d+\//, '/').split('?')[0];
}

async function cleanup() {
  console.log('--- Cleaning Up Broken Wallpapers ---');

  // 1. Fetch all asset URLs from both Cloudinary accounts
  const cloudUrls = new Set();
  for (const cloud of CLOUDS) {
    cloudinary.config({
        cloud_name: cloud.cloud_name,
        api_key: cloud.api_key,
        api_secret: cloud.api_secret,
        secure: true
    });

    let next_cursor = null;
    try {
      do {
        const res = await cloudinary.api.resources({ max_results: 500, next_cursor });
        res.resources.forEach(r => cloudUrls.add(normalizeUrl(r.secure_url)));
        next_cursor = res.next_cursor;
      } while (next_cursor);
    } catch (err) {
      console.error(`Error listing ${cloud.name}:`, err.message);
    }
  }
  console.log(`Verified ${cloudUrls.size} total valid images in Cloudinary.`);

  // 2. Scan Firestore for broken links
  const snap = await db.collection('wallpapers').get();
  let deletedCount = 0;

  for (const doc of snap.docs) {
    const data = doc.data();
    const norm = normalizeUrl(data.image_url);
    
    if (norm && !cloudUrls.has(norm)) {
      console.log(`🗑️ Deleting broken entry: [${doc.id}] ${data.title || 'untitled'}`);
      await doc.ref.delete();
      deletedCount++;
    }
  }

  console.log(`\nCleanup Finished!`);
  console.log(`- Deleted: ${deletedCount} broken entries.`);
  console.log(`- Remaining: ${snap.size - deletedCount} valid wallpapers.`);
  
  process.exit(0);
}

cleanup().catch(e => {
  console.error(e);
  process.exit(1);
});
