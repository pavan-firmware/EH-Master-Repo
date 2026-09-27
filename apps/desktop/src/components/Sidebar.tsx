/**
 * Desktop Application Sidebar Navigation
 * Hosts reconciled navigation links across platform lifecycle domains (Parts 04–11).
 */

import React from 'react';
import {
  LayoutDashboard,
  Box,
  Layers,
  FileCode2,
  Radio,
  Factory,
  PackageCheck,
  Warehouse,
  Settings,
  Cpu,
  Printer,
} from 'lucide-react';
import { useAppState, NavigationTab } from '../state/app-state';

interface NavItem {
  id: NavigationTab;
  label: string;
  icon: React.ComponentType<{ className?: string }>;
  partBadge?: string;
}

const NAV_ITEMS: NavItem[] = [
  { id: 'dashboard', label: 'Dashboard', icon: LayoutDashboard, partBadge: 'Part 04' },
  { id: 'products', label: 'Products', icon: Box, partBadge: 'Part 05' },
  { id: 'hardware', label: 'Hardware & BOM', icon: Layers, partBadge: 'Part 06' },
  { id: 'firmware', label: 'Firmware & Releases', icon: FileCode2, partBadge: 'Part 07+' },
  { id: 'provisioner', label: 'Bench Provisioner', icon: Cpu, partBadge: 'Part 09' },
  { id: 'labels', label: 'Label & QR Printer', icon: Printer, partBadge: 'Part 10' },
  { id: 'devices', label: 'Device Fleet', icon: Radio, partBadge: 'Fleet' },
  { id: 'production', label: 'Production & QC', icon: Factory, partBadge: 'QC' },
  { id: 'packing', label: 'Packing & Dual-Scan', icon: PackageCheck, partBadge: 'Part 11' },
  { id: 'inventory', label: 'Inventory', icon: Warehouse, partBadge: 'Stock' },
  { id: 'settings', label: 'Settings', icon: Settings, partBadge: 'Config' },
];

export const Sidebar: React.FC = () => {
  const { activeTab, setActiveTab } = useAppState();

  return (
    <aside className="flex w-60 flex-col border-r border-surface-border bg-surface-dark select-none h-[calc(100vh-3.5rem-2rem)]">
      {/* Navigation List */}
      <nav className="flex-1 space-y-1 p-3 overflow-y-auto">
        <div className="px-3 pb-2 text-[10px] font-semibold uppercase tracking-wider text-slate-400">
          Platform Domains
        </div>
        {NAV_ITEMS.map((item) => {
          const Icon = item.icon;
          const isActive = activeTab === item.id;
          return (
            <button
              key={item.id}
              onClick={() => setActiveTab(item.id)}
              className={`flex w-full items-center justify-between rounded-lg px-3 py-2 text-xs font-medium transition ${
                isActive
                  ? 'bg-indigo-600 text-white shadow-sm shadow-indigo-600/30'
                  : 'text-slate-300 hover:bg-surface-card hover:text-slate-100'
              }`}
            >
              <div className="flex items-center gap-2.5">
                <Icon className={`h-4 w-4 ${isActive ? 'text-white' : 'text-slate-400'}`} />
                <span>{item.label}</span>
              </div>
              {item.partBadge && (
                <span
                  className={`text-[10px] px-1.5 py-0.2 rounded font-mono ${
                    isActive
                      ? 'bg-indigo-700/80 text-white border border-indigo-500/40'
                      : 'bg-surface-border/60 text-slate-400 border border-surface-border/40'
                  }`}
                >
                  {item.partBadge}
                </span>
              )}
            </button>
          );
        })}
      </nav>

      {/* Workspace Footer Info */}
      <div className="border-t border-surface-border p-3 text-[11px] text-slate-400">
        <div className="font-medium text-slate-300">Target Protocol</div>
        <div className="font-mono text-[10px] text-slate-400">eh://p/v1?t=&lt;TOKEN&gt;</div>
      </div>
    </aside>
  );
};
