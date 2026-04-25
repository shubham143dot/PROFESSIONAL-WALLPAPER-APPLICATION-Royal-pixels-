const cloudinary = require('cloudinary').v2;
const CLOUDS = [
  { name: 'Free', cloud_name: 'dl00rha3n', api_key: '837238164488567', api_secret: 'bdHDsHE2QyXzqt5UNLJMzxrrpu8' },
  { name: 'Premium', cloud_name: 'dmt6y2k6h', api_key: '174456259398661', api_secret: 'OxI0nRoL8RNK7xRJYVQJtX6cEhs' }
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
