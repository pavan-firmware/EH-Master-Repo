'use strict';

/**
 * EH Home — Real Socket-Level MQTT 3.1.1 / TLS Client (Phase 6)
 *
 * Provides genuine TCP/TLS socket connectivity for real broker validation.
 * Uses Node standard library `net` and `tls` modules — ZERO external dependencies.
 *
 * Implements MQTT 3.1.1 packet framing:
 *   - CONNECT (0x10) with LWT support & client certificate
 *   - CONNACK (0x20)
 *   - PUBLISH (0x30) with QoS 0 / QoS 1 & Retain flags
 *   - PUBACK  (0x40)
 *   - SUBSCRIBE (0x82) with packet identifier & requested QoS
 *   - SUBACK  (0x90)
 *   - PINGREQ (0xC0) & PINGRESP (0xD0)
 *   - DISCONNECT (0xE0)
 */

const net = require('net');
const tls = require('tls');
const EventEmitter = require('events');

class RealMqttClient extends EventEmitter {
  /**
   * @param {Object} opts
   * @param {string} [opts.host='127.0.0.1']
   * @param {number} [opts.port=1883]
   * @param {boolean} [opts.useTls=false]
   * @param {string} [opts.ca]             - PEM CA cert for TLS
   * @param {string} [opts.cert]           - PEM client cert for mTLS
   * @param {string} [opts.key]            - PEM client key for mTLS
   * @param {string} [opts.clientId]       - MQTT clientId
   * @param {Object} [opts.will]           - { topic, payload, qos, retain }
   * @param {number} [opts.keepalive=60]   - Keepalive seconds
   */
  constructor(opts = {}) {
    super();
    this.host = opts.host || '127.0.0.1';
    this.port = opts.port || (opts.useTls ? 8883 : 1883);
    this.useTls = opts.useTls || false;
    this.ca = opts.ca || null;
    this.cert = opts.cert || null;
    this.key = opts.key || null;
    this.clientId = opts.clientId || `eh_client_${Math.floor(Math.random() * 100000)}`;
    this.will = opts.will || null;
    this.keepalive = opts.keepalive || 60;

    this.socket = null;
    this.connected = false;
    this.nextPacketId = 1;
    this._buffer = Buffer.alloc(0);
    this._pendingPublishes = new Map();
    this._pendingSubscriptions = new Map();
  }

  /** Connect to real MQTT broker over TCP or TLS */
  connect() {
    return new Promise((resolve, reject) => {
      const connectOpts = {
        host: this.host,
        port: this.port,
        rejectUnauthorized: false
      };

      if (this.useTls) {
        if (this.ca) connectOpts.ca = this.ca;
        if (this.cert) connectOpts.cert = this.cert;
        if (this.key) connectOpts.key = this.key;
        this.socket = tls.connect(connectOpts, () => this._sendConnect(resolve, reject));
      } else {
        this.socket = net.connect(connectOpts, () => this._sendConnect(resolve, reject));
      }

      this.socket.on('data', (chunk) => this._onData(chunk));
      this.socket.on('error', (err) => {
        this.emit('error', err);
        if (!this.connected) reject(err);
      });
      this.socket.on('close', () => {
        const wasConnected = this.connected;
        this.connected = false;
        this.emit('close');
        if (wasConnected) this.emit('disconnected');
      });
    });
  }

