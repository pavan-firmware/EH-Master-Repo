/**
 * EH Home - Embedded Local SNTP Timekeeper Server (RFC 5905)
 * Allows smart switches and LAN devices to keep microsecond-accurate RTC
 * time fully offline during prolonged ISP fiber cuts / internet outages.
 */

const dgram = require('dgram');

// NTP Epoch is 1900-01-01 00:00:00 UTC (70 years before Unix Epoch 1970)
const NTP_DELTA = 2208988800;

class SntpTimeServer {
  constructor(port = 123) {
    this.requestedPort = port;
    this.port = port;
    this.server = null;
    this.isRunning = false;
  }

  start(onListening) {
    const socket = dgram.createSocket('udp4');

    socket.on('error', (err) => {
      // If port 123 requires root permissions on some OSes, gracefully fall back to 4212
      if (err.code === 'EACCES' || err.code === 'EADDRINUSE') {
        if (this.port === 123) {
          console.warn(`[SNTP Server] Port 123 restricted (${err.code}). Falling back to alternate NTP port 4212...`);
          try {
            socket.close();
          } catch (_) {}
          this.port = 4212;
          return this.start(onListening);
        }
      }
      console.error('[SNTP Server] Socket error:', err.message);
    });

    socket.on('message', (msg, rinfo) => {
      if (msg.length < 48) return; // Ignore malformed frames

      const nowMs = Date.now();
      const ntpSeconds = Math.floor(nowMs / 1000) + NTP_DELTA;
      const ntpFraction = Math.floor(((nowMs % 1000) / 1000) * 0xFFFFFFFF);

      const response = Buffer.alloc(48);

      // Byte 0: LI = 0 (no warning), VN = 4 (IPv4), Mode = 4 (Server)
      // 00 100 100 -> 0x24
      response[0] = 0x24;

      // Byte 1: Stratum = 1 (Primary reference / Local RTC master)
      response[1] = 0x01;

      // Byte 2: Poll interval (6 = 64 seconds)
      response[2] = 0x06;

      // Byte 3: Precision = -20 (~1 microsecond)
      response[3] = 0xEC;

      // Bytes 4-7: Root Delay = 0
      response.writeUInt32BE(0, 4);

      // Bytes 8-11: Root Dispersion = 0.0001 sec
      response.writeUInt32BE(10, 8);

      // Bytes 12-15: Reference Identifier ("LOCL" or "PPS")
      response.write('LOCL', 12, 4, 'ascii');

      // Bytes 16-23: Reference Timestamp (Time when system clock was set)
      response.writeUInt32BE(ntpSeconds, 16);
      response.writeUInt32BE(ntpFraction, 20);

      // Bytes 24-31: Originate Timestamp (Copied directly from client's Transmit Timestamp at bytes 40-47)
      msg.copy(response, 24, 40, 48);

      // Bytes 32-39: Receive Timestamp
      response.writeUInt32BE(ntpSeconds, 32);
      response.writeUInt32BE(ntpFraction, 36);

      // Bytes 40-47: Transmit Timestamp (Time request departed server)
      response.writeUInt32BE(ntpSeconds, 40);
      response.writeUInt32BE(ntpFraction, 44);

      socket.send(response, 0, response.length, rinfo.port, rinfo.address, (sendErr) => {
        if (!sendErr) {
          // Microsecond time sync dispatched
        }
      });
    });

    socket.on('listening', () => {
      this.isRunning = true;
      const addr = socket.address();
      console.log(`[SNTP Server] RFC 5905 Local NTP Responder listening on ${addr.address}:${addr.port}`);
      if (typeof onListening === 'function') {
        onListening(this.port);
      }
    });

    socket.bind(this.port);
    this.server = socket;
  }

  stop() {
    if (this.server) {
      try {
        this.server.close();
      } catch (_) {}
      this.server = null;
      this.isRunning = false;
    }
  }
}

module.exports = {
  SntpTimeServer,
  NTP_DELTA,
};
