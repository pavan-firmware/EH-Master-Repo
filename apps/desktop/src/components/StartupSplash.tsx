import React, { useEffect, useState } from 'react';

interface StartupSplashProps {
  onComplete: () => void;
  durationMs?: number;
}

export const StartupSplash: React.FC<StartupSplashProps> = ({
  onComplete,
  durationMs = 3000,
}) => {
  const [elapsed, setElapsed] = useState(0);
  const [isFadingOut, setIsFadingOut] = useState(false);

  useEffect(() => {
    const startTime = Date.now();
    const interval = setInterval(() => {
      const current = Date.now() - startTime;
      setElapsed(current);
      if (current >= durationMs - 300 && !isFadingOut) {
        setIsFadingOut(true);
      }
      if (current >= durationMs) {
        clearInterval(interval);
        onComplete();
      }
    }, 16);

    return () => clearInterval(interval);
  }, [durationMs, onComplete, isFadingOut]);

  // Normalized progress 0.0 -> 1.0 across 3000ms
  const t = Math.min(Math.max(elapsed / durationMs, 0), 1);

  // Sequential timeline matching Flutter mobile splash_screen.dart
  const calcBell = (start: number, end: number) => {
    if (t < start || t > end) return 0;
    const mid = (start + end) / 2;
    const half = (end - start) / 2;
    const dist = Math.abs(t - mid) / half;
    return Math.max(0, 1 - dist * dist);
  };

  const bulbOpacity = calcBell(0.18, 0.35);
  const fanOpacity = calcBell(0.33, 0.48);
  const fanAngle = (t >= 0.33 && t <= 0.48 ? (t - 0.33) / 0.15 : 0) * 360 * 3;
  const socketOpacity = calcBell(0.46, 0.60);
  const thermoOpacity = calcBell(0.58, 0.71);
  const lockOpacity = calcBell(0.69, 0.80);
  const homeWifiOpacity = t < 0.76 ? (t < 0.18 ? 1 : 0) : Math.min((t - 0.76) / 0.14, 1);

  return (
    <div
      className={`fixed inset-0 z-50 flex items-center justify-center bg-[#090D14] select-none transition-opacity duration-300 ${
        isFadingOut ? 'opacity-0 pointer-events-none' : 'opacity-100'
      }`}
      style={{ backgroundColor: '#090D14' }}
    >
      {/* Centered Phone Screen Frame matching reference 853x1844 aspect ratio */}
      <div className="relative h-full max-h-screen aspect-[853/1844] flex items-center justify-center overflow-hidden">
        {/* Authoritative mobile app startup image */}
        <img
          src="/branding/app_startup_without_loading.png"
          alt="EH Home Startup"
          className="absolute inset-0 w-full h-full object-contain pointer-events-none"
          onError={(e) => {
            (e.target as HTMLImageElement).src = '/branding/startup_animation_image.png';
          }}
        />

        {/* Precision Positioned Animated Ring Layer */}
        {/* Center: X = 50.64%, Y = 67.70%, Diameter = 36.34% of container width */}
        <div
          className="absolute flex items-center justify-center"
          style={{
            left: '50.64%',
            top: '67.70%',
            width: '36.34%',
            height: '36.34%',
            transform: 'translate(-50%, -50%)',
          }}
        >
          {/* Animated Gold Ring */}
          <svg
            className="w-full h-full animate-[spin_2.2s_linear_infinite]"
            viewBox="0 0 100 100"
            style={{ filter: 'drop-shadow(0 0 12px rgba(247, 200, 82, 0.45))' }}
          >
            <defs>
              <linearGradient id="mobileGoldArcGrad" x1="0%" y1="100%" x2="0%" y2="0%">
                <stop offset="0%" stopColor="#DCAE45" />
                <stop offset="50%" stopColor="#F7C852" />
                <stop offset="100%" stopColor="#DCAE45" />
              </linearGradient>
            </defs>

            {/* Left Solid Glowing Gold Arc */}
            <path
              d="M 50 94 A 44 44 0 0 1 50 6"
              fill="none"
              stroke="url(#mobileGoldArcGrad)"
              strokeWidth="3.6"
              strokeLinecap="round"
            />

            {/* Right Dashed Stepping Gold Ticks */}
            <path
              d="M 50 6 A 44 44 0 0 1 50 94"
              fill="none"
              stroke="#DCAE45"
              strokeWidth="2.2"
              strokeDasharray="2.5 5.5"
              strokeOpacity="0.55"
              strokeLinecap="round"
            />

            {/* Orbiting Gold Head Dot */}
            <circle cx="50" cy="6" r="4.5" fill="#F7C852" />
            <circle cx="50" cy="6" r="8" fill="#F7C852" opacity="0.35" />
          </svg>

          {/* Sequential Center Device Icons (Strictly in the exact center) */}
          <div className="absolute inset-0 flex items-center justify-center pointer-events-none">
            {/* 1. Bulb */}
            {bulbOpacity > 0.05 && (
              <svg
                className="w-[45%] h-[45%] text-[#F7C852] absolute transition-opacity duration-150"
                style={{ opacity: bulbOpacity }}
                viewBox="0 0 24 24"
                fill="none"
                stroke="currentColor"
                strokeWidth="1.8"
                strokeLinecap="round"
                strokeLinejoin="round"
              >
                <path d="M9 18h6" />
                <path d="M10 22h4" />
                <path d="M12 2a7 7 0 0 0-7 7c0 2.5 1.5 4.7 3.5 6h7c2-1.3 3.5-3.5 3.5-6a7 7 0 0 0-7-7z" />
              </svg>
            )}

            {/* 2. Fan */}
            {fanOpacity > 0.05 && (
              <svg
                className="w-[45%] h-[45%] text-[#F7C852] absolute transition-opacity duration-150"
                style={{ opacity: fanOpacity, transform: `rotate(${fanAngle}deg)` }}
                viewBox="0 0 24 24"
                fill="none"
                stroke="currentColor"
                strokeWidth="1.8"
                strokeLinecap="round"
                strokeLinejoin="round"
              >
                <circle cx="12" cy="12" r="2.5" />
                <path d="M12 9.5c0-4 3-5.5 5-5.5s1.5 3-1.5 5-3.5.5-3.5.5z" />
                <path d="M9.5 12c-4 0-5.5-3-5.5-5s3-1.5 5 1.5.5 3.5.5 3.5z" />
                <path d="M14.5 12c4 0 5.5 3 5.5 5s-3 1.5-5-1.5-.5-3.5-.5-3.5z" />
                <path d="M12 14.5c0 4-3 5.5-5 5.5s-1.5-3 1.5-5 3.5-.5 3.5-.5z" />
              </svg>
            )}

            {/* 3. Socket */}
            {socketOpacity > 0.05 && (
              <svg
                className="w-[45%] h-[45%] text-[#F7C852] absolute transition-opacity duration-150"
                style={{ opacity: socketOpacity }}
                viewBox="0 0 24 24"
                fill="none"
                stroke="currentColor"
                strokeWidth="1.8"
                strokeLinecap="round"
                strokeLinejoin="round"
              >
                <circle cx="12" cy="12" r="9" />
                <line x1="9" y1="10" x2="9" y2="13" />
                <line x1="15" y1="10" x2="15" y2="13" />
                <circle cx="12" cy="16" r="1" fill="#F7C852" />
              </svg>
            )}

            {/* 4. Temperature */}
            {thermoOpacity > 0.05 && (
              <svg
                className="w-[45%] h-[45%] text-[#F7C852] absolute transition-opacity duration-150"
                style={{ opacity: thermoOpacity }}
                viewBox="0 0 24 24"
                fill="none"
                stroke="currentColor"
                strokeWidth="1.8"
                strokeLinecap="round"
                strokeLinejoin="round"
              >
                <path d="M14 14.76V3.5a2.5 2.5 0 0 0-5 0v11.26a4.5 4.5 0 1 0 5 0z" />
              </svg>
            )}

            {/* 5. Lock */}
            {lockOpacity > 0.05 && (
              <svg
                className="w-[45%] h-[45%] text-[#F7C852] absolute transition-opacity duration-150"
                style={{ opacity: lockOpacity }}
                viewBox="0 0 24 24"
                fill="none"
                stroke="currentColor"
                strokeWidth="1.8"
                strokeLinecap="round"
                strokeLinejoin="round"
              >
                <rect x="5" y="11" width="14" height="10" rx="2" />
                <path d="M7 11V7a5 5 0 0 1 10 0v4" />
              </svg>
            )}

            {/* 6. Home + Wi-Fi (Final Connected State) */}
            {homeWifiOpacity > 0.05 && (
              <svg
                className="w-[50%] h-[50%] text-[#F7C852] absolute transition-opacity duration-200"
                style={{
                  opacity: homeWifiOpacity,
                  filter: 'drop-shadow(0 0 8px rgba(247, 200, 82, 0.6))',
                }}
                viewBox="0 0 24 24"
                fill="none"
                stroke="currentColor"
                strokeWidth="1.8"
                strokeLinecap="round"
                strokeLinejoin="round"
              >
                <path d="M3 9l9-7 9 7v11a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2z" />
                <polyline points="9 22 9 12 15 12 15 22" />
                <path d="M12 7.5a2.5 2.5 0 0 1 2.5 2.5" strokeWidth="1.4" />
                <path d="M12 5a5 5 0 0 1 5 5" strokeWidth="1.4" />
              </svg>
            )}
          </div>
        </div>
      </div>
    </div>
  );
};
