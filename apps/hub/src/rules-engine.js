/**
 * EH Home - Smart Hub Local Cross-Device Event Bus & Fast-Path UDP Engine
 *
 * Implements Add-on Plan 4:
 * 1. Low-latency (<3ms) Fast-Path Unicast UDP actuation on Port 4210
 * 2. Automatic fallback to HTTP POST /api/v1/control upon UDP timeout
 * 3. Reactive Event Bus for multi-device cascades and cross-floor triggers
 * 4. Microsecond audit log stored in Hub SQLite storage
 */

const dgram = require('dgram');
const http = require('http');

class RulesEngine {
  constructor(storage) {
    this.storage = storage;
    this.udpSocket = null;
    this.pendingUdpAcks = new Map(); // token -> { resolve, timer }
    this.initUdp();
  }

  initUdp() {
    try {
      this.udpSocket = dgram.createSocket('udp4');
      this.udpSocket.on('message', (msg, rinfo) => {
        try {
          const parsed = JSON.parse(msg.toString());
          if (parsed.cmd === 'P2P_ACTUATE_ACK' && parsed.seq) {
            const pending = this.pendingUdpAcks.get(parsed.seq);
            if (pending) {
              clearTimeout(pending.timer);
              this.pendingUdpAcks.delete(parsed.seq);
              pending.resolve({ success: true, latencyMs: performance.now() - pending.start, ack: parsed });
            }
          }
        } catch (_) {}
      });
      this.udpSocket.on('error', (err) => {
        console.warn('[RulesEngine:UDP] Socket warning:', err.message);
      });
    } catch (e) {
      console.warn('[RulesEngine] Failed to create UDP socket, will use HTTP fallback:', e.message);
    }
  }

  /**
   * Fast-Path Unicast UDP Actuation with 25ms timeout
   */
  async sendFastPathUdp(ip, channel, power, isToggle = false) {
    if (!this.udpSocket || !ip) {
      return { success: false, reason: 'UDP_SOCKET_UNAVAILABLE' };
    }

    const seq = 'seq_' + Math.random().toString(36).substring(2, 9);
    const payload = JSON.stringify({
      cmd: 'P2P_ACTUATE',
      seq,
      channel,
      power,
      isToggle,
      timestamp: Date.now(),
    });

    return new Promise((resolve) => {
      const start = performance.now();
      const timer = setTimeout(() => {
        this.pendingUdpAcks.delete(seq);
        resolve({ success: false, reason: 'UDP_TIMEOUT_EXCEEDED' });
      }, 35); // 35ms timeout before falling back to HTTP

      this.pendingUdpAcks.set(seq, { resolve, timer, start });

      const buf = Buffer.from(payload);
      this.udpSocket.send(buf, 0, buf.length, 4210, ip, (err) => {
        if (err) {
          clearTimeout(timer);
          this.pendingUdpAcks.delete(seq);
          resolve({ success: false, reason: err.message });
        }
      });
    });
  }

  /**
   * HTTP POST Fallback Actuation (<100ms)
   */
  async sendHttpFallback(ip, channel, power, isToggle = false) {
    if (!ip) return { success: false, reason: 'NO_TARGET_IP' };

    return new Promise((resolve) => {
      const start = performance.now();
      const payload = JSON.stringify({
        channel,
        channelIndex: channel,
        power,
        value: power,
        state: power,
        toggle: isToggle,
      });

      const req = http.request(
        {
          hostname: ip,
          port: 4210,
          path: '/api/v1/control',
          method: 'POST',
          headers: {
            'Content-Type': 'application/json',
            'Content-Length': Buffer.byteLength(payload),
          },
          timeout: 800,
        },
        (res) => {
          let data = '';
          res.on('data', (c) => (data += c));
          res.on('end', () => {
            const latencyMs = Math.round(performance.now() - start);
            resolve({ success: res.statusCode === 200, latencyMs });
          });
        }
      );

      req.on('timeout', () => {
        req.destroy();
        resolve({ success: false, reason: 'HTTP_TIMEOUT' });
      });

      req.on('error', (err) => {
        resolve({ success: false, reason: err.message });
      });

      req.write(payload);
      req.end();
    });
  }

  /**
   * Execute Action with Automatic Local Priority: Fast-Path UDP -> HTTP POST Fallback
   */
  async executeAction(rule, triggerEvent = 'MANUAL') {
    const t0 = performance.now();
    const isToggle = rule.actionCommand === 'TOGGLE';
    const targetPower = rule.actionCommand === 'ON' ? true : rule.actionCommand === 'OFF' ? false : true;

    let dispatchResult = await this.sendFastPathUdp(
      rule.actionDeviceIp,
      rule.actionChannel,
      targetPower,
      isToggle
    );

    let methodUsed = 'FAST_PATH_UDP';

    if (!dispatchResult.success) {
      // Step 2: Fallback to HTTP POST
      dispatchResult = await this.sendHttpFallback(
        rule.actionDeviceIp,
        rule.actionChannel,
        targetPower,
        isToggle
      );
      methodUsed = 'HTTP_FALLBACK';
    }

    const totalLatencyMs = Math.round(performance.now() - t0);
    const status = dispatchResult.success ? `SUCCESS_${methodUsed}` : `FAILED_${dispatchResult.reason || 'UNKNOWN'}`;

    const logEntry = {
      id: 'log_' + Date.now() + '_' + Math.random().toString(36).substring(2, 6),
      ruleId: rule.id,
      ruleName: rule.name,
      triggerEvent,
      actionSummary: `${rule.actionDeviceId} CH${rule.actionChannel} -> ${rule.actionCommand}`,
      latencyMs: totalLatencyMs,
      status,
      timestamp: new Date().toISOString(),
    };

    try {
      this.storage.addExecutionLog(logEntry);
    } catch (_) {}

    return {
      success: dispatchResult.success,
      latencyMs: totalLatencyMs,
      method: methodUsed,
      log: logEntry,
    };
  }

  /**
   * Evaluate Incoming State Changes across the Local Event Bus
   */
  async evaluateStateChange(deviceId, channel, state) {
    const rules = this.storage.getRules();
    const matchingRules = rules.filter((r) => {
      if (!r.enabled) return false;
      if (r.triggerDeviceId !== deviceId) return false;
      if (r.triggerChannel !== channel) return false;
      if (r.triggerState !== null && r.triggerState !== undefined && r.triggerState !== state) {
        return false;
      }
      return true;
    });

    const results = [];
    for (const rule of matchingRules) {
      const triggerDesc = `${deviceId} CH${channel}=${state ? 'ON' : 'OFF'}`;
      const res = await this.executeAction(rule, triggerDesc);
      results.push({ ruleId: rule.id, result: res });
    }

    return results;
  }

  close() {
    if (this.udpSocket) {
      try {
        this.udpSocket.close();
      } catch (_) {}
      this.udpSocket = null;
    }
  }
}

module.exports = {
  RulesEngine,
};
