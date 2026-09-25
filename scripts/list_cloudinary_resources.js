const cloudinary = require('cloudinary').v2;

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

async function listAll() {
  for (const cloud of CLOUDS) {
    console.log(`\nAccount: ${cloud.name}`);
    cloudinary.config({
      cloud_name: cloud.cloud_name,
      api_key: cloud.api_key,
      api_secret: cloud.api_secret,
      secure: true
    });

    let next_cursor = null;
    let count = 0;
    try {
      do {
        const result = await cloudinary.api.resources({
          type: 'upload',
          max_results: 500,
          next_cursor: next_cursor
        });
        count += result.resources.length;
        result.resources.forEach(r => {
           console.log(`URL: ${r.secure_url}`);
        });
        next_cursor = result.next_cursor;
      } while (next_cursor);
      console.log(`Total in ${cloud.name}: ${count}`);
    } catch (err) {
      console.error(`Error ${cloud.name}:`, err.message);
    }
  }
}

listAll();
