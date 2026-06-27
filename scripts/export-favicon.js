// Run: node scripts/export-favicon.js
// Requires: npm install sharp
// Reads:    public/logo-concepts/icon-dark-bg.svg
// Outputs:  public/ (all 6 favicon/icon files)

const sharp = require('sharp');
const path = require('path');
const fs = require('fs');

const SRC = path.join(__dirname, '../public/logo-concepts/icon-dark-bg.svg');
const OUT = path.join(__dirname, '../public');

const svgBuffer = fs.readFileSync(SRC);

const exports = [
  { file: 'favicon-16x16.png',          size: 16  },
  { file: 'favicon-32x32.png',          size: 32  },
  { file: 'apple-touch-icon.png',       size: 180 },
  { file: 'android-chrome-192x192.png', size: 192 },
  { file: 'android-chrome-512x512.png', size: 512 },
];

async function run() {
  for (const { file, size } of exports) {
    const dest = path.join(OUT, file);
    await sharp(svgBuffer)
      .resize(size, size)
      .png()
      .toFile(dest);
    console.log(`✓ ${file} (${size}×${size})`);
  }

  // favicon.ico — embed 16, 32, 48 sizes
  // sharp doesn't write .ico natively; we generate a 48px PNG and rename guidance below
  const icoSrc = path.join(OUT, 'favicon-32x32.png');
  console.log('\nfavicon.ico note:');
  console.log('  Use https://favicon.io/favicon-converter/ — upload favicon-32x32.png → download favicon.ico');
  console.log('  Place the downloaded favicon.ico in /public, replacing the existing one.');
  console.log('\nAll done. Copy the files above into /public and you are ready for Sprint R7.');
}

run().catch(err => { console.error(err); process.exit(1); });
