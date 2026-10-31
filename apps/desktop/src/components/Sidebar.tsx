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
  Sparkles,
  GitBranch,
} from 'lucide-react';
import { useAppState, NavigationTab } from '../state/app-state';

interface NavItem {
  id: NavigationTab;
  label: string;
  icon: React.ComponentType<{ className?: string }>;
}

const NAV_ITEMS: NavItem[] = [
  { id: 'dashboard', label: 'Dashboard', icon: LayoutDashboard },
  { id: 'setup', label: 'System Setup', icon: Sparkles },
  { id: 'repositories', label: 'Repositories & Source', icon: GitBranch },
  { id: 'products', label: 'Products', icon: Box },
  { id: 'hardware', label: 'Hardware & BOM', icon: Layers },
  { id: 'firmware', label: 'Firmware & Releases', icon: FileCode2 },
  { id: 'provisioner', label: 'Bench Provisioner', icon: Cpu },
  { id: 'labels', label: 'Label & QR Printer', icon: Printer },
  { id: 'devices', label: 'Device Fleet', icon: Radio },
  { id: 'production', label: 'Production & QC', icon: Factory },
  { id: 'packing', label: 'Packing & Dual-Scan', icon: PackageCheck },
  { id: 'inventory', label: 'Inventory', icon: Warehouse },
  { id: 'settings', label: 'Settings & Diagnostics', icon: Settings },
];

export const Sidebar: React.FC = () => {
  const { activeTab, setActiveTab } = useAppState();

  return (
    <aside className="flex w-60 flex-col border-r border-[#3C3C3C] bg-[#181818] select-none h-full text-[13px]">
      {/* Sidebar Header */}
      <div className="px-3.5 py-2 text-[11px] font-semibold uppercase tracking-wider text-[#9D9D9D] border-b border-[#2D2D2D]">
        Explorer: Workbench
      </div>

      {/* Navigation List */}
      <nav className="flex-1 space-y-0.5 p-2 overflow-y-auto">
        {NAV_ITEMS.map((item) => {
          const Icon = item.icon;
          const isActive = activeTab === item.id;
          return (
            <button
              key={item.id}
              onClick={() => setActiveTab(item.id)}
              className={`flex w-full items-center justify-between px-3 py-2 rounded text-[13px] transition ${
                isActive
                  ? 'bg-[#37373D] text-white font-medium border-l-2 border-[#007ACC]'
                  : 'text-[#CCCCCC] hover:bg-[#2A2D2E] hover:text-white'
              }`}
            >
              <div className="flex items-center gap-2.5 truncate">
                <Icon className={`h-4 w-4 shrink-0 ${isActive ? 'text-[#007ACC]' : 'text-[#9D9D9D]'}`} />
                <span className="truncate">{item.label}</span>
              </div>
            </button>
          );
        })}
      </nav>

      {/* Sidebar Footer */}
      <div className="border-t border-[#3C3C3C] p-2.5 text-[11px] text-[#808080] font-mono flex items-center justify-between bg-[#141414]">
        <span>PROTOCOL</span>
        <span className="text-[#9D9D9D]">eh://p/v1</span>
      </div>
    </aside>
  );
};