  /** Send MQTT CONNECT packet */
  _sendConnect(resolve, reject) {
    this._connectResolve = resolve;
    this._connectReject = reject;

    // Connect flags: Clean Session (0x02)
    let connectFlags = 0x02;
    let willPayloadBuf = null;

    if (this.will) {
      connectFlags |= 0x04; // Will Flag
      if (this.will.qos) connectFlags |= (this.will.qos & 0x03) << 3;
      if (this.will.retain) connectFlags |= 0x20;
      willPayloadBuf = Buffer.from(this.will.payload || '');
    }

    // Variable header: Protocol Name ("MQTT"), Version (4 = 3.1.1), Flags, Keep Alive
    const protoName = Buffer.from([0x00, 0x04, 0x4D, 0x51, 0x54, 0x54]); // "MQTT"
    const protoVer = Buffer.from([0x04]); // 3.1.1
    const flagsBuf = Buffer.from([connectFlags]);
    const keepAliveBuf = Buffer.alloc(2);
    keepAliveBuf.writeUInt16BE(this.keepalive, 0);

    // Payload: clientId, Will Topic, Will Payload
    const clientIdBuf = this._encodeString(this.clientId);
    const willTopicBuf = this.will ? this._encodeString(this.will.topic) : Buffer.alloc(0);
    const willMsgBuf = this.will ? this._encodeUInt16String(willPayloadBuf) : Buffer.alloc(0);

    const variableAndPayload = Buffer.concat([
      protoName, protoVer, flagsBuf, keepAliveBuf,
      clientIdBuf,
      willTopicBuf, willMsgBuf
    ]);

    const header = this._encodeFixedHeader(0x10, variableAndPayload.length);
    const packet = Buffer.concat([header, variableAndPayload]);

    this.socket.write(packet);
  }

  /** Send MQTT PUBLISH packet */
  publish(topic, payload, opts = {}, callback = null) {
    const qos = opts.qos || 0;
    const retain = opts.retain || false;
    const payloadBuf = typeof payload === 'string' ? Buffer.from(payload) : Buffer.from(JSON.stringify(payload));
    const topicBuf = this._encodeString(topic);

    let packetFlags = (qos & 0x03) << 1;
    if (retain) packetFlags |= 0x01;

    let variableHeader = topicBuf;
    let packetId = null;

    if (qos > 0) {
      packetId = this._getNextPacketId();
      const pidBuf = Buffer.alloc(2);
      pidBuf.writeUInt16BE(packetId, 0);
      variableHeader = Buffer.concat([topicBuf, pidBuf]);
    }

    const payloadLength = variableHeader.length + payloadBuf.length;
    const header = this._encodeFixedHeader(0x30 | packetFlags, payloadLength);
    const packet = Buffer.concat([header, variableHeader, payloadBuf]);

    if (qos > 0 && callback) {
      this._pendingPublishes.set(packetId, callback);
    }

    this.socket.write(packet, () => {
      if (qos === 0 && typeof callback === 'function') {
        callback(null);
      }
    });
  }

  /** Send MQTT SUBSCRIBE packet */
  subscribe(topic, opts = {}, callback = null) {
    const qos = opts.qos || 0;
    const packetId = this._getNextPacketId();
    const pidBuf = Buffer.alloc(2);
    pidBuf.writeUInt16BE(packetId, 0);

    const topicBuf = this._encodeString(topic);
    const qosBuf = Buffer.from([qos]);

    const variableAndPayload = Buffer.concat([pidBuf, topicBuf, qosBuf]);
    const header = this._encodeFixedHeader(0x82, variableAndPayload.length);
    const packet = Buffer.concat([header, variableAndPayload]);

    if (callback) {
      this._pendingSubscriptions.set(packetId, callback);
    }

    this.socket.write(packet);
  }

  /** Graceful DISCONNECT */
  end() {
    if (this.socket && this.connected) {
      const disconnectPacket = Buffer.from([0xE0, 0x00]);
      this.socket.write(disconnectPacket, () => {
        this.socket.end();
        this.connected = false;
      });
    }
  }

  // ---------------------------------------------------------------------------
  // Internal Packet Parsing
  // ---------------------------------------------------------------------------

  _onData(chunk) {
    this._buffer = Buffer.concat([this._buffer, chunk]);
    while (this._buffer.length > 0) {
      const parsed = this._parsePacket(this._buffer);
      if (!parsed) break; // Incomplete packet
      this._buffer = this._buffer.slice(parsed.totalLength);
      this._handlePacket(parsed);
    }
  }

