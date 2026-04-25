const admin = require('firebase-admin');
const path = require('path');
const http = require('http');
const https = require('https');

const sa = require(path.join(__dirname, 'service_account.json'));
admin.initializeApp({ credential: admin.credential.cert(sa) });
const db = admin.firestore();

function checkImageValid(url) {
  return new Promise((resolve) => {
    try {
      if (!url || !url.startsWith('http')) {
        return resolve(false);
      }
      
      const lib = url.startsWith('https') ? https : http;
      const req = lib.request(url, { method: 'HEAD', timeout: 5000 }, (res) => {
        // Some CDNs return 403 or 401 instead of 404 for invalid assets, but usually 404
        if (res.statusCode >= 400) {
          resolve(false);
        } else {
          resolve(true);
        }
      });
      
      req.on('error', () => resolve(false));
      req.on('timeout', () => {
        req.destroy();
        resolve(false);
      });
      req.end();
    } catch (e) {
      resolve(false);
    }
  });
}

async function run() {
  console.log('Fetching wallpapers...');
  const snap = await db.collection('wallpapers').get();
  let total = snap.size;
  let deleted = 0;
  
  console.log(`Checking ${total} wallpapers...`);
  
  const batch = db.batch();
  let promises = [];
  
  for (const doc of snap.docs) {
    const data = doc.data();
    const url = data.image_url;
    
    // Check if valid
    const p = checkImageValid(url).then(isValid => {
      if (!isValid) {
        console.log(`[DELETE] Invalid/Missing Image: ${data.title} (${doc.id}) - URL: ${url}`);
        batch.delete(doc.ref);
        deleted++;
      }
    });
    
    promises.push(p);
    
    // To not overwhelm the network, pause every 20 requests
    if (promises.length >= 20) {
      await Promise.all(promises);
      promises = [];
    }
  }
  
  if (promises.length > 0) {
    await Promise.all(promises);
  }
  
  if (deleted > 0) {
    console.log(`Committing deletion of ${deleted} wallpapers...`);
    await batch.commit();
    console.log('Deletion successful!');
  } else {
    console.log('No invalid wallpapers found.');
  }
  
  process.exit(0);
}

run().catch(e => {
  console.error('Error:', e);
  process.exit(1);
});
