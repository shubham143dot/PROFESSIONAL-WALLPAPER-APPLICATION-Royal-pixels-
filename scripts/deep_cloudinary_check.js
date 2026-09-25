const cloudinary = require('cloudinary').v2;
// Cloudinary Credentials (configured via environment or .env)
const CLOUDS = [
  { name: 'Free', cloud_name: process.env.CLOUDINARY_CLOUD_NAME_FREE || '', api_key: process.env.CLOUDINARY_API_KEY_FREE || '', api_secret: process.env.CLOUDINARY_API_SECRET_FREE || '' },
  { name: 'Premium', cloud_name: process.env.CLOUDINARY_CLOUD_NAME_PREMIUM || '', api_key: process.env.CLOUDINARY_API_KEY_PREMIUM || '', api_secret: process.env.CLOUDINARY_API_SECRET_PREMIUM || '' }
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
