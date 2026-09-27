/**
 * Safe Desktop Logger
 * Prevents accidental logging of Wi-Fi passwords, keys, or device secrets.
 */

const REDACTED_KEYS = [
  'password',
  'token',
  'secret',
  'privatekey',
  'private_key',
  'wifipassword',
  'wifi_password',
  'authorization',
  'argon2id',
];

export function redactSensitiveData(data: unknown): unknown {
  if (!data || typeof data !== 'object') {
    return data;
  }

  if (Array.isArray(data)) {
    return data.map(redactSensitiveData);
  }

  const sanitized: Record<string, unknown> = {};
  for (const [key, value] of Object.entries(data as Record<string, unknown>)) {
    const lowerKey = key.toLowerCase();
    if (REDACTED_KEYS.some((rk) => lowerKey.includes(rk))) {
      sanitized[key] = '[REDACTED]';
    } else if (typeof value === 'object' && value !== null) {
      sanitized[key] = redactSensitiveData(value);
    } else {
      sanitized[key] = value;
    }
  }

  return sanitized;
}

export const logger = {
  info: (msg: string, meta?: unknown) => {
    console.log(`[INFO] ${msg}`, meta ? redactSensitiveData(meta) : '');
  },
  warn: (msg: string, meta?: unknown) => {
    console.warn(`[WARN] ${msg}`, meta ? redactSensitiveData(meta) : '');
  },
  error: (msg: string, meta?: unknown) => {
    console.error(`[ERROR] ${msg}`, meta ? redactSensitiveData(meta) : '');
  },
  debug: (msg: string, meta?: unknown) => {
    console.debug(`[DEBUG] ${msg}`, meta ? redactSensitiveData(meta) : '');
  },
};
