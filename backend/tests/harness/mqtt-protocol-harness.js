'use strict';

/**
 * EH HOME — TEST-ONLY LOW-LEVEL MQTT PROTOCOL HARNESS (Phase 6)
 *
 * THIS MODULE IS A LOW-LEVEL PROTOCOL/FRAMING TEST HARNESS ONLY.
 * IT IS NOT THE PRODUCTION EMQX BROKER.
 *
 * Provides a pure Node.js socket server for testing binary MQTT 3.1.1 framing,
 * packet parsing, and ACL simulation in isolated unit/integration test environments.
 */

const net = require('net');
const tls = require('tls');
const EventEmitter = require('events');

const UUID_REGEX = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;

class MqttProtocolHarnessBroker extends EventEmitter {
  constructor(opts = {}) {
    super();
    this.port = opts.port || (opts.useTls ? 8883 : 18883);
    this.useTls = opts.useTls || false;
    this.key = opts.key || null;
    this.cert = opts.cert || null;
    this.ca = opts.ca || null;

    this.server = null;
    this.clients = new Set();
    this.retainedMessages = new Map();
  }

  start() {
    return new Promise((resolve, reject) => {
      if (this.useTls) {
        const tlsOpts = {
          key: this.key,
          cert: this.cert,
          ca: this.ca,
          requestCert: true,
          rejectUnauthorized: true // ENFORCE CERTIFICATE VERIFICATION
        };
        this.server = tls.createServer(tlsOpts, (socket) => this._handleSocket(socket, true));
      } else {
        this.server = net.createServer((socket) => this._handleSocket(socket, false));
      }

      this.server.on('error', (err) => reject(err));
      this.server.listen(this.port, '127.0.0.1', () => {
        console.log(`[ProtocolHarnessBroker] Listening on ${this.useTls ? 'mTLS' : 'TCP'} 127.0.0.1:${this.port}`);
        resolve();
      });
    });
  }

  stop() {
    return new Promise((resolve) => {
      for (const client of this.clients) {
        if (client.socket) client.socket.destroy();
      }
      this.clients.clear();
      if (this.server) {
        this.server.close(() => resolve());
      } else {
        resolve();
      }
    });
  }

  _handleSocket(socket, isTls) {
    const client = {
      socket,
      isTls,
      connected: false,
      clientId: null,
      deviceId: null,
      certFingerprint: null,
      will: null,
      cleanSession: true,
      subscriptions: new Map(),
      buffer: Buffer.alloc(0)
    };

    if (isTls) {
      const cert = socket.getPeerCertificate();
      if (cert && cert.subject && cert.subject.CN) {
        client.deviceId = cert.subject.CN;
        client.certFingerprint = cert.fingerprint;
      }
    }

    this.clients.add(client);

    socket.on('data', (chunk) => {
      client.buffer = Buffer.concat([client.buffer, chunk]);
      while (client.buffer.length > 0) {
        const parsed = this._parsePacket(client.buffer);
        if (!parsed) break;
        client.buffer = client.buffer.slice(parsed.totalLength);
        this._processClientPacket(client, parsed);
      }
    });

    socket.on('error', () => {});
    socket.on('close', () => {
      this.clients.delete(client);
      if (client.connected) {
        client.connected = false;
        if (client.will && !client.gracefulDisconnect) {
          this._publishLwt(client);
        }
      }
    });
  }

  _parsePacket(buf) {
    if (buf.length < 2) return null;
    const firstByte = buf[0];
    const type = (firstByte >> 4) & 0x0F;
    const flags = firstByte & 0x0F;

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

    const body = buf.slice(offset, totalLength);
    return { type, flags, body, totalLength };
  }

  _processClientPacket(client, packet) {
    switch (packet.type) {
      case 1: this._handleConnect(client, packet); break;
      case 3: this._handlePublish(client, packet); break;
      case 8: this._handleSubscribe(client, packet); break;
      case 12: client.socket.write(Buffer.from([0xD0, 0x00])); break;
      case 14: client.gracefulDisconnect = true; client.socket.end(); break;
    }
  }

