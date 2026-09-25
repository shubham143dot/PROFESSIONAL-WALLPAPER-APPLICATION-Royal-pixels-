const admin = require('firebase-admin');
const cloudinary = require('cloudinary').v2;
const path = require('path');

// Initialize Firebase
const sa = require(path.join(__dirname, 'service_account.json'));
if (!admin.apps.length) {
  admin.initializeApp({ credential: admin.credential.cert(sa) });
}
const db = admin.firestore();

// Cloudinary Credentials (configured via environment or .env)
const CLOUDS = [
  { name: 'Free', cloud_name: process.env.CLOUDINARY_CLOUD_NAME_FREE || '', api_key: process.env.CLOUDINARY_API_KEY_FREE || '', api_secret: process.env.CLOUDINARY_API_SECRET_FREE || '' },
  { name: 'Premium', cloud_name: process.env.CLOUDINARY_CLOUD_NAME_PREMIUM || '', api_key: process.env.CLOUDINARY_API_KEY_PREMIUM || '', api_secret: process.env.CLOUDINARY_API_SECRET_PREMIUM || '' }
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
