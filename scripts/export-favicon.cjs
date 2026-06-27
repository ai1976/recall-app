// Run: node scripts/export-favicon.cjs
// Requires: npm install sharp  (already done)
// Outputs:  public/ (5 PNG files ready to use)

const sharp = require('sharp');
const path = require('path');
const fs = require('fs');

// Build SVG with font embedded as base64 so sharp renders it correctly
const fontPath = path.join(__dirname, 'DMSans-Bold.woff2');
const fontB64 = fs.readFileSync(fontPath).toString('base64');

const svgSource = `<svg width="512" height="512" viewBox="0 0 512 512" xmlns="http://www.w3.org/2000/svg">
  <defs>
    <style>
      @font-face {
        font-family: 'DM Sans';
        font-weight: 700;
        src: url('data:font/woff2;base64,${fontB64}') format('woff2');
      }
    </style>
  </defs>
  <rect width="512" height="512" fill="#1e1b4b" rx="100"/>
  <text x="256" y="308" text-anchor="middle"
    font-family="DM Sans, sans-serif"
    font-weight="700" font-size="112" letter-spacing="-4">
    <tspan fill="#f59e0b">Revis</tspan><tspan fill="#ffffff">Op</tspan>
  </text>
</svg>`;

const svgBuffer = Buffer.from(svgSource);
const OUT = path.join(__dirname, '../public');

const sizes = [
  { file: 'favicon-16x16.png',          size: 16  },
  { file: 'favicon-32x32.png',          size: 32  },
  { file: 'apple-touch-icon.png',       size: 180 },
  { file: 'android-chrome-192x192.png', size: 192 },
  { file: 'android-chrome-512x512.png', size: 512 },
];

// Render at 4× then downscale for crisp edges
const OVERSAMPLE = 4;

async function run() {
  for (const { file, size } of sizes) {
    const dest = path.join(OUT, file);
    const renderSize = size * OVERSAMPLE;
    await sharp(svgBuffer)
      .resize(renderSize, renderSize)
      .resize(size, size, { kernel: sharp.kernel.lanczos3 })
      .png()
      .toFile(dest);
    console.log(`✓  ${file}  (${size}×${size})`);
  }

  console.log('\nAll 5 PNG files written to /public.');
  console.log('\nFor favicon.ico:');
  console.log('  1. Go to https://favicon.io/favicon-converter/');
  console.log('  2. Upload public/favicon-32x32.png');
  console.log('  3. Download and place favicon.ico in /public/');
}

run().catch(err => { console.error(err); process.exit(1); });
