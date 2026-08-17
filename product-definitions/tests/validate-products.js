const path = require('path');
const fs = require('fs');
const { SchemaValidator } = require('../../packages/contracts/validator');

const validator = new SchemaValidator();

// Load canonical schemas
[
  '../../packages/contracts/product/hardware-profile.schema.json',
  '../../packages/contracts/product/connectivity-profile.schema.json',
  '../../packages/contracts/product/product-metadata.schema.json'
].forEach(f => validator.loadSchema(path.join(__dirname, f)));

console.log('=== VALIDATING PRODUCT DEFINITIONS ===\n');

const metadataPath = path.join(__dirname, '../smart-switch/3x/metadata.json');
const metadata = JSON.parse(fs.readFileSync(metadataPath, 'utf8'));

const res = validator.validate('ProductMetadata', metadata);
if (res.valid) {
  console.log(`[PASS] smart-switch-3x metadata.json validated successfully!`);
  process.exit(0);
} else {
  console.error(`[FAIL] smart-switch-3x metadata.json failed validation:`, res.errors);
  process.exit(1);
}
