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
const product_schema_1 = require("./product.schema");
const productRoutes = async (app) => {
    const repository = new product_repository_1.ProductRepository(app.db);
    const service = new product_service_1.ProductService(repository);
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
};
exports.productRoutes = productRoutes;
//# sourceMappingURL=product.routes.js.map