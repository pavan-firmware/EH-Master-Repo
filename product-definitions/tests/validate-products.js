const path = require('path');
const fs = require('fs');
const { SchemaValidator } = require('../../packages/contracts/validator');

const validator = new SchemaValidator();

// Load canonical schemas
[
  '../../packages/contracts/product/hardware-profile.schema.json',
  '../../packages/contracts/product/connectivity-profile.schema.json',
  '../../packages/contracts/product/product-metadata.schema.json',
  '../../packages/contracts/product/product-family.schema.json',
  '../../packages/contracts/product/product-model.schema.json',
  '../../packages/contracts/product/product-variant.schema.json',
  '../../packages/contracts/product/product-asset.schema.json',
  '../../packages/contracts/product/product-catalog-entry.schema.json',
  '../../packages/contracts/product/product-discovery-response.schema.json',
  '../../packages/contracts/product/product-search-result.schema.json',
  '../../packages/contracts/product/product-compatibility.schema.json',
  '../../packages/contracts/product/device-add-session.schema.json'
].forEach(f => validator.loadSchema(path.join(__dirname, f)));

console.log('=== VALIDATING PRODUCT DEFINITIONS ===\n');

const productDefinitionsRoot = path.join(__dirname, '..');
const families = fs.readdirSync(productDefinitionsRoot).filter(entry => {
  const entryPath = path.join(productDefinitionsRoot, entry);
  return fs.statSync(entryPath).isDirectory() && !entry.startsWith('_') && entry !== 'tests';
});

let failed = 0;
let validatedCount = 0;

for (const family of families) {
  const familyPath = path.join(productDefinitionsRoot, family);
  const variants = fs.readdirSync(familyPath).filter(entry => {
    const entryPath = path.join(familyPath, entry);
    return fs.statSync(entryPath).isDirectory();
  });

  for (const variant of variants) {
    const variantPath = path.join(familyPath, variant);
    const metadataPath = path.join(variantPath, 'metadata.json');
    if (!fs.existsSync(metadataPath)) continue;

    const metadata = JSON.parse(fs.readFileSync(metadataPath, 'utf8'));
    const res = validator.validate('ProductMetadata', metadata);
    if (res.valid) {
      console.log(`[PASS] ${family}/${variant} metadata.json (${metadata.productVariantId}) validated successfully!`);
      validatedCount++;
    } else {
      console.error(`[FAIL] ${family}/${variant} metadata.json failed validation:`, res.errors);
      failed++;
    }
  }
}

console.log(`\nValidated ${validatedCount} product definitions. Failures: ${failed}`);
process.exit(failed > 0 ? 1 : 0);
