import React from 'react';

export const LoadingState: React.FC<{ message?: string }> = ({ message = 'Loading Workbench Domain...' }) => {
  return (
    <div className="flex h-64 w-full flex-col items-center justify-center gap-3 select-none">
      <div className="relative h-10 w-10 flex items-center justify-center">
        <svg className="h-full w-full animate-spin" viewBox="0 0 100 100">
          <defs>
            <linearGradient id="goldSpinGrad" x1="0%" y1="100%" x2="0%" y2="0%">
              <stop offset="0%" stopColor="#DCAE45" />
              <stop offset="50%" stopColor="#F7C852" />
              <stop offset="100%" stopColor="#DCAE45" />
            </linearGradient>
          </defs>
          <path d="M 50 90 A 40 40 0 0 1 50 10" fill="none" stroke="url(#goldSpinGrad)" strokeWidth="4" strokeLinecap="round" />
          <path d="M 50 10 A 40 40 0 0 1 50 90" fill="none" stroke="#DCAE45" strokeWidth="2.5" strokeDasharray="3 6" strokeOpacity="0.5" strokeLinecap="round" />
          <circle cx="50" cy="10" r="4.5" fill="#F7C852" />
        </svg>
      </div>
      <span className="text-xs font-mono text-[#9D9D9D]">{message}</span>
    </div>
  );
};

