import { StorageService } from '../storage/storage.service';
import { ProductRepository } from './product.repository';
import { ProductAsset } from './product.schema';
export declare class ProductAssetService {
    private readonly storage;
    private readonly repository;
    constructor(storage: StorageService, repository: ProductRepository);
    uploadVariantAsset(variantId: string, input: {
        kind: ProductAsset['kind'];
        filename: string;
        contentBase64: string;
        productId?: string;
    }): Promise<ProductAsset>;
    deleteVariantAsset(variantId: string, assetId: string): Promise<boolean>;
}
//# sourceMappingURL=product-asset.service.d.ts.map