  _handleConnect(client, packet) {
    const body = packet.body;
    let offset = 0;

    const protoLen = body.readUInt16BE(0); offset += 2;
    offset += protoLen; // Skip "MQTT"
    offset++; // Skip proto ver

    const flags = body[offset++];
    const keepalive = body.readUInt16BE(offset); offset += 2;

    const cleanSession = (flags & 0x02) !== 0;
    const willFlag = (flags & 0x04) !== 0;
    const willQos = (flags >> 3) & 0x03;
    const willRetain = (flags & 0x20) !== 0;

    const cidLen = body.readUInt16BE(offset); offset += 2;
    client.clientId = body.toString('utf8', offset, offset + cidLen); offset += cidLen;
    client.cleanSession = cleanSession;

    if (!client.deviceId && client.clientId.startsWith('eh_device_')) {
      const parts = client.clientId.split('_');
      if (parts.length >= 3 && UUID_REGEX.test(parts[2])) {
        client.deviceId = parts[2];
      }
    } else if (!client.deviceId && UUID_REGEX.test(client.clientId)) {
      client.deviceId = client.clientId;
    }

    if (willFlag) {
      const wtLen = body.readUInt16BE(offset); offset += 2;
      const willTopic = body.toString('utf8', offset, offset + wtLen); offset += wtLen;

      const wpLen = body.readUInt16BE(offset); offset += 2;
      const willPayload = body.slice(offset, offset + wpLen); offset += wpLen;

      client.will = { topic: willTopic, payload: willPayload, qos: willQos, retain: willRetain };
    }

    client.connected = true;
    client.socket.write(Buffer.from([0x20, 0x02, 0x00, 0x00]));
  }

  _handlePublish(client, packet) {
    const qos = (packet.flags >> 1) & 0x03;
    const retain = (packet.flags & 0x01) === 1;

    let offset = 0;
    const topicLen = packet.body.readUInt16BE(0); offset += 2;
    const topic = packet.body.toString('utf8', offset, offset + topicLen); offset += topicLen;

    let packetId = null;
    if (qos > 0) {
      packetId = packet.body.readUInt16BE(offset); offset += 2;
    }

    const payload = packet.body.slice(offset);

    if (!this._checkPublishAcl(client, topic)) {
      console.warn(`[ProtocolHarnessBroker] ACL DENIED publish to '${topic}' by client '${client.clientId}'`);
      if (qos > 0 && packetId !== null) {
        const pubAck = Buffer.alloc(4);
        pubAck[0] = 0x40; pubAck[1] = 0x02;
        pubAck.writeUInt16BE(packetId, 2);
        client.socket.write(pubAck);
      }
      return;
    }

    if (retain) {
      if (payload.length === 0) this.retainedMessages.delete(topic);
      else this.retainedMessages.set(topic, { topic, payload, qos });
    }

    if (qos > 0 && packetId !== null) {
      const pubAck = Buffer.alloc(4);
      pubAck[0] = 0x40; pubAck[1] = 0x02;
      pubAck.writeUInt16BE(packetId, 2);
      client.socket.write(pubAck);
    }

    this._routeMessage(topic, payload, qos, retain);
  }

  _handleSubscribe(client, packet) {
    let offset = 0;
    const packetId = packet.body.readUInt16BE(offset); offset += 2;
    const returnCodes = [];

    while (offset < packet.body.length) {
      const topicLen = packet.body.readUInt16BE(offset); offset += 2;
      const topicPattern = packet.body.toString('utf8', offset, offset + topicLen); offset += topicLen;
      const reqQos = packet.body[offset++];

      if (!this._checkSubscribeAcl(client, topicPattern)) {
        console.warn(`[ProtocolHarnessBroker] ACL DENIED subscribe to '${topicPattern}' by client '${client.clientId}'`);
        returnCodes.push(0x80);
      } else {
        client.subscriptions.set(topicPattern, reqQos);
        returnCodes.push(reqQos);
        this._deliverRetained(client, topicPattern);
      }
    }

    const subAckBuf = Buffer.alloc(4 + returnCodes.length);
    subAckBuf[0] = 0x90;
    subAckBuf[1] = 2 + returnCodes.length;
    subAckBuf.writeUInt16BE(packetId, 2);
    for (let i = 0; i < returnCodes.length; i++) subAckBuf[4 + i] = returnCodes[i];
    client.socket.write(subAckBuf);
  }

