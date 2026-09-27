/**
 * Application Error Boundary
 * Catches unhandled UI errors gracefully without crashing the desktop shell.
 */

import { Component, ErrorInfo, ReactNode } from 'react';
import { AlertTriangle, RefreshCw } from 'lucide-react';
import { logger } from '../lib/logger';

interface Props {
  children: ReactNode;
}

interface State {
  hasError: boolean;
  errorMessage: string;
}

export class ErrorBoundary extends Component<Props, State> {
  public override state: State = {
    hasError: false,
    errorMessage: '',
  };

  public static getDerivedStateFromError(error: Error): State {
    return {
      hasError: true,
      errorMessage: error.message || 'An unexpected rendering error occurred',
    };
  }

  public override componentDidCatch(error: Error, errorInfo: ErrorInfo): void {
    logger.error('UI rendering exception captured by ErrorBoundary', {
      error: error.message,
      componentStack: errorInfo.componentStack,
    });
  }

  public override render(): ReactNode {
    if (this.state.hasError) {
      return (
        <div className="flex h-screen w-screen flex-col items-center justify-center bg-surface-darker p-8 text-center text-slate-100">
          <div className="mb-4 flex h-16 w-16 items-center justify-center rounded-2xl bg-rose-950/60 border border-rose-800/80 text-rose-400">
            <AlertTriangle className="h-8 w-8" />
          </div>
          <h2 className="mb-2 text-xl font-bold tracking-tight text-slate-100">Application Error</h2>
          <p className="mb-6 max-w-md text-sm text-slate-400">{this.state.errorMessage}</p>
          <button
            onClick={() => window.location.reload()}
            className="flex items-center gap-2 rounded-lg bg-indigo-600 px-4 py-2 text-sm font-semibold text-white shadow-lg shadow-indigo-600/30 transition hover:bg-indigo-500"
          >
            <RefreshCw className="h-4 w-4" />
            Reload Workspace
          </button>
        </div>
      );
    }

    return this.props.children;
  }
}
