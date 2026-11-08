"use strict";
var __importDefault = (this && this.__importDefault) || function (mod) {
    return (mod && mod.__esModule) ? mod : { "default": mod };
};
Object.defineProperty(exports, "__esModule", { value: true });
exports.ProductAssetService = void 0;
const node_crypto_1 = __importDefault(require("node:crypto"));
const sharp_1 = __importDefault(require("sharp"));
const contracts_1 = require("@eh-home/contracts");
const MAX_UPLOAD_BYTES = 12 * 1024 * 1024;
const KINDS = new Set(['hero', 'front', 'rear', 'installed', 'packaging', 'technicalDiagram', 'diagram', 'render', 'icon', 'thumbnail']);
const ASSET_SORT_ORDER = {
    hero: 0,
    thumbnail: 1,
    front: 2,
    rear: 3,
    installed: 4,
    packaging: 5,
    technicalDiagram: 6,
    diagram: 7,
    render: 8,
    icon: 9,
};
class ProductAssetService {
    storage;
    repository;
    constructor(storage, repository) {
        this.storage = storage;
        this.repository = repository;
    }
    async uploadVariantAsset(variantId, input) {
        if (!KINDS.has(input.kind))
            throw new Error('Unsupported product asset kind');
        const content = Buffer.from(input.contentBase64, 'base64');
        if (!content.length || content.length > MAX_UPLOAD_BYTES)
            throw new Error('Image must be between 1 byte and 12 MB');
        const image = (0, sharp_1.default)(content, { failOn: 'error' });
        const metadata = await image.metadata();
        if (!metadata.format || !['png', 'jpeg', 'webp', 'avif'].includes(metadata.format))
            throw new Error('Only PNG, JPEG, WebP, or AVIF images are supported');
        if (!metadata.width || !metadata.height || metadata.width < 32 || metadata.height < 32)
            throw new Error('Image must be at least 32x32 pixels');
        if (metadata.width > 8000 || metadata.height > 8000)
            throw new Error('Image dimensions must not exceed 8000x8000 pixels');
        const variant = await this.repository.getVariantById(variantId);
        if (!variant)
            throw new Error(`Variant '${variantId}' not found`);
        const productId = input.productId || variant.productId;
        const assetId = `${variantId}-${input.kind}-${node_crypto_1.default.randomUUID()}`;
        const output = await image.rotate().resize({ width: 1600, height: 1600, fit: 'inside', withoutEnlargement: true }).webp({ quality: 84, effort: 4 }).toBuffer();
        const filename = `${input.kind}.webp`;
        const key = contracts_1.CanonicalObjectKeyBuilder.buildProductAssetKey(productId, variantId, assetId, filename);
        await this.storage.putObject('eh-product-assets', key, output, {
            contentType: 'image/webp',
            classification: 'PUBLIC_ASSET',
            customMetadata: { productId, variantId, assetId, kind: input.kind, sourceFormat: metadata.format, width: String(metadata.width), height: String(metadata.height) },
        });
        // One authoritative image per variant/kind. This also removes stale
        // metadata left by the previous in-memory provider, so sync cannot pick
        // an older 404 URL after a replacement upload.
        for (const previous of await this.repository.listVariantAssets(variantId)) {
            if (previous.kind === input.kind)
                await this.deleteVariantAsset(variantId, previous.assetId);
        }
        const url = `/api/v1/storage/object/eh-product-assets/${key}`;
        // sort_order is a PostgreSQL INTEGER. Date.now() is a millisecond epoch
        // (~1.7e12) and overflows that column; use a deterministic catalog order.
        return this.repository.createVariantAsset({
            id: assetId,
            productVariantId: variantId,
            kind: input.kind,
            url,
            sortOrder: ASSET_SORT_ORDER[input.kind],
        });
    }
    async deleteVariantAsset(variantId, assetId) {
        const asset = await this.repository.getVariantAsset(variantId, assetId);
        if (!asset)
            return false;
        const deleted = await this.repository.deleteVariantAsset(variantId, assetId);
        if (deleted && asset.url.includes('/storage/object/eh-product-assets/')) {
            const key = asset.url.split('/storage/object/eh-product-assets/')[1];
            if (key)
                await this.storage.deleteObject('eh-product-assets', key);
        }
        return deleted;
    }
}
exports.ProductAssetService = ProductAssetService;
//# sourceMappingURL=product-asset.service.js.map