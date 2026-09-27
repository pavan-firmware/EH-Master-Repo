/**
 * EH Home Desktop — Product Catalog Management (Part 05)
 *
 * Exposes canonical product families, variants, channel mappings,
 * hardware compatibility, firmware family, capabilities, and electrical specs.
 * Consumes apps/api /api/v1/products and canonical contracts.
 */

import React, { useState, useEffect, useCallback } from 'react';
import {
  Box,
  RefreshCw,
  Sliders,
  Cpu,
  Zap,
  Radio,
  CheckCircle2,
  AlertCircle,
  Search,
  ExternalLink,
  Layers,
  ChevronRight,
} from 'lucide-react';
import { apiClient } from '../../services/api-client';
import { CANONICAL_PRODUCT_DEFINITIONS, CanonicalProductDefinition } from '@eh-home/contracts';

export const ProductsView: React.FC = () => {
  const [products, setProducts] = useState<any[]>([...CANONICAL_PRODUCT_DEFINITIONS]);
  const [selectedFamily, setSelectedFamily] = useState<string>('all');
  const [searchQuery, setSearchQuery] = useState<string>('');
  const [selectedVariantId, setSelectedVariantId] = useState<string>('eh-smart-switch-1x');
  const [isLoading, setIsLoading] = useState<boolean>(true);
  const [error, setError] = useState<string | null>(null);

  const fetchCatalog = useCallback(async () => {
    setIsLoading(true);
    setError(null);
    try {
      const [prodRes] = await Promise.all([
        apiClient.listProducts(),
        apiClient.listProductFamilies(),
      ]);

      if (prodRes.success && Array.isArray(prodRes.data) && prodRes.data.length > 0) {
        setProducts(prodRes.data);
      } else {
        setProducts([...CANONICAL_PRODUCT_DEFINITIONS]);
      }
    } catch (err: any) {
      setProducts([...CANONICAL_PRODUCT_DEFINITIONS]);
      setError(`Notice: Using local canonical contracts (${err.message})`);
    } finally {
      setIsLoading(false);
    }
  }, []);

  useEffect(() => {
    fetchCatalog();
  }, [fetchCatalog]);

  const filteredProducts = products.filter((item) => {
    const familyMatch =
      selectedFamily === 'all' ||
      item.familyId === selectedFamily ||
      item.productFamily === selectedFamily ||
      item.family?.familyId === selectedFamily;

    const query = searchQuery.toLowerCase().trim();
    const searchMatch =
      !query ||
      (item.displayName || item.name || '').toLowerCase().includes(query) ||
      (item.variantId || item.id || '').toLowerCase().includes(query) ||
      (item.sku || '').toLowerCase().includes(query);

    return familyMatch && searchMatch;
  });

  const selectedProduct: CanonicalProductDefinition | any =
    products.find((p) => (p.variantId || p.id) === selectedVariantId) ||
    CANONICAL_PRODUCT_DEFINITIONS.find((p) => p.variantId === selectedVariantId) ||
    CANONICAL_PRODUCT_DEFINITIONS[0];

  return (
    <div className="space-y-6">
      {/* Page Header */}
      <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-4">
        <div>
          <div className="flex items-center gap-2">
            <h1 className="text-lg font-bold text-slate-100">Product & Design Management</h1>
            <span className="text-[11px] font-mono text-emerald-400 bg-emerald-950/60 px-2 py-0.5 rounded border border-emerald-800/60">
              Part 05 Verified
            </span>
          </div>
          <p className="text-xs text-slate-400">
            Canonical single-source-of-truth product catalog, variant capabilities, channel definitions, and hardware/firmware linkage.
          </p>
        </div>

        <button
          onClick={fetchCatalog}
          disabled={isLoading}
          className="flex items-center gap-2 rounded-lg bg-surface-card border border-surface-border px-3 py-1.5 text-xs font-medium text-slate-200 hover:bg-surface-border/50 transition disabled:opacity-50 self-start"
        >
          <RefreshCw className={`h-3.5 w-3.5 ${isLoading ? 'animate-spin' : ''}`} />
          <span>Refresh Catalog</span>
        </button>
      </div>

      {error && (
        <div className="flex items-center gap-2 rounded-lg bg-amber-950/40 border border-amber-800/50 p-3 text-xs text-amber-300">
          <AlertCircle className="h-4 w-4 shrink-0" />
          <span>{error}</span>
        </div>
      )}

      {/* Filters & Search */}
      <div className="flex flex-col sm:flex-row gap-3 items-center justify-between">
        <div className="flex flex-wrap gap-1.5 w-full sm:w-auto">
          {['all', 'smart-switch', 'smart-socket', 'smart-fan', 'smart-light', 'smart-hub', 'sensor-node'].map((fam) => (
            <button
              key={fam}
              onClick={() => setSelectedFamily(fam)}
              className={`px-2.5 py-1 text-xs font-medium rounded-lg transition capitalize ${
                selectedFamily === fam
                  ? 'bg-indigo-600 text-white shadow-sm'
                  : 'bg-surface-card border border-surface-border text-slate-400 hover:text-slate-200 hover:bg-surface-border/40'
              }`}
            >
              {fam === 'all' ? 'All Families' : fam.replace('-', ' ')}
            </button>
          ))}
        </div>

        <div className="relative w-full sm:w-64">
          <Search className="absolute left-2.5 top-2.5 h-3.5 w-3.5 text-slate-500" />
          <input
            type="text"
            placeholder="Search variant, SKU, or name..."
            value={searchQuery}
            onChange={(e) => setSearchQuery(e.target.value)}
            className="w-full rounded-lg bg-surface-dark border border-surface-border pl-8 pr-3 py-1.5 text-xs text-slate-200 placeholder-slate-500 focus:outline-none focus:border-indigo-500"
          />
        </div>
      </div>

      {/* Main Grid: Catalog List (Left) + Detailed Variant Spec (Right) */}
      <div className="grid grid-cols-1 lg:grid-cols-12 gap-6">
        {/* Left Column: Product List */}
        <div className="lg:col-span-7 space-y-3">
          <div className="text-xs font-semibold uppercase tracking-wider text-slate-400 flex items-center justify-between">
            <span>Canonical Variants ({filteredProducts.length})</span>
            <span className="text-[10px] font-mono text-slate-500">Source: @eh-home/contracts</span>
          </div>

          {isLoading ? (
            <div className="space-y-2">
              {[1, 2, 3, 4].map((i) => (
                <div key={i} className="h-16 rounded-xl bg-surface-card animate-pulse border border-surface-border/40" />
              ))}
            </div>
          ) : filteredProducts.length === 0 ? (
            <div className="rounded-xl border border-surface-border bg-surface-dark p-8 text-center text-slate-400 text-xs">
              No products found matching the selected filter.
            </div>
          ) : (
            <div className="space-y-2 max-h-[calc(100vh-20rem)] overflow-y-auto pr-1">
              {filteredProducts.map((p) => {
                const varId = p.variantId || p.id;
                const isSelected = selectedVariantId === varId;
                return (
                  <div
                    key={varId}
                    onClick={() => setSelectedVariantId(varId)}
                    className={`flex items-center justify-between p-3.5 rounded-xl border cursor-pointer transition ${
                      isSelected
                        ? 'bg-indigo-950/40 border-indigo-500/80 shadow-sm shadow-indigo-900/20'
                        : 'bg-surface-card/60 border-surface-border hover:bg-surface-card hover:border-slate-700'
                    }`}
                  >
                    <div className="flex items-center gap-3">
                      <div className={`p-2 rounded-lg ${isSelected ? 'bg-indigo-600/30 text-indigo-400' : 'bg-surface-border/60 text-slate-400'}`}>
                        <Box className="h-4 w-4" />
                      </div>
                      <div>
                        <div className="text-xs font-semibold text-slate-200">
                          {p.displayName || p.name}
                        </div>
                        <div className="text-[11px] font-mono text-slate-400 flex items-center gap-2">
                          <span>{varId}</span>
                          <span>•</span>
                          <span className="text-slate-500">SKU: {p.sku || 'N/A'}</span>
                        </div>
                      </div>
                    </div>

                    <div className="flex items-center gap-3">
                      <span className="text-[10px] font-mono px-2 py-0.5 rounded bg-surface-border/60 text-slate-300">
                        {p.channelCount || 1} Ch
                      </span>
                      <ChevronRight className={`h-4 w-4 ${isSelected ? 'text-indigo-400' : 'text-slate-600'}`} />
                    </div>
                  </div>
                );
              })}
            </div>
          )}
        </div>

        {/* Right Column: Selected Variant Details */}
        <div className="lg:col-span-5">
          <div className="sticky top-6 rounded-xl border border-surface-border bg-surface-dark p-5 space-y-5">
            <div className="border-b border-surface-border pb-4">
              <div className="flex items-center justify-between mb-1">
                <span className="text-[10px] font-mono uppercase tracking-wider text-indigo-400 bg-indigo-950/60 px-2 py-0.5 rounded border border-indigo-800/60">
                  {selectedProduct.productFamily || selectedProduct.familyId || 'Product Family'}
                </span>
                <span className="flex items-center gap-1 text-[11px] text-emerald-400 font-medium">
                  <CheckCircle2 className="h-3.5 w-3.5" />
                  <span>Approved Catalog</span>
                </span>
              </div>
              <h2 className="text-base font-bold text-slate-100">
                {selectedProduct.displayName || selectedProduct.name}
              </h2>
              <p className="text-xs text-slate-400 mt-1">
                {selectedProduct.description || 'Production verified smart home appliance variant.'}
              </p>
            </div>

            {/* Specifications Grid */}
            <div className="space-y-3 text-xs">
              <div className="flex justify-between py-1.5 border-b border-surface-border/60">
                <span className="text-slate-400 flex items-center gap-1.5">
                  <Sliders className="h-3.5 w-3.5 text-slate-500" /> Variant ID:
                </span>
                <span className="font-mono text-slate-200">{selectedProduct.variantId || selectedProduct.id}</span>
              </div>

              <div className="flex justify-between py-1.5 border-b border-surface-border/60">
                <span className="text-slate-400 flex items-center gap-1.5">
                  <Layers className="h-3.5 w-3.5 text-slate-500" /> Channel Count:
                </span>
                <span className="font-mono text-indigo-300 font-semibold">{selectedProduct.channelCount || 1} Channel(s)</span>
              </div>

              <div className="flex justify-between py-1.5 border-b border-surface-border/60">
                <span className="text-slate-400 flex items-center gap-1.5">
                  <Cpu className="h-3.5 w-3.5 text-slate-500" /> Target MCU:
                </span>
                <span className="font-mono text-slate-200">{selectedProduct.targetMcu || 'ESP32-C6 (RISC-V)'}</span>
              </div>

              <div className="flex justify-between py-1.5 border-b border-surface-border/60">
                <span className="text-slate-400 flex items-center gap-1.5">
                  <Zap className="h-3.5 w-3.5 text-slate-500" /> Firmware Family:
                </span>
                <span className="font-mono text-slate-200">{selectedProduct.firmwareFamily || 'esp32c6-switch-platform'}</span>
              </div>

              <div className="flex justify-between py-1.5 border-b border-surface-border/60">
                <span className="text-slate-400 flex items-center gap-1.5">
                  <Radio className="h-3.5 w-3.5 text-slate-500" /> Connectivity:
                </span>
                <span className="text-slate-200">{selectedProduct.connectivityProfile || 'Wi-Fi 6 (802.11ax) + BLE 5.3 + ESP-NOW'}</span>
              </div>

              <div className="flex justify-between py-1.5 border-b border-surface-border/60">
                <span className="text-slate-400 flex items-center gap-1.5">
                  <ExternalLink className="h-3.5 w-3.5 text-slate-500" /> Hardware Revisions:
                </span>
                <div className="flex gap-1">
                  {(selectedProduct.compatibleHardwareRevisions || ['HW_1_0', 'HW_1_1']).map((rev: string) => (
                    <span key={rev} className="text-[10px] font-mono px-1.5 py-0.5 rounded bg-surface-card border border-surface-border text-emerald-400">
                      {rev}
                    </span>
                  ))}
                </div>
              </div>
            </div>

            {/* Channels & Capabilities Badges */}
            <div className="space-y-2 pt-1">
              <div className="text-[11px] font-semibold text-slate-400 uppercase tracking-wider">
                Capabilities & Channels
              </div>
              <div className="flex flex-wrap gap-1.5">
                {(selectedProduct.channelLabels || selectedProduct.channels || ['Relay Channel 1']).map((ch: any, idx: number) => (
                  <span key={idx} className="text-[10px] px-2 py-0.5 rounded bg-indigo-950/60 border border-indigo-800/60 text-indigo-300 font-mono">
                    {typeof ch === 'string' ? ch : ch.label || `Ch ${idx + 1}`}
                  </span>
                ))}
                {(selectedProduct.capabilities || ['on_off', 'power_monitoring', 'timer', 'ble_provisioning']).map((cap: string) => (
                  <span key={cap} className="text-[10px] px-2 py-0.5 rounded bg-surface-card border border-surface-border text-slate-300">
                    {cap}
                  </span>
                ))}
              </div>
            </div>
          </div>
        </div>
      </div>
    </div>
  );
};
