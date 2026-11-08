"use strict";
/**
 * EH Home Product Domain Routes
 *
 * Fastify route plugin for the Product & Design Management catalog.
 * Follows the pattern: Route -> Validation -> Service -> Repository -> Drizzle.
 */
Object.defineProperty(exports, "__esModule", { value: true });
exports.productRoutes = void 0;
const product_repository_1 = require("./product.repository");
const product_service_1 = require("./product.service");
const product_asset_service_1 = require("./product-asset.service");
const product_schema_1 = require("./product.schema");
const productRoutes = async (app) => {
    const repository = new product_repository_1.ProductRepository(app.db);
    const service = new product_service_1.ProductService(repository);
    const assetService = new product_asset_service_1.ProductAssetService(app.storageService, repository);
    // 1. GET /api/v1/products - List products with optional query filtering
    app.get('/', async (req, reply) => {
        const filters = product_schema_1.ListProductsQuerySchema.parse(req.query);
        const result = await service.listProducts(filters);
        return reply.status(200).send({
            schemaVersion: 1,
            success: true,
            data: result.items,
            pagination: {
                total: result.total,
                limit: result.limit,
                offset: result.offset,
            },
            meta: {
                requestId: req.correlationId,
                timestamp: new Date().toISOString(),
            },
        });
    });
    // 2. GET /api/v1/products/families - List product families
    app.get('/families', async (req, reply) => {
        const families = await service.listFamilies();
        return reply.status(200).send({
            schemaVersion: 1,
            success: true,
            data: families,
            meta: {
                requestId: req.correlationId,
                timestamp: new Date().toISOString(),
            },
        });
    });
    // 3. GET /api/v1/products/variants - List all product variants
    app.get('/variants', async (req, reply) => {
        const query = req.query || {};
        const result = await service.listVariants({
            familyId: query.familyId,
            productId: query.productId,
            limit: query.limit ? Number(query.limit) : 50,
            offset: query.offset ? Number(query.offset) : 0,
            databaseOnly: query.databaseOnly === 'true',
        });
        return reply.status(200).send({
            schemaVersion: 1,
            success: true,
            data: result.items,
            pagination: {
                total: result.total,
                limit: query.limit ? Number(query.limit) : 50,
                offset: query.offset ? Number(query.offset) : 0,
            },
            meta: {
                source: query.databaseOnly === 'true' ? 'database' : 'database_or_canonical_fallback',
                requestId: req.correlationId,
                timestamp: new Date().toISOString(),
            },
        });
    });
    // 4. GET /api/v1/products/variants/:variantId - Retrieve single variant details
    app.get('/variants/:variantId', async (req, reply) => {
        const params = product_schema_1.GetVariantParamsSchema.parse(req.params);
        const variant = await service.getVariant(params.variantId);
        if (!variant) {
            return reply.status(404).send({
                schemaVersion: 1,
                success: false,
                error: {
                    code: 'VARIANT_NOT_FOUND',
                    message: `Product variant with ID '${params.variantId}' not found`,
                },
                meta: {
                    requestId: req.correlationId,
                    timestamp: new Date().toISOString(),
                },
            });
        }
        return reply.status(200).send({
            schemaVersion: 1,
            success: true,
            data: variant,
            meta: {
                requestId: req.correlationId,
                timestamp: new Date().toISOString(),
            },
        });
    });
    // Consumer/mobile discovery contract. This is deliberately database-only:
    // a phone must never receive canonical demo variants that are not actually
    // present in the catalog database.
    app.get('/discovery', async (req, reply) => {
        const query = req.query || {};
        const page = Math.max(1, Number(query.page) || 1);
        const limit = Math.min(100, Math.max(1, Number(query.limit) || 20));
        const all = await service.listVariants({ databaseOnly: true, limit: 500, offset: 0 });
        const families = await service.listFamilies();
        const familyByProductId = new Map();
        for (const family of families) {
            for (const product of family.products || [])
                familyByProductId.set(product.id, family);
        }
        const text = (value) => String(value ?? '').toLowerCase();
        const categoryFor = (variant) => {
            const value = text(`${variant.displayName} ${variant.variantSlug}`);
            if (value.includes('sensor'))
                return 'sensors';
            if (value.includes('hub') || value.includes('gateway'))
                return 'hubs';
            if (value.includes('fan'))
                return 'fans';
            if (value.includes('light'))
                return 'lights';
            if (value.includes('socket'))
                return 'sockets';
            return 'switches';
        };
        const requestedCategory = text(query.category);
        const requestedCapability = text(query.capability);
        const requestedFamily = text(query.family || query.familyId);
        const requestedConnectivity = text(query.connectivity);
        const filtered = all.items.filter((variant) => {
            const family = familyByProductId.get(variant.productId);
            const category = categoryFor(variant);
            const capabilities = (variant.capabilities || []).map(text);
            const connectivity = text(JSON.stringify(variant.connectivityProfile));
            const familyMatches = !requestedFamily ||
                text(family?.id).includes(requestedFamily) ||
                text(family?.slug).includes(requestedFamily) ||
                text(family?.displayName).includes(requestedFamily);
            return (!requestedCategory || category === requestedCategory) &&
                (!requestedCapability || capabilities.some((item) => item.includes(requestedCapability))) &&
                (!requestedConnectivity || connectivity.includes(requestedConnectivity)) &&
                familyMatches;
        });
        const products = filtered.map((variant) => {
            const family = familyByProductId.get(variant.productId);
            const images = {};
            for (const asset of variant.assets || []) {
                if (asset.isPublished !== false && asset.url)
                    images[asset.kind] = asset.url;
            }
            return {
                productId: variant.productId,
                productFamilyId: family?.id || '',
                modelId: variant.variantId,
                variantId: variant.variantId,
                sku: variant.variantSlug,
                marketingName: variant.displayName,
                technicalName: variant.variantSlug,
                description: '',
                productStatus: 'ACTIVE',
                visibility: 'PUBLIC',
                category: categoryFor(variant),
                brand: 'EH',
                images,
                assets: variant.assets || [],
                channelCount: variant.channelCount,
                channels: variant.channels,
                electricalSpecifications: variant.electricalSpecifications,
                capabilities: variant.capabilities,
                supportedHardwareRevisions: variant.supportedHardwareRevisions,
                connectivityCapabilities: Object.keys(variant.connectivityProfile || {}),
            };
        });
        const offset = (page - 1) * limit;
        const pageItems = products.slice(offset, offset + limit);
        const categoryCounts = new Map();
        for (const item of products)
            categoryCounts.set(item.category, (categoryCounts.get(item.category) || 0) + 1);
        const capabilitySet = new Set();
        for (const item of products)
            for (const capability of item.capabilities || [])
                capabilitySet.add(capability);
        return reply.status(200).send({
            products: pageItems,
            total: products.length,
            page,
            limit,
            totalPages: Math.ceil(products.length / limit),
            categories: [...categoryCounts].map(([id, count]) => ({ id, displayName: id, count })),
            families: families.map((family) => ({ id: family.id, displayName: family.displayName, category: 'devices' })),
            availableCapabilities: [...capabilitySet],
        });
    });
    // 4. GET /api/v1/products/:productId - Retrieve complete product details
    app.get('/:productId', async (req, reply) => {
        const params = product_schema_1.GetProductParamsSchema.parse(req.params);
        const product = await service.getProduct(params.productId);
        if (!product) {
            return reply.status(404).send({
                schemaVersion: 1,
                success: false,
                error: {
                    code: 'PRODUCT_NOT_FOUND',
                    message: `Product with ID '${params.productId}' not found`,
                },
                meta: {
                    requestId: req.correlationId,
                    timestamp: new Date().toISOString(),
                },
            });
        }
        return reply.status(200).send({
            schemaVersion: 1,
            success: true,
            data: product,
            meta: {
                requestId: req.correlationId,
                timestamp: new Date().toISOString(),
            },
        });
    });
    // 5. POST /api/v1/products - Create a new product
    app.post('/', async (req, reply) => {
        const created = await service.createProduct(req.body);
        return reply.status(201).send({
            schemaVersion: 1,
            success: true,
            data: created,
            meta: {
                requestId: req.correlationId,
                timestamp: new Date().toISOString(),
            },
        });
    });
    // 6. PATCH /api/v1/products/:productId - Update/Archive product
    app.patch('/:productId', async (req, reply) => {
        const params = product_schema_1.GetProductParamsSchema.parse(req.params);
        const updated = await service.updateProduct(params.productId, req.body);
        if (!updated) {
            return reply.status(404).send({
                schemaVersion: 1,
                success: false,
                error: { code: 'PRODUCT_NOT_FOUND', message: `Product '${params.productId}' not found` },
            });
        }
        return reply.status(200).send({
            schemaVersion: 1,
            success: true,
            data: updated,
            meta: { requestId: req.correlationId, timestamp: new Date().toISOString() },
        });
    });
    // 7. POST /api/v1/products/variants - Create variant
    app.post('/variants', async (req, reply) => {
        const created = await service.createVariant(req.body);
        return reply.status(201).send({
            schemaVersion: 1,
            success: true,
            data: created,
            meta: { requestId: req.correlationId, timestamp: new Date().toISOString() },
        });
    });
    // 8. PATCH /api/v1/products/variants/:variantId - Update/Archive variant
    app.patch('/variants/:variantId', async (req, reply) => {
        const params = product_schema_1.GetVariantParamsSchema.parse(req.params);
        const updated = await service.updateVariant(params.variantId, req.body);
        if (!updated) {
            return reply.status(404).send({
                schemaVersion: 1,
                success: false,
                error: { code: 'VARIANT_NOT_FOUND', message: `Variant '${params.variantId}' not found` },
            });
        }
        return reply.status(200).send({
            schemaVersion: 1,
            success: true,
            data: updated,
            meta: { requestId: req.correlationId, timestamp: new Date().toISOString() },
        });
    });
    // Product imagery is deliberately variant-scoped: an image can never be
    // attached to a different model by filename or family-name matching.
    app.post('/variants/:variantId/assets', async (req, reply) => {
        const params = product_schema_1.GetVariantParamsSchema.parse(req.params);
        const body = req.body;
        if (!body?.kind || !body?.filename || !body?.contentBase64) {
            return reply.status(400).send({ success: false, error: { code: 'INVALID_ASSET_UPLOAD', message: 'kind, filename, and contentBase64 are required' } });
        }
        try {
            const asset = await assetService.uploadVariantAsset(params.variantId, body);
            return reply.status(201).send({ schemaVersion: 1, success: true, data: asset, meta: { requestId: req.correlationId, timestamp: new Date().toISOString() } });
        }
        catch (err) {
            return reply.status(422).send({ success: false, error: { code: 'ASSET_UPLOAD_REJECTED', message: err.message } });
        }
    });
    app.delete('/variants/:variantId/assets/:assetId', async (req, reply) => {
        const params = req.params;
        const deleted = await assetService.deleteVariantAsset(params.variantId, params.assetId);
        return reply.status(deleted ? 200 : 404).send({ success: deleted, ...(deleted ? {} : { error: { code: 'ASSET_NOT_FOUND', message: 'Asset not found for this variant' } }) });
    });
};
exports.productRoutes = productRoutes;
//# sourceMappingURL=product.routes.js.map