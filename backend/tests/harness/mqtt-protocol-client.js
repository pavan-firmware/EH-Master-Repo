'use strict';

/**
 * EH HOME — TEST-ONLY LOW-LEVEL MQTT PROTOCOL CLIENT HARNESS (Phase 6)
 *
 * THIS MODULE IS A TEST-ONLY CLIENT FOR LOW-LEVEL PROTOCOL/FRAMING TESTS.
 * IT IS NOT THE PRODUCTION BACKEND TRANSPORT CLIENT.
 * Production backend transport uses official `mqtt.js` in `backend/src/services/mqtt-device-transport.js`.
 */

const net = require('net');
const tls = require('tls');
const EventEmitter = require('events');

class MqttProtocolHarnessClient extends EventEmitter {
  constructor(opts = {}) {
    super();
    this.host = opts.host || '127.0.0.1';
    this.port = opts.port || (opts.useTls ? 8883 : 18883);
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

  connect() {
    return new Promise((resolve, reject) => {
      const connectOpts = {
        host: this.host,
        port: this.port,
        // SECURITY REQUIREMENT: rejectUnauthorized IS ALWAYS TRUE FOR TLS
        rejectUnauthorized: true
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

  _sendConnect(resolve, reject) {
    this._connectResolve = resolve;
    this._connectReject = reject;

    let connectFlags = 0x02;
    let willPayloadBuf = null;

    if (this.will) {
      connectFlags |= 0x04;
      if (this.will.qos) connectFlags |= (this.will.qos & 0x03) << 3;
      if (this.will.retain) connectFlags |= 0x20;
      willPayloadBuf = Buffer.from(this.will.payload || '');
    }

    const protoName = Buffer.from([0x00, 0x04, 0x4D, 0x51, 0x54, 0x54]);
    const protoVer = Buffer.from([0x04]);
    const flagsBuf = Buffer.from([connectFlags]);
    const keepAliveBuf = Buffer.alloc(2);
    keepAliveBuf.writeUInt16BE(this.keepalive, 0);

    const clientIdBuf = this._encodeString(this.clientId);
    const willTopicBuf = this.will ? this._encodeString(this.will.topic) : Buffer.alloc(0);
    const willMsgBuf = this.will ? this._encodeUInt16String(willPayloadBuf) : Buffer.alloc(0);

    const variableAndPayload = Buffer.concat([
      protoName, protoVer, flagsBuf, keepAliveBuf,
      clientIdBuf, willTopicBuf, willMsgBuf
    ]);

    const header = this._encodeFixedHeader(0x10, variableAndPayload.length);
    this.socket.write(Buffer.concat([header, variableAndPayload]));
  }

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

    if (qos > 0 && callback) {
      this._pendingPublishes.set(packetId, callback);
    }

    this.socket.write(Buffer.concat([header, variableHeader, payloadBuf]), () => {
      if (qos === 0 && typeof callback === 'function') callback(null);
    });
  }

  subscribe(topic, opts = {}, callback = null) {
    const qos = opts.qos || 0;
    const packetId = this._getNextPacketId();
    const pidBuf = Buffer.alloc(2);
    pidBuf.writeUInt16BE(packetId, 0);

    const topicBuf = this._encodeString(topic);
    const qosBuf = Buffer.from([qos]);

    const variableAndPayload = Buffer.concat([pidBuf, topicBuf, qosBuf]);
    const header = this._encodeFixedHeader(0x82, variableAndPayload.length);

    if (callback) {
      this._pendingSubscriptions.set(packetId, callback);
    }

    this.socket.write(Buffer.concat([header, variableAndPayload]));
  }

  end() {
    if (this.socket && this.connected) {
      this.socket.write(Buffer.from([0xE0, 0x00]), () => {
        this.socket.end();
        this.connected = false;
      });
    }
  }

  _onData(chunk) {
    this._buffer = Buffer.concat([this._buffer, chunk]);
    while (this._buffer.length > 0) {
      const parsed = this._parsePacket(this._buffer);
      if (!parsed) break;
      this._buffer = this._buffer.slice(parsed.totalLength);
      this._handlePacket(parsed);
    }
  }

  _parsePacket(buf) {
    if (buf.length < 2) return null;
    const type = (buf[0] >> 4) & 0x0F;
    const flags = buf[0] & 0x0F;

    let multiplier = 1;
    let value = 0;
    let offset = 1;
    let digit;

    do {
      if (offset >= buf.length) return null;
      digit = buf[offset++];
      value += (digit & 0x7F) * multiplier;
      multiplier *= 128;
    } while ((digit & 0x80) !== 0);

    const totalLength = offset + value;
    if (buf.length < totalLength) return null;

    return { type, flags, body: buf.slice(offset, totalLength), totalLength };
  }

  _handlePacket(packet) {
    switch (packet.type) {
      case 2:
        if (packet.body[1] === 0) {
          this.connected = true;
          this.emit('connect');
          if (this._connectResolve) this._connectResolve();
        } else {
          const err = new Error(`MQTT Connection refused: code ${packet.body[1]}`);
          this.emit('error', err);
          if (this._connectReject) this._connectReject(err);
        }
        break;

      case 3:
        const qos = (packet.flags >> 1) & 0x03;
        let offset = 0;
        const topicLen = packet.body.readUInt16BE(0); offset += 2;
        const topic = packet.body.toString('utf8', offset, offset + topicLen); offset += topicLen;

        if (qos > 0) {
          const packetId = packet.body.readUInt16BE(offset); offset += 2;
          const pubAck = Buffer.alloc(4);
          pubAck[0] = 0x40; pubAck[1] = 0x02;
          pubAck.writeUInt16BE(packetId, 2);
          this.socket.write(pubAck);
        }

        this.emit('message', topic, packet.body.slice(offset), { qos, retain: (packet.flags & 0x01) === 1 });
        break;

      case 4:
        const pubAckId = packet.body.readUInt16BE(0);
        if (this._pendingPublishes.has(pubAckId)) {
          const cb = this._pendingPublishes.get(pubAckId);
          this._pendingPublishes.delete(pubAckId);
          cb(null);
        }
        break;

      case 9:
        const subAckId = packet.body.readUInt16BE(0);
        const grantQos = packet.body[2];
        if (this._pendingSubscriptions.has(subAckId)) {
          const cb = this._pendingSubscriptions.get(subAckId);
          this._pendingSubscriptions.delete(subAckId);
          if (grantQos === 0x80) cb(new Error('Broker rejected subscription (ACL failure)'));
          else cb(null, [{ qos: grantQos }]);
        }
        break;
    }
  }

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

module.exports = { MqttProtocolHarnessClient };
