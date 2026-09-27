/**
 * EH Home Desktop Shell Root Component
 * Coordinates Header, Sidebar, Active Domain View, StatusFooter, and ErrorBoundary.
 * Reconciles all platform domain views (Parts 04–11).
 */

import React from 'react';
import { AppStateProvider, useAppState } from './state/app-state';
import { ErrorBoundary } from './components/ErrorBoundary';
import { Header } from './components/Header';
import { Sidebar } from './components/Sidebar';
import { StatusFooter } from './components/StatusFooter';
import { DashboardView } from './features/dashboard/DashboardView';
import { ProductsView } from './features/products/ProductsView';
import { HardwareBomView } from './features/hardware/HardwareBomView';
import { FirmwareReleasesView } from './features/firmware/FirmwareReleasesView';
import { ProvisionerView } from './features/provisioner/ProvisionerView';
import { LabelPrinterView } from './features/label-printer/LabelPrinterView';
import { DeviceFleetView } from './features/devices/DeviceFleetView';
import { ProductionQcView } from './features/production/ProductionQcView';
import { ProductionPackingView } from './features/packing/ProductionPackingView';
import { InventoryView } from './features/inventory/InventoryView';
import { SettingsView } from './features/settings/SettingsView';
import { PlaceholderView } from './features/placeholders/PlaceholderView';

const ShellContent: React.FC = () => {
  const { activeTab } = useAppState();

  const renderActiveView = () => {
    switch (activeTab) {
      case 'dashboard':
        return <DashboardView />;
      case 'products':
        return <ProductsView />;
      case 'hardware':
        return <HardwareBomView />;
      case 'firmware':
        return <FirmwareReleasesView />;
      case 'provisioner':
        return <ProvisionerView />;
      case 'labels':
        return <LabelPrinterView />;
      case 'devices':
        return <DeviceFleetView />;
      case 'production':
        return <ProductionQcView />;
      case 'packing':
        return <ProductionPackingView />;
      case 'inventory':
        return <InventoryView />;
      case 'settings':
        return <SettingsView />;
      default:
        return <PlaceholderView tab={activeTab} />;
    }
  };

  return (
    <div className="flex h-screen w-screen flex-col overflow-hidden bg-surface-darker">
      <Header />
      <div className="flex flex-1 overflow-hidden">
        <Sidebar />
        <main className="flex-1 overflow-y-auto p-6">
          {renderActiveView()}
        </main>
      </div>
      <StatusFooter />
    </div>
  );
};

export const App: React.FC = () => {
  return (
    <ErrorBoundary>
      <AppStateProvider>
        <ShellContent />
      </AppStateProvider>
    </ErrorBoundary>
  );
};

export default App;
