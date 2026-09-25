const cloudinary = require('cloudinary').v2;
// Cloudinary Credentials (configured via environment or .env)
const CLOUDS = [
  { name: 'Free', cloud_name: process.env.CLOUDINARY_CLOUD_NAME_FREE || 'dl00rha3n', api_key: process.env.CLOUDINARY_API_KEY_FREE || '837238164488567', api_secret: process.env.CLOUDINARY_API_SECRET_FREE || 'YOUR_FREE_API_SECRET' },
  { name: 'Premium', cloud_name: process.env.CLOUDINARY_CLOUD_NAME_PREMIUM || 'dmt6y2k6h', api_key: process.env.CLOUDINARY_API_KEY_PREMIUM || '174456259398661', api_secret: process.env.CLOUDINARY_API_SECRET_PREMIUM || 'YOUR_PREMIUM_API_SECRET' }
];

async function checkDeep() {
  for (const cloud of CLOUDS) {
    console.log(`\nAccount: ${cloud.name} (${cloud.cloud_name})`);
    cloudinary.config({
      cloud_name: cloud.cloud_name,
      api_key: cloud.api_key,
      api_secret: cloud.api_secret,
      secure: true
    });

    for (const type of ['upload', 'private', 'authenticated']) {
      try {
        let total = 0;
        let next_cursor = null;
        do {
          const res = await cloudinary.api.resources({ type, max_results: 500, next_cursor });
          total += res.resources.length;
          next_cursor = res.next_cursor;
        } while (next_cursor);
        console.log(`  - ${type}: ${total} resources found`);
      } catch (e) {
        console.log(`  - ${type}: Error ${e.message}`);
      }
    }

    try {
      const folders = await cloudinary.api.root_folders();
      console.log(`  - Folders: ${folders.folders.map(f => f.name).join(', ') || 'None'}`);
    } catch (e) {
      console.log(`  - Folders: Error ${e.message}`);
    }
  }
}

checkDeep();