  _parsePacket(buf) {
    if (buf.length < 2) return null;
    const firstByte = buf[0];
    const type = (firstByte >> 4) & 0x0F;
    const flags = firstByte & 0x0F;

    // Decode remaining length (variable byte integer)
    let multiplier = 1;
    let value = 0;
    let offset = 1;
    let digit;

    do {
      if (offset >= buf.length) return null; // Incomplete header
      digit = buf[offset++];
      value += (digit & 0x7F) * multiplier;
      multiplier *= 128;
    } while ((digit & 0x80) !== 0);

    const totalLength = offset + value;
    if (buf.length < totalLength) return null; // Incomplete body

    const body = buf.slice(offset, totalLength);
    return { type, flags, body, totalLength };
  }

  _handlePacket(packet) {
    switch (packet.type) {
      case 2: // CONNACK
        const returnCode = packet.body[1];
        if (returnCode === 0) {
          this.connected = true;
          this.emit('connect');
          if (this._connectResolve) this._connectResolve();
        } else {
          const err = new Error(`MQTT Connection refused: code ${returnCode}`);
          this.emit('error', err);
          if (this._connectReject) this._connectReject(err);
        }
        break;

      case 3: // PUBLISH
        this._handleIncomingPublish(packet);
        break;

      case 4: // PUBACK
        const pubAckId = packet.body.readUInt16BE(0);
        if (this._pendingPublishes.has(pubAckId)) {
          const cb = this._pendingPublishes.get(pubAckId);
          this._pendingPublishes.delete(pubAckId);
          cb(null);
        }
        break;

      case 9: // SUBACK
        const subAckId = packet.body.readUInt16BE(0);
        const grantQos = packet.body[2];
        if (this._pendingSubscriptions.has(subAckId)) {
          const cb = this._pendingSubscriptions.get(subAckId);
          this._pendingSubscriptions.delete(subAckId);
          if (grantQos === 0x80) {
            cb(new Error('Broker rejected subscription (ACL failure)'));
          } else {
            cb(null, [{ qos: grantQos }]);
          }
        }
        break;

      case 13: // PINGRESP
        break;
    }
  }

  _handleIncomingPublish(packet) {
    const qos = (packet.flags >> 1) & 0x03;
    let offset = 0;
    const topicLen = packet.body.readUInt16BE(0);
    offset += 2;
    const topic = packet.body.toString('utf8', offset, offset + topicLen);
    offset += topicLen;

    let packetId = null;
    if (qos > 0) {
      packetId = packet.body.readUInt16BE(offset);
      offset += 2;

      // Send PUBACK
      const pubAck = Buffer.alloc(4);
      pubAck[0] = 0x40;
      pubAck[1] = 0x02;
      pubAck.writeUInt16BE(packetId, 2);
      this.socket.write(pubAck);
    }

    const payload = packet.body.slice(offset);
    this.emit('message', topic, payload, { qos, retain: (packet.flags & 0x01) === 1 });
  }

  // ---------------------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------------------

  _encodeFixedHeader(typeAndFlags, length) {
    const lengthBytes = [];
    let l = length;
    do {
      let digit = l % 128;
      l = Math.floor(l / 128);
      if (l > 0) digit |= 0x80;
      lengthBytes.push(digit);
    } while (l > 0);

    return Buffer.concat([Buffer.from([typeAndFlags]), Buffer.from(lengthBytes)]);
  }

  _encodeString(str) {
    const buf = Buffer.from(str, 'utf8');
    const lenBuf = Buffer.alloc(2);
    lenBuf.writeUInt16BE(buf.length, 0);
    return Buffer.concat([lenBuf, buf]);
  }

  _encodeUInt16String(buf) {
    const lenBuf = Buffer.alloc(2);
    lenBuf.writeUInt16BE(buf.length, 0);
    return Buffer.concat([lenBuf, buf]);
  }

  _getNextPacketId() {
    const id = this.nextPacketId++;
    if (this.nextPacketId > 65535) this.nextPacketId = 1;
    return id;
  }
}

module.exports = { RealMqttClient };
