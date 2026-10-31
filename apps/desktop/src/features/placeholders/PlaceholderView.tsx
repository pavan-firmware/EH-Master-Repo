/**
 * Generic Domain Placeholder View
 * VS Code-style engineering workbench placeholder for future extension areas.
 */

import React from 'react';
import { Construction } from 'lucide-react';
import { NavigationTab } from '../../state/app-state';

interface Props {
  tab: NavigationTab;
}

const TAB_METADATA: Record<NavigationTab, { title: string; phase: string; description: string }> = {
  dashboard: { title: 'Dashboard & Telemetry', phase: 'Part 04', description: 'System health & foundation.' },
  setup: { title: 'System Setup & Requirement Diagnostics', phase: 'First-Run', description: 'Host hardware discovery, Python flasher validation, and station configuration.' },
  repositories: { title: 'Source Control & Repositories', phase: 'Part 14', description: 'GitHub master repository and local source workspace.' },
  products: { title: 'Product Catalog Management', phase: 'Part 05', description: 'Product masters, variants, channel definitions, and catalog metadata.' },
  hardware: { title: 'Hardware & BOM Management', phase: 'Part 06', description: 'PCB revisions, component BOM specs, and Gerber checksums.' },
  firmware: { title: 'Firmware & Releases', phase: 'Part 07', description: 'Release management, artifact signatures, and compatibility matrices.' },
  provisioner: { title: 'ESP32 Bench Provisioner', phase: 'Part 09', description: 'Bench provisioning workflow, serial flashing, and identity injection.' },
  labels: { title: 'QR & Thermal Label Printing', phase: 'Part 10', description: 'Deterministic TSPL, ESC/POS, and PDF virtual document generation.' },
  devices: { title: 'Device Fleet Inventory', phase: 'Part 08/11', description: 'Provisioned device inventory, identity verification, and status monitoring.' },
  production: { title: 'Production Batches & QC', phase: 'Part 09/11', description: 'Batch scheduling, flashing workflows, and QC station pass/fail logs.' },
  packing: { title: 'Packing & Dual-Scan Verification', phase: 'Part 11', description: 'Dual-scan enforcement, serial mismatch rejection, and box sealing.' },
  inventory: { title: 'Finished Goods Inventory', phase: 'Part 11', description: 'Warehouse stock tracking, transfers, and shipment allocations.' },
  settings: { title: 'Workbench Settings', phase: 'System', description: 'Serial port selection, printer driver calibration, and endpoint configuration.' },
};

export const PlaceholderView: React.FC<Props> = ({ tab }) => {
  const meta = TAB_METADATA[tab] || {
    title: 'Domain Area',
    phase: 'Future Extension',
    description: 'This module is scheduled for future implementation.',
  };

  return (
    <div className="flex flex-col items-center justify-center p-12 text-center h-[calc(100vh-12rem)] font-sans">
      <div className="flex h-12 w-12 items-center justify-center rounded bg-[#252526] border border-[#3C3C3C] text-[#007ACC] mb-3 shadow-sm">
        <Construction className="h-6 w-6" />
      </div>
      <span className="text-[10px] font-mono text-[#007ACC] bg-[#007ACC]/10 px-2 py-0.5 rounded border border-[#007ACC]/30 mb-2">
        {meta.phase}
      </span>
      <h2 className="text-sm font-bold text-white mb-1">{meta.title}</h2>
      <p className="text-xs text-[#858585] max-w-md">{meta.description}</p>
      <div className="mt-4 text-[10px] text-[#666666] font-mono">
        Workbench boundary established &bull; Controlled scope
      </div>
    </div>
  );
};