  _checkPublishAcl(client, topic) {
    if (client.clientId && (client.clientId.startsWith('backend') || client.clientId.startsWith('eh_client_'))) return true;
    if (!client.deviceId) return true;
    const segments = topic.split('/');
    if (segments.length >= 4 && segments[0] === 'eh' && segments[1] === 'v1' && segments[2] === 'devices') {
      if (segments[3] !== client.deviceId) return false;
    }
    return true;
  }

  _checkSubscribeAcl(client, topicPattern) {
    if (client.clientId && (client.clientId.startsWith('backend') || client.clientId.startsWith('eh_client_'))) return true;
    if (!client.deviceId) return true;
    const segments = topicPattern.split('/');
    if (segments.length >= 4 && segments[0] === 'eh' && segments[1] === 'v1' && segments[2] === 'devices') {
      if (segments[3] !== client.deviceId && segments[3] !== '+') return false;
    }
    return true;
  }

  _routeMessage(topic, payload, qos, retain) {
    for (const client of this.clients) {
      if (!client.connected) continue;
      for (const [pattern, subQos] of client.subscriptions.entries()) {
        if (this._topicMatches(pattern, topic)) {
          this._sendPublishToClient(client, topic, payload, Math.min(qos, subQos), retain);
          break;
        }
      }
    }
  }

  _deliverRetained(client, topicPattern) {
    for (const [topic, ret] of this.retainedMessages.entries()) {
      if (this._topicMatches(topicPattern, topic)) {
        this._sendPublishToClient(client, ret.topic, ret.payload, ret.qos, true);
      }
    }
  }

  _sendPublishToClient(client, topic, payload, qos, retain) {
    const topicBuf = Buffer.from(topic, 'utf8');
    const topicLenBuf = Buffer.alloc(2);
    topicLenBuf.writeUInt16BE(topicBuf.length, 0);

    let packetIdBuf = Buffer.alloc(0);
    if (qos > 0) {
      packetIdBuf = Buffer.alloc(2);
      packetIdBuf.writeUInt16BE(1, 0);
    }

    let flags = (qos & 0x03) << 1;
    if (retain) flags |= 0x01;

    const variableHeader = Buffer.concat([topicLenBuf, topicBuf, packetIdBuf]);
    const payloadBuf = Buffer.isBuffer(payload) ? payload : Buffer.from(payload);
    const bodyLength = variableHeader.length + payloadBuf.length;

    const lengthBytes = [];
    let l = bodyLength;
    do {
      let digit = l % 128;
      l = Math.floor(l / 128);
      if (l > 0) digit |= 0x80;
      lengthBytes.push(digit);
    } while (l > 0);

    const header = Buffer.concat([Buffer.from([0x30 | flags]), Buffer.from(lengthBytes)]);
    client.socket.write(Buffer.concat([header, variableHeader, payloadBuf]));
  }

  _publishLwt(client) {
    const will = client.will;
    if (!will) return;
    this._routeMessage(will.topic, will.payload, will.qos, will.retain);
    if (will.retain) {
      this.retainedMessages.set(will.topic, { topic: will.topic, payload: will.payload, qos: will.qos || 1 });
    }
  }

  _topicMatches(pattern, topic) {
    if (pattern === topic) return true;
    const pSegs = pattern.split('/');
    const tSegs = topic.split('/');
    for (let i = 0; i < pSegs.length; i++) {
      if (pSegs[i] === '#') return true;
      if (pSegs[i] === '+') {
        if (i >= tSegs.length) return false;
        continue;
      }
      if (pSegs[i] !== tSegs[i]) return false;
    }
    return pSegs.length === tSegs.length;
  }
}

module.exports = { MqttProtocolHarnessBroker };
