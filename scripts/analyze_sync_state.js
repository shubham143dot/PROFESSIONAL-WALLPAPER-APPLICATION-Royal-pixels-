const admin = require('firebase-admin');
const cloudinary = require('cloudinary').v2;
const path = require('path');
const fs = require('fs');

const sa = require(path.join(__dirname, 'service_account.json'));
if (!admin.apps.length) {
  admin.initializeApp({ credential: admin.credential.cert(sa) });
}
const db = admin.firestore();

// Cloudinary Credentials (configured via environment or .env)
const CLOUDS = [
  {
    name: 'Free',
    cloud_name: process.env.CLOUDINARY_CLOUD_NAME_FREE || 'dl00rha3n',
    api_key: process.env.CLOUDINARY_API_KEY_FREE || '837238164488567',
    api_secret: process.env.CLOUDINARY_API_SECRET_FREE || 'YOUR_FREE_API_SECRET'
  },
  {
    name: 'Premium',
    cloud_name: process.env.CLOUDINARY_CLOUD_NAME_PREMIUM || 'dmt6y2k6h',
    api_key: process.env.CLOUDINARY_API_KEY_PREMIUM || '174456259398661',
    api_secret: process.env.CLOUDINARY_API_SECRET_PREMIUM || 'YOUR_PREMIUM_API_SECRET'
  }
];

function normalizeUrl(url) {
  if (!url) return '';
  return url.replace(/\/v\d+\//, '/').split('?')[0];
}

async function analyze() {
  console.log('--- Analyzing Firestore vs Cloudinary ---');

  // 1. Get Firestore Wallpapers
  const snap = await db.collection('wallpapers').get();
  const firestoreWallpapers = [];
  const firestoreUrls = new Set();
  
  snap.docs.forEach(doc => {
    const data = doc.data();
    firestoreWallpapers.push({ id: doc.id, ...data });
    if (data.image_url) {
      firestoreUrls.add(normalizeUrl(data.image_url));
    }
  });
  console.log(`Firestore has ${firestoreWallpapers.length} wallpapers.`);

  // 2. Get Cloudinary Resources
  const cloudinaryUrls = new Set();
  const cloudinaryResources = [];

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
        const result = await cloudinary.api.resources({
          type: 'upload',
          max_results: 500,
          next_cursor: next_cursor
        });
        result.resources.forEach(r => {
          const norm = normalizeUrl(r.secure_url);
          cloudinaryUrls.add(norm);
          cloudinaryResources.push({
            url: r.secure_url,
            normalized: norm,
            account: cloud.name,
            public_id: r.public_id
          });
        });
        next_cursor = result.next_cursor;
      } while (next_cursor);
    } catch (err) {
      console.error(`Error listing ${cloud.name}:`, err.message);
    }
  }
  console.log(`Cloudinary has ${cloudinaryResources.length} resources.`);

  // 3. Compare
  const missingInFirestore = cloudinaryResources.filter(r => !firestoreUrls.has(r.normalized));
  const brokenInFirestore = firestoreWallpapers.filter(w => w.image_url && !cloudinaryUrls.has(normalizeUrl(w.image_url)));

  console.log(`\nResults:`);
  console.log(`- Images in Cloudinary NOT in Firestore: ${missingInFirestore.length}`);
  console.log(`- Wallpapers in Firestore NOT in Cloudinary: ${brokenInFirestore.length}`);

  if (missingInFirestore.length > 0) {
    console.log('\nSample missing images:');
    missingInFirestore.slice(0, 5).forEach(m => console.log(`  [${m.account}] ${m.url}`));
  }

  if (brokenInFirestore.length > 0) {
      console.log('\nSample broken Firestore wallpapers:');
      brokenInFirestore.slice(0, 5).forEach(b => console.log(`  [${b.id}] ${b.title} (${b.image_url})`));
  }

  process.exit(0);
}

analyze().catch(e => {
  console.error(e);
  process.exit(1);
});
