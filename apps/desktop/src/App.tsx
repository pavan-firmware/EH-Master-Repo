/**
 * EH Home Desktop Shell Root Component
 * Coordinates Titlebar Header, Explorer Sidebar, Active Domain View, StatusFooter, and ErrorBoundary.
 * VS Code-style engineering workbench layout.
 */

import React from 'react';
import { AppStateProvider, useAppState } from './state/app-state';
import { ErrorBoundary } from './components/ErrorBoundary';
import { Header } from './components/Header';
import { Sidebar } from './components/Sidebar';
import { StatusFooter } from './components/StatusFooter';
import { DashboardView } from './features/dashboard/DashboardView';
import { RepositoriesView } from './features/repositories/RepositoriesView';
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
import { SystemSetupWizardView } from './features/setup/SystemSetupWizardView';
import { PlaceholderView } from './features/placeholders/PlaceholderView';
import { ProvisioningTerminalWindow } from './features/provisioner/ProvisioningTerminalWindow';

import { StartupSplash } from './components/StartupSplash';

const ShellContent: React.FC = () => {
  const { activeTab } = useAppState();

  const isKnownTab = [
    'dashboard',
    'setup',
    'repositories',
    'products',
    'hardware',
    'firmware',
    'provisioner',
    'labels',
    'devices',
    'production',
    'packing',
    'inventory',
    'settings',
  ].includes(activeTab);

  return (
    <div className="flex h-screen w-screen flex-col overflow-hidden bg-[#1E1E1E] text-[#CCCCCC] font-sans antialiased select-none">
      <Header />
      <div className="flex flex-1 overflow-hidden">
        <Sidebar />
        <main className="flex-1 overflow-hidden bg-[#1E1E1E] relative">
          <div className={`h-full w-full overflow-y-auto p-4 ${activeTab === 'dashboard' ? 'block' : 'hidden'}`}>
            <DashboardView />
          </div>
          <div className={`h-full w-full overflow-y-auto p-4 ${activeTab === 'setup' ? 'block' : 'hidden'}`}>
            <SystemSetupWizardView />
          </div>
          <div className={`h-full w-full overflow-y-auto p-4 ${activeTab === 'repositories' ? 'block' : 'hidden'}`}>
            <RepositoriesView />
          </div>
          <div className={`h-full w-full overflow-y-auto p-4 ${activeTab === 'products' ? 'block' : 'hidden'}`}>
            <ProductsView />
          </div>
          <div className={`h-full w-full overflow-y-auto p-4 ${activeTab === 'hardware' ? 'block' : 'hidden'}`}>
            <HardwareBomView />
          </div>
          <div className={`h-full w-full overflow-y-auto p-4 ${activeTab === 'firmware' ? 'block' : 'hidden'}`}>
            <FirmwareReleasesView />
          </div>
          <div className={`h-full w-full overflow-y-auto p-4 ${activeTab === 'provisioner' ? 'block' : 'hidden'}`}>
            <ProvisionerView />
          </div>
          <div className={`h-full w-full overflow-y-auto p-4 ${activeTab === 'labels' ? 'block' : 'hidden'}`}>
            <LabelPrinterView />
          </div>
          <div className={`h-full w-full overflow-y-auto p-4 ${activeTab === 'devices' ? 'block' : 'hidden'}`}>
            <DeviceFleetView />
          </div>
          <div className={`h-full w-full overflow-y-auto p-4 ${activeTab === 'production' ? 'block' : 'hidden'}`}>
            <ProductionQcView />
          </div>
          <div className={`h-full w-full overflow-y-auto p-4 ${activeTab === 'packing' ? 'block' : 'hidden'}`}>
            <ProductionPackingView />
          </div>
          <div className={`h-full w-full overflow-y-auto p-4 ${activeTab === 'inventory' ? 'block' : 'hidden'}`}>
            <InventoryView />
          </div>
          <div className={`h-full w-full overflow-y-auto p-4 ${activeTab === 'settings' ? 'block' : 'hidden'}`}>
            <SettingsView />
          </div>
          {!isKnownTab && (
            <div className="h-full w-full overflow-y-auto p-4 block">
              <PlaceholderView tab={activeTab} />
            </div>
          )}
        </main>
      </div>
      <StatusFooter />
    </div>
  );
};

export const App: React.FC<{ skipSplash?: boolean }> = ({ skipSplash = false }) => {
  const queryWindow = typeof window !== 'undefined'
    ? new URLSearchParams(window.location.search).get('window')
    : null;
  const isTerminalHash = typeof window !== 'undefined' && (
    window.location.hash.includes('terminal') ||
    window.location.pathname.includes('terminal')
  );
  const isTerminalInitial = queryWindow === 'provisioning-terminal' || isTerminalHash || (
    typeof window !== 'undefined' && (
      (window as any).__TAURI_INTERNALS__?.metadata?.currentWindow?.label === 'provisioning-terminal' ||
      (window as any).__TAURI_INTERNALS__?.metadata?.currentWebview?.label === 'provisioning-terminal'
    )
  );

  const [nativeWindowLabel, setNativeWindowLabel] = React.useState<string>(
    isTerminalInitial ? 'provisioning-terminal' : 'main'
  );

  React.useEffect(() => {
    let active = true;
    if (typeof window !== 'undefined' && (window as any).__TAURI_INTERNALS__) {
      import('@tauri-apps/api/webviewWindow')
        .then(({ getCurrentWebviewWindow }) => {
          if (active) {
            const win = getCurrentWebviewWindow();
            if (win && win.label) setNativeWindowLabel(win.label);
          }
        })
        .catch(() => {
          import('@tauri-apps/api/window')
            .then(({ getCurrentWindow }) => {
              if (active) {
                const win = getCurrentWindow();
                if (win && win.label) setNativeWindowLabel(win.label);
              }
            })
            .catch(() => {});
        });
    }
    return () => { active = false; };
  }, [isTerminalInitial]);

  if (nativeWindowLabel === 'provisioning-terminal' || isTerminalInitial || queryWindow === 'provisioning-terminal') {
    return <ProvisioningTerminalWindow />;
  }
  const [showSplash, setShowSplash] = React.useState(!skipSplash);

  return (
    <ErrorBoundary>
      <AppStateProvider>
        {showSplash && (
          <StartupSplash
            onComplete={() => setShowSplash(false)}
            durationMs={3000}
          />
        )}
        <ShellContent />
      </AppStateProvider>
    </ErrorBoundary>
  );
};

export default App;
