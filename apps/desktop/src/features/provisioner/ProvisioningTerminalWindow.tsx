import React, { useEffect, useRef, useState, useMemo } from 'react';
import {
  Terminal,
  Trash2,
  Copy,
  Check,
  ArrowDownCircle,
  XCircle,
  Send,
  RefreshCw,
  Cpu,
  Zap,
} from 'lucide-react';

const LOG_KEY = 'eh_provisioning_terminal_logs_v1';
const SELECTED_PORT_KEY = 'eh_provisioner_selected_port';

export const ProvisioningTerminalWindow: React.FC = () => {
  const [logs, setLogs] = useState<string[]>([]);
  const [searchQuery, setSearchQuery] = useState('');
  const [autoScroll, setAutoScroll] = useState(true);
  const [copied, setCopied] = useState(false);
  const [commandInput, setCommandInput] = useState('');
  const [isSending, setIsSending] = useState(false);
  const [selectedPort, setSelectedPort] = useState<string>(() => {
    try {
      return localStorage.getItem(SELECTED_PORT_KEY) || 'COM6';
    } catch {
      return 'COM6';
    }
  });
  const [baudRate, setBaudRate] = useState<number>(115200);
  const [lineEnding, setLineEnding] = useState<string>('\\r\\n');
  const [history, setHistory] = useState<string[]>([]);
  const [historyIdx, setHistoryIdx] = useState<number>(-1);
  const outputRef = useRef<HTMLDivElement>(null);
  const inputRef = useRef<HTMLInputElement>(null);

  // Poll localStorage & Tauri event stream
  useEffect(() => {
    const readLogs = () => {
      try {
        const value = JSON.parse(localStorage.getItem(LOG_KEY) || '[]');
        if (Array.isArray(value)) setLogs(value);
        const storedPort = localStorage.getItem(SELECTED_PORT_KEY);
        if (storedPort) setSelectedPort(storedPort);
      } catch {
        /* ignore */
      }
    };
    readLogs();
    const timer = window.setInterval(readLogs, 300);

    let unlisten: (() => void) | undefined;
    if (typeof window !== 'undefined' && (window as any).__TAURI_INTERNALS__) {
      import('@tauri-apps/api/event').then(({ listen }) => {
        listen<string>('provisioner-log', (event) => {
          if (event.payload) {
            setLogs((prev) => {
              const next = [...prev, event.payload];
              try {
                localStorage.setItem(LOG_KEY, JSON.stringify(next.slice(-1000)));
              } catch {
                /* ignore */
              }
              return next;
            });
          }
        }).then((un) => {
          unlisten = un;
        });
      });
    }

    return () => {
      window.clearInterval(timer);
      if (unlisten) unlisten();
    };
  }, []);

  useEffect(() => {
    if (autoScroll && outputRef.current) {
      outputRef.current.scrollTop = outputRef.current.scrollHeight;
    }
  }, [logs, autoScroll]);

  const appendTerminalLog = (line: string) => {
    setLogs((prev) => {
      const next = [...prev, line];
      try {
        localStorage.setItem(LOG_KEY, JSON.stringify(next.slice(-1000)));
      } catch {
        /* ignore */
      }
      return next;
    });
  };

  const handleClear = () => {
    setLogs([]);
    try {
      localStorage.setItem(LOG_KEY, '[]');
    } catch {
      /* ignore */
    }
  };

  const handleCopy = async () => {
    try {
      await navigator.clipboard.writeText(logs.join('\n'));
      setCopied(true);
      setTimeout(() => setCopied(false), 2000);
    } catch {
      /* ignore */
    }
  };

  const handleClose = async () => {
    try {
      if (typeof window !== 'undefined' && (window as any).__TAURI_INTERNALS__) {
        const { invoke } = await import('@tauri-apps/api/core');
        await invoke('close_provisioning_terminal_window');
        const { getCurrentWebviewWindow } = await import('@tauri-apps/api/webviewWindow');
        await getCurrentWebviewWindow().close();
      } else {
        window.close();
      }
    } catch {
      window.close();
    }
  };

  const handleSendCommand = async (cmdToSend?: string) => {
    const cmd = (cmdToSend !== undefined ? cmdToSend : commandInput).trim();
    if (!cmd || isSending) return;

    setIsSending(true);
    setCommandInput('');
    setHistory((prev) => [cmd, ...prev.filter((c) => c !== cmd)].slice(0, 50));
    setHistoryIdx(-1);

    const timestamp = new Date().toLocaleTimeString();
    appendTerminalLog(`[${timestamp}] > ${cmd}`);

    try {
      if (typeof window !== 'undefined' && (window as any).__TAURI_INTERNALS__) {
        const { invoke } = await import('@tauri-apps/api/core');
        const res = await invoke<any>('send_serial_command', {
          request: {
            port: selectedPort,
            baud_rate: baudRate,
            serial_cmd: cmd,
            timeout_sec: 1.5,
            line_ending: lineEnding,
          },
        });

        if (res.success && Array.isArray(res.response_lines) && res.response_lines.length > 0) {
          for (const line of res.response_lines) {
            appendTerminalLog(line);
          }
        } else if (res.error_message) {
          appendTerminalLog(`[ERROR] ${res.error_message}`);
        } else {
          appendTerminalLog(`[INFO] Command transmitted to ${selectedPort} (${baudRate} baud). No immediate echo response.`);
        }
      } else {
        // Mock fallback simulation
        setTimeout(() => {
          if (cmd === 'help') {
            appendTerminalLog('Available device commands: help, status, version, reboot, wifi_status, relays_state');
          } else if (cmd === 'status') {
            appendTerminalLog('DEVICE STATUS: OK | Free Heap: 144360 | State: FACTORY_NEW | WiFi: GPONWIFI_BD50');
          } else if (cmd === 'version') {
            appendTerminalLog('EH Smart Switch/Socket 3X Firmware v1.0.0 (ESP-IDF v5.4.1)');
          } else if (cmd === 'reboot') {
            appendTerminalLog('Rebooting device...');
            appendTerminalLog('rst:0x1 (POWERON_RESET),boot:0x13 (SPI_FAST_FLASH_BOOT)');
          } else {
            appendTerminalLog(`ACK: ${cmd}`);
          }
          setIsSending(false);
        }, 200);
        return;
      }
    } catch (err: any) {
      appendTerminalLog(`[ERROR] Failed to send command: ${err.message}`);
    } finally {
      setIsSending(false);
      setTimeout(() => inputRef.current?.focus(), 50);
    }
  };

  const handleKeyDown = (e: React.KeyboardEvent<HTMLInputElement>) => {
    if (e.key === 'Enter') {
      e.preventDefault();
      handleSendCommand();
    } else if (e.key === 'ArrowUp') {
      e.preventDefault();
      if (history.length > 0 && historyIdx < history.length - 1) {
        const nextIdx = historyIdx + 1;
        setHistoryIdx(nextIdx);
        setCommandInput(history[nextIdx] || '');
      }
    } else if (e.key === 'ArrowDown') {
      e.preventDefault();
      if (historyIdx > 0) {
        const nextIdx = historyIdx - 1;
        setHistoryIdx(nextIdx);
        setCommandInput(history[nextIdx] || '');
      } else if (historyIdx === 0) {
        setHistoryIdx(-1);
        setCommandInput('');
      }
    }
  };

  const filteredLogs = useMemo(() => {
    if (!searchQuery.trim()) return logs;
    const q = searchQuery.toLowerCase();
    return logs.filter((line) => line.toLowerCase().includes(q));
  }, [logs, searchQuery]);

  const quickCommands = [
    { label: 'help', cmd: 'help' },
    { label: 'status', cmd: 'status' },
    { label: 'version', cmd: 'version' },
    { label: 'wifi_status', cmd: 'wifi_status' },
    { label: 'reboot', cmd: 'reboot' },
  ];

  return (
    <div className="h-screen w-screen overflow-hidden bg-[#0D1117] text-[#C9D1D9] flex flex-col font-sans select-none">
      {/* Titlebar Header */}
      <div className="flex items-center justify-between border-b border-[#30363D] bg-[#161B22] px-4 py-2">
        <div className="flex items-center gap-2.5">
          <Terminal className="h-4 w-4 text-[#58A6FF]" />
          <span className="font-semibold text-xs tracking-wide text-[#F0F6FC]">
            EH Home — Real Interactive Serial & Provisioning Terminal
          </span>
          <span className="flex items-center gap-1.5 rounded-full bg-[#238636]/20 px-2 py-0.5 text-[10px] font-mono font-medium text-[#3FB950] border border-[#238636]/40">
            <span className="h-1.5 w-1.5 rounded-full bg-[#3FB950] animate-pulse" />
            {selectedPort || 'COM6'} ({baudRate} BAUD)
          </span>
        </div>

        <div className="flex items-center gap-2">
          {/* Port Input */}
          <div className="flex items-center gap-1 bg-[#0D1117] border border-[#30363D] rounded px-1.5 py-0.5">
            <Cpu className="h-3 w-3 text-[#8B949E]" />
            <input
              type="text"
              value={selectedPort}
              onChange={(e) => {
                setSelectedPort(e.target.value.toUpperCase());
                try {
                  localStorage.setItem(SELECTED_PORT_KEY, e.target.value.toUpperCase());
                } catch {
                  /* ignore */
                }
              }}
              placeholder="COM Port"
              className="w-16 bg-transparent text-[11px] font-mono text-[#58A6FF] focus:outline-none"
            />
          </div>

          {/* Baud Rate */}
          <select
            value={baudRate}
            onChange={(e) => setBaudRate(Number(e.target.value))}
            className="rounded border border-[#30363D] bg-[#0D1117] px-2 py-0.5 text-[11px] font-mono text-[#C9D1D9] focus:outline-none"
          >
            <option value={115200}>115200 baud</option>
            <option value={921600}>921600 baud</option>
            <option value={74880}>74880 baud</option>
            <option value={9600}>9600 baud</option>
          </select>

          {/* Line Ending */}
          <select
            value={lineEnding}
            onChange={(e) => setLineEnding(e.target.value)}
            className="rounded border border-[#30363D] bg-[#0D1117] px-2 py-0.5 text-[11px] font-mono text-[#C9D1D9] focus:outline-none"
          >
            <option value="\\r\\n">CRLF (\r\n)</option>
            <option value="\\n">LF (\n)</option>
            <option value="\\r">CR (\r)</option>
          </select>

          {/* Search */}
          <input
            type="text"
            placeholder="Filter logs..."
            value={searchQuery}
            onChange={(e) => setSearchQuery(e.target.value)}
            className="w-32 rounded border border-[#30363D] bg-[#0D1117] px-2 py-0.5 text-[11px] font-mono text-[#C9D1D9] placeholder-[#8B949E] focus:border-[#58A6FF] focus:outline-none"
          />

          {/* Auto Scroll */}
          <button
            onClick={() => setAutoScroll(!autoScroll)}
            title={autoScroll ? 'Auto-scroll enabled' : 'Auto-scroll disabled'}
            className={`flex items-center gap-1 rounded border px-2 py-1 text-[11px] font-mono transition ${
              autoScroll
                ? 'border-[#58A6FF]/40 bg-[#58A6FF]/10 text-[#58A6FF]'
                : 'border-[#30363D] bg-[#21262D] text-[#8B949E]'
            }`}
          >
            <ArrowDownCircle className="h-3 w-3" />
            <span>Scroll</span>
          </button>

          {/* Copy Logs */}
          <button
            onClick={handleCopy}
            className="flex items-center gap-1 rounded border border-[#30363D] bg-[#21262D] px-2 py-1 text-[11px] font-mono text-[#C9D1D9] hover:bg-[#30363D] transition"
          >
            {copied ? <Check className="h-3 w-3 text-[#3FB950]" /> : <Copy className="h-3 w-3" />}
            <span>{copied ? 'Copied' : 'Copy'}</span>
          </button>

          {/* Clear Logs */}
          <button
            onClick={handleClear}
            className="flex items-center gap-1 rounded border border-[#30363D] bg-[#21262D] px-2 py-1 text-[11px] font-mono text-[#F85149] hover:bg-[#F85149]/10 transition"
          >
            <Trash2 className="h-3 w-3" />
            <span>Clear</span>
          </button>

          {/* Close Window */}
          <button
            onClick={handleClose}
            className="flex items-center gap-1 rounded border border-[#DA3633]/60 bg-[#DA3633]/20 px-2.5 py-1 text-[11px] font-medium text-[#FF7B72] hover:bg-[#DA3633]/30 transition"
          >
            <XCircle className="h-3 w-3" />
            <span>Close</span>
          </button>
        </div>
      </div>

      {/* Terminal Viewport */}
      <div
        ref={outputRef}
        className="flex-1 overflow-y-auto bg-[#090D14] p-4 font-mono text-xs leading-5 text-[#E6EDF3] space-y-0.5 select-text"
      >
        {filteredLogs.length === 0 ? (
          <div className="flex h-full flex-col items-center justify-center text-center text-[#8B949E] italic text-xs gap-2">
            <Zap className="h-6 w-6 text-[#58A6FF]/40" />
            <span>{searchQuery ? 'No log lines match the filter query.' : 'Hardware serial console ready. Type a command below or execute flashing.'}</span>
          </div>
        ) : (
          filteredLogs.map((line, idx) => {
            let color = 'text-[#C9D1D9]';
            if (line.includes('[ERROR]') || line.includes('FAIL') || line.includes('Fatal') || line.includes('Traceback')) {
              color = 'text-[#FF7B72] font-semibold';
            } else if (line.includes('[SUCCESS]') || line.includes('PASS') || line.includes('Hash of data verified')) {
              color = 'text-[#3FB950] font-semibold';
            } else if (line.includes('[WARN]') || line.includes('WARNING')) {
              color = 'text-[#D29922]';
            } else if (line.includes('[STEP') || line.includes('[STAGE') || line.includes('Connecting')) {
              color = 'text-[#58A6FF]';
            } else if (line.includes('> ') || line.startsWith('>')) {
              color = 'text-[#A371F7] font-semibold';
            }
            return (
              <div key={idx} className={`${color} whitespace-pre-wrap break-all`}>
                {line}
              </div>
            );
          })
        )}
      </div>

      {/* Interactive Command Bar */}
      <div className="border-t border-[#30363D] bg-[#161B22] p-2.5 flex flex-col gap-2">
        {/* Quick Command Pills */}
        <div className="flex items-center gap-1.5 overflow-x-auto text-[11px] font-mono text-[#8B949E]">
          <span className="text-[10px] text-[#8B949E] uppercase tracking-wider font-semibold">Quick Cmds:</span>
          {quickCommands.map((q) => (
            <button
              key={q.cmd}
              onClick={() => handleSendCommand(q.cmd)}
              disabled={isSending}
              className="rounded bg-[#21262D] px-2 py-0.5 text-[#58A6FF] border border-[#30363D] hover:bg-[#30363D] hover:text-[#79C0FF] transition disabled:opacity-50"
            >
              {q.label}
            </button>
          ))}
        </div>

        {/* Input Bar */}
        <div className="flex items-center gap-2">
          <div className="relative flex-1 flex items-center">
            <span className="absolute left-3 text-[#58A6FF] font-mono text-xs font-bold">&gt;</span>
            <input
              ref={inputRef}
              type="text"
              value={commandInput}
              onChange={(e) => setCommandInput(e.target.value)}
              onKeyDown={handleKeyDown}
              disabled={isSending}
              placeholder={`Send serial command to ${selectedPort} (e.g. help, status, reboot)... [↑/↓ for history]`}
              className="w-full rounded border border-[#30363D] bg-[#0D1117] py-1.5 pl-8 pr-3 text-xs font-mono text-[#F0F6FC] placeholder-[#8B949E] focus:border-[#58A6FF] focus:outline-none"
            />
          </div>
          <button
            onClick={() => handleSendCommand()}
            disabled={!commandInput.trim() || isSending}
            className="flex items-center gap-1.5 rounded bg-[#238636] px-4 py-1.5 text-xs font-semibold text-white hover:bg-[#2EA043] transition disabled:opacity-40 disabled:cursor-not-allowed"
          >
            {isSending ? <RefreshCw className="h-3.5 w-3.5 animate-spin" /> : <Send className="h-3.5 w-3.5" />}
            <span>Send</span>
          </button>
        </div>
      </div>

      {/* Footer Info */}
      <div className="flex items-center justify-between border-t border-[#30363D] bg-[#0D1117] px-4 py-1 text-[10px] font-mono text-[#8B949E]">
        <div className="flex items-center gap-3">
          <span>LINES: <strong className="text-[#F0F6FC]">{logs.length}</strong></span>
          <span>FILTERED: <strong className="text-[#F0F6FC]">{filteredLogs.length}</strong></span>
        </div>
        <div>
          <span>Target: <strong>{selectedPort}</strong> • Baud: <strong>{baudRate}</strong> • Line Ending: <strong>{lineEnding}</strong></span>
        </div>
      </div>
    </div>
  );
};
