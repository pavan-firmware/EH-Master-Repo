/**
 * Generic Domain Placeholder View
 * Implements Step 4: clearly non-functional placeholder screen for future areas.
 */

import React from 'react';
import { Construction } from 'lucide-react';
import { NavigationTab } from '../../state/app-state';

interface Props {
  tab: NavigationTab;
}

const TAB_METADATA: Record<NavigationTab, { title: string; phase: string; description: string }> = {
  dashboard: { title: 'Dashboard', phase: 'Part 04', description: 'System health & foundation.' },
  products: { title: 'Product Catalog Management', phase: 'Part 05', description: 'Product masters, variants, channel definitions, and catalog metadata.' },
  hardware: { title: 'Hardware & BOM Management', phase: 'Part 06', description: 'PCB revisions, component BOM specs, and Gerber checksums.' },
  firmware: { title: 'Firmware & OTA Releases', phase: 'Part 07', description: 'Release management, artifact signatures, and compatibility matrices.' },
  provisioner: { title: 'ESP32 Bench Provisioner', phase: 'Part 09', description: 'Bench provisioning workflow, serial flashing, and identity injection.' },
  labels: { title: 'QR & Thermal Label Printing', phase: 'Part 10', description: 'Deterministic TSPL and ESC/POS thermal label generation and printing.' },
  devices: { title: 'Device Fleet Management', phase: 'Part 08', description: 'Provisioned device inventory, identity verification, and status monitoring.' },
  production: { title: 'Production Batches & QC', phase: 'Part 09', description: 'Batch scheduling, flashing workflows, and QC station pass/fail logs.' },
  packing: { title: 'Packing & Dual-Scan Verification', phase: 'Part 10', description: 'Dual-scan enforcement, serial mismatch rejection, and box sealing.' },
  inventory: { title: 'Finished Goods Inventory', phase: 'Part 11', description: 'Warehouse stock tracking, transfers, and shipment allocations.' },
  settings: { title: 'Workbench Settings', phase: 'Part 12', description: 'Serial port selection, printer driver calibration, and API keys.' },
};

export const PlaceholderView: React.FC<Props> = ({ tab }) => {
  const meta = TAB_METADATA[tab] || {
    title: 'Domain Area',
    phase: 'Future Part',
    description: 'This module is scheduled for future implementation.',
  };

  return (
    <div className="flex flex-col items-center justify-center p-12 text-center h-[calc(100vh-14rem)]">
      <div className="flex h-14 w-14 items-center justify-center rounded-2xl bg-surface-card border border-surface-border text-indigo-400 mb-4 shadow-sm">
        <Construction className="h-7 w-7" />
      </div>
      <span className="text-[11px] font-mono text-indigo-400 bg-indigo-950/60 px-2.5 py-0.5 rounded-full border border-indigo-800/60 mb-2">
        Scheduled for {meta.phase}
      </span>
      <h2 className="text-base font-bold text-slate-100 mb-1">{meta.title}</h2>
      <p className="text-xs text-slate-400 max-w-md">{meta.description}</p>
      <div className="mt-6 text-[11px] text-slate-400 font-mono">
        Architectural domain boundary established in Part 00. Implementation deferred by design.
      </div>
    </div>
  );
};
