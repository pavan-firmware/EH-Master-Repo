/**
 * EH Home Product Domain Routes
 *
 * Fastify route plugin for the Product & Design Management catalog.
 * Follows the pattern: Route -> Validation -> Service -> Repository -> Drizzle.
 */

import { FastifyInstance, FastifyPluginAsync } from 'fastify';
import { ProductRepository } from './product.repository';
import { ProductService } from './product.service';
import {
  ListProductsQuerySchema,
  GetProductParamsSchema,
  GetVariantParamsSchema,
} from './product.schema';

export const productRoutes: FastifyPluginAsync = async (app: FastifyInstance) => {
  const repository = new ProductRepository(app.db);
  const service = new ProductService(repository);

  // 1. GET /api/v1/products - List products with optional query filtering
  app.get('/', async (req, reply) => {
    const filters = ListProductsQuerySchema.parse(req.query);
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

  // 3. GET /api/v1/products/variants/:variantId - Retrieve single variant details
  app.get('/variants/:variantId', async (req, reply) => {
    const params = GetVariantParamsSchema.parse(req.params);
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
    const params = GetProductParamsSchema.parse(req.params);
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
};
