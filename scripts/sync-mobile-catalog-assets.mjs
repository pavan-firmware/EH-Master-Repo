#!/usr/bin/env node

// Release step: copy approved API artwork into the Flutter APK and generate
// an exact variantId -> local asset manifest for offline product discovery.
import fs from 'node:fs/promises';
import path from 'node:path';
import process from 'node:process';
import { fileURLToPath } from 'node:url';

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');
const flutterRoot = path.join(root, 'smart_home_application_v1');
const assetRoot = path.join(flutterRoot, 'assets', 'products', 'catalog');
const manifestPath = path.join(flutterRoot, 'lib', 'core', 'generated', 'product_asset_manifest.dart');
const index = process.argv.indexOf('--api');
const apiBase = (index >= 0 && process.argv[index + 1] ? process.argv[index + 1] : process.env.EH_HOME_API_URL || 'http://127.0.0.1:3000').replace(/\/$/, '');

const response = await fetch(`${apiBase}/api/v1/products/variants?databaseOnly=true&limit=500`);
if (!response.ok) throw new Error(`Catalog request failed: HTTP ${response.status}`);
const envelope = await response.json();
const variants = Array.isArray(envelope.data) ? envelope.data : [];
if (!variants.length) throw new Error('Catalog returned no database variants; refusing to replace the mobile manifest.');

await fs.mkdir(assetRoot, { recursive: true });
await fs.mkdir(path.dirname(manifestPath), { recursive: true });
const manifest = {};

for (const variant of variants) {
  const variantId = String(variant.variantId || '').trim();
  if (!variantId) continue;
  const assets = Array.isArray(variant.assets) ? variant.assets : [];
  const selected = assets.find((asset) => asset.kind === 'hero') || assets.find((asset) => asset.kind === 'thumbnail') || assets.find((asset) => asset.kind === 'front');
  if (!selected?.url) {
    console.warn(`[mobile-assets] SKIP ${variantId} — no hero/thumbnail/front asset uploaded yet.`);
    continue;
  }
  const assetUrl = /^https?:\/\//i.test(selected.url) ? selected.url : `${apiBase}${selected.url}`;
  const imageResponse = await fetch(assetUrl);
  if (!imageResponse.ok) {
    // Warn and skip — do not abort the entire sync when one variant's image is missing.
    // This keeps the manifest up-to-date for all other variants.
    console.warn(
      `[mobile-assets] SKIP ${variantId} — image not reachable at ${assetUrl} (HTTP ${imageResponse.status}). ` +
      'Re-upload this variant image in the admin desktop app then run sync again.'
    );
    continue;
  }
  const relative = `assets/products/catalog/${variantId}/hero.webp`;
  const destination = path.join(flutterRoot, relative.replaceAll('/', path.sep));
  await fs.mkdir(path.dirname(destination), { recursive: true });
  await fs.writeFile(destination, Buffer.from(await imageResponse.arrayBuffer()));
  manifest[variantId] = relative;
  console.log(`[mobile-assets] ${variantId} <- ${selected.kind}`);
}

const dartMap = Object.entries(manifest).sort(([a], [b]) => a.localeCompare(b)).map(([id, asset]) => `  ${JSON.stringify(id)}: ${JSON.stringify(asset)},`).join('\n');
await fs.writeFile(manifestPath, `// GENERATED FILE. Do not edit manually.\nconst Map<String, String> bundledProductAssetManifest = <String, String>{\n${dartMap}\n};\n`, 'utf8');
console.log(`[mobile-assets] Generated ${Object.keys(manifest).length} exact variant mappings.`);

// Automatically update pubspec.yaml assets section so Flutter packages all catalog subdirectories
const pubspecPath = path.join(flutterRoot, 'pubspec.yaml');
try {
  let pubspecContent = await fs.readFile(pubspecPath, 'utf8');
  const catalogDirs = (await fs.readdir(assetRoot, { withFileTypes: true }))
    .filter((d) => d.isDirectory())
    .map((d) => d.name)
    .sort();

  // Find all existing asset lines under flutter: assets:
  const lines = pubspecContent.split(/\r?\n/);
  const assetsIdx = lines.findIndex((l) => /^\s*assets:\s*$/.test(l));
  if (assetsIdx >= 0) {
    // Collect non-catalog asset lines
    const preserved = [];
    let endIdx = assetsIdx + 1;
    while (endIdx < lines.length && (lines[endIdx].startsWith('    -') || lines[endIdx].startsWith('    #') || lines[endIdx].trim() === '')) {
      const line = lines[endIdx];
      if (!line.includes('assets/products/catalog/')) {
        preserved.push(line);
      }
      endIdx++;
    }

    const newCatalogEntries = [
      '    # Bundled product catalog images (populated by scripts/sync-mobile-catalog-assets.mjs)',
      '    - assets/products/catalog/',
      ...catalogDirs.map((dir) => `    - assets/products/catalog/${dir}/`),
    ];

    const updatedLines = [
      ...lines.slice(0, assetsIdx + 1),
      ...preserved.filter((l) => l.trim().length > 0 && !l.includes('Bundled product catalog')),
      ...newCatalogEntries,
      ...lines.slice(endIdx),
    ];

    await fs.writeFile(pubspecPath, updatedLines.join('\n'), 'utf8');
    console.log(`[mobile-assets] Synchronized pubspec.yaml with ${catalogDirs.length} catalog variant asset directories.`);
  }
} catch (err) {
  console.warn(`[mobile-assets] Could not auto-update pubspec.yaml: ${err.message}`);
}
