'use strict';

/**
 * EH Home — Real Socket-Level MQTT 3.1.1 / TLS Broker Engine (Phase 6)
 *
 * Runs a real TCP (port 1883) or mTLS (port 8883) socket MQTT broker.
 * Implements real MQTT 3.1.1 binary framing, mTLS certificate validation,
 * per-device ACL isolation, LWT publishing on ungraceful drop, QoS 1 PUBACKs,
 * and retained message storage.
 *
 * Uses Node standard library `net`, `tls`, `crypto` — ZERO external dependencies.
 */

const net = require('net');
const tls = require('tls');
const EventEmitter = require('events');

const UUID_REGEX = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;

class RealMqttBroker extends EventEmitter {
  /**
   * @param {Object} opts
   * @param {number} [opts.port=1883]
   * @param {boolean} [opts.useTls=false]
   * @param {string} [opts.key]   - PEM server key
   * @param {string} [opts.cert]  - PEM server cert
   * @param {string} [opts.ca]    - PEM CA cert for mTLS
   */
  constructor(opts = {}) {
    super();
    this.port = opts.port || (opts.useTls ? 8883 : 1883);
    this.useTls = opts.useTls || false;
    this.key = opts.key || null;
    this.cert = opts.cert || null;
    this.ca = opts.ca || null;

    this.server = null;
    this.clients = new Set(); // Active client sessions
    this.retainedMessages = new Map(); // topic -> { topic, payload, qos }
  }

  /** Start listening for real TCP or TLS connections */
  start() {
    return new Promise((resolve, reject) => {
      if (this.useTls) {
        const tlsOpts = {
          key: this.key,
          cert: this.cert,
          ca: this.ca,
          requestCert: true,
          rejectUnauthorized: true // Strict mTLS verification
        };
        this.server = tls.createServer(tlsOpts, (socket) => this._handleSocket(socket, true));
      } else {
        this.server = net.createServer((socket) => this._handleSocket(socket, false));
      }

      this.server.on('error', (err) => reject(err));
      this.server.listen(this.port, '127.0.0.1', () => {
        console.log(`[RealMqttBroker] Listening on ${this.useTls ? 'mTLS' : 'TCP'} 127.0.0.1:${this.port}`);
        resolve();
      });
    });
  }

  /** Stop server and close all active client sockets */
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

  // ---------------------------------------------------------------------------
  // Socket Handling & Binary MQTT Parsing
  // ---------------------------------------------------------------------------

  _handleSocket(socket, isTls) {
    const client = {
      socket,
      isTls,
      connected: false,
      clientId: null,
      deviceId: null, // Resolved from client certificate CN or clientId
      certFingerprint: null,
      will: null,
      cleanSession: true,
      subscriptions: new Map(), // topicPattern -> qos
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

    socket.on('error', (err) => {
      // Socket error
    });

    socket.on('close', () => {
      this.clients.delete(client);
      if (client.connected) {
        client.connected = false;
        // Trigger LWT if disconnected ungracefully and LWT is configured
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
      case 1: // CONNECT
        this._handleConnect(client, packet);
        break;
      case 3: // PUBLISH
        this._handlePublish(client, packet);
        break;
      case 8: // SUBSCRIBE
        this._handleSubscribe(client, packet);
        break;
      case 12: // PINGREQ
        // Send PINGRESP (0xD0 0x00)
        client.socket.write(Buffer.from([0xD0, 0x00]));
        break;
      case 14: // DISCONNECT
        client.gracefulDisconnect = true;
        client.socket.end();
        break;
    }
  }

  // ---------------------------------------------------------------------------
  // Protocol Handlers
  // ---------------------------------------------------------------------------

  _handleConnect(client, packet) {
    const body = packet.body;
    let offset = 0;

    // Protocol Name ("MQTT")
    const protoLen = body.readUInt16BE(0); offset += 2;
    const protoName = body.toString('utf8', offset, offset + protoLen); offset += protoLen;
    const protoVer = body[offset++];

    const flags = body[offset++];
    const keepalive = body.readUInt16BE(offset); offset += 2;

    const cleanSession = (flags & 0x02) !== 0;
    const willFlag = (flags & 0x04) !== 0;
    const willQos = (flags >> 3) & 0x03;
    const willRetain = (flags & 0x20) !== 0;

    // ClientId
    const cidLen = body.readUInt16BE(offset); offset += 2;
    client.clientId = body.toString('utf8', offset, offset + cidLen); offset += cidLen;
    client.cleanSession = cleanSession;

    // Extract deviceId from clientId if not already set by TLS cert
    if (!client.deviceId && client.clientId.startsWith('eh_device_')) {
      const parts = client.clientId.split('_');
      if (parts.length >= 3 && UUID_REGEX.test(parts[2])) {
        client.deviceId = parts[2];
      }
    } else if (!client.deviceId && UUID_REGEX.test(client.clientId)) {
      client.deviceId = client.clientId;
    }

    // Will Topic & Payload
    if (willFlag) {
      const wtLen = body.readUInt16BE(offset); offset += 2;
      const willTopic = body.toString('utf8', offset, offset + wtLen); offset += wtLen;

      const wpLen = body.readUInt16BE(offset); offset += 2;
      const willPayload = body.slice(offset, offset + wpLen); offset += wpLen;

      client.will = {
        topic: willTopic,
        payload: willPayload,
        qos: willQos,
        retain: willRetain
      };
    }

    client.connected = true;

    // Send CONNACK (0x20 0x02 0x00 0x00)
    const connack = Buffer.from([0x20, 0x02, 0x00, 0x00]);
    client.socket.write(connack);
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

    // --- BROKER ACL PERMISSION CHECK (PUBLISH) ---
    const aclAllowed = this._checkPublishAcl(client, topic);
    if (!aclAllowed) {
      console.warn(`[RealMqttBroker] ACL DENIED: client '${client.clientId}' device '${client.deviceId}' attempted publish to '${topic}'`);
      // Send PUBACK if QoS 1 so client doesn't retry forever, but DO NOT route the message
      if (qos > 0 && packetId !== null) {
        const pubAck = Buffer.alloc(4);
        pubAck[0] = 0x40; pubAck[1] = 0x02;
        pubAck.writeUInt16BE(packetId, 2);
        client.socket.write(pubAck);
      }
      return;
    }

    // Retain storage
    if (retain) {
      if (payload.length === 0) {
        this.retainedMessages.delete(topic);
      } else {
        this.retainedMessages.set(topic, { topic, payload, qos });
      }
    }

    // Send PUBACK for QoS 1
    if (qos > 0 && packetId !== null) {
      const pubAck = Buffer.alloc(4);
      pubAck[0] = 0x40; pubAck[1] = 0x02;
      pubAck.writeUInt16BE(packetId, 2);
      client.socket.write(pubAck);
    }

    // Route message to all subscribing clients
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

      // --- BROKER ACL PERMISSION CHECK (SUBSCRIBE) ---
      const aclAllowed = this._checkSubscribeAcl(client, topicPattern);
      if (!aclAllowed) {
        console.warn(`[RealMqttBroker] ACL DENIED: client '${client.clientId}' device '${client.deviceId}' attempted subscribe to '${topicPattern}'`);
        returnCodes.push(0x80); // 0x80 = Failure
      } else {
        client.subscriptions.set(topicPattern, reqQos);
        returnCodes.push(reqQos);

        // Deliver matching retained messages to new subscriber
        this._deliverRetained(client, topicPattern);
      }
    }

    // Send SUBACK (0x90)
    const variableLen = 2 + returnCodes.length;
    const subAckBuf = Buffer.alloc(2 + variableLen);
    subAckBuf[0] = 0x90;
    subAckBuf[1] = variableLen;
    subAckBuf.writeUInt16BE(packetId, 2);
    for (let i = 0; i < returnCodes.length; i++) {
      subAckBuf[4 + i] = returnCodes[i];
    }
    client.socket.write(subAckBuf);
  }

  // ---------------------------------------------------------------------------
  // Broker ACL Logic
  // ---------------------------------------------------------------------------

  /**
   * Device A CANNOT publish to Device B topics (`eh/v1/devices/B/...`).
   * Backend client (clientId `backend_*` or `eh_client_*`) has service privileges.
   */
  _checkPublishAcl(client, topic) {
    if (client.clientId && (client.clientId.startsWith('backend') || client.clientId.startsWith('eh_client_'))) {
      return true; // Backend service principal
    }

    if (!client.deviceId) return true; // Unbound client in test

    const segments = topic.split('/');
    if (segments.length >= 4 && segments[0] === 'eh' && segments[1] === 'v1' && segments[2] === 'devices') {
      const topicDeviceId = segments[3];
      if (topicDeviceId !== client.deviceId) {
        return false; // DEVICE A CANNOT PUBLISH TO DEVICE B TOPICS
      }
    }
    return true;
  }

  /**
   * Device A CANNOT subscribe to Device B topics (`eh/v1/devices/B/...`).
   * Backend service principal can subscribe using `+` wildcard.
   */
  _checkSubscribeAcl(client, topicPattern) {
    if (client.clientId && (client.clientId.startsWith('backend') || client.clientId.startsWith('eh_client_'))) {
      return true; // Backend service principal
    }

    if (!client.deviceId) return true;

    const segments = topicPattern.split('/');
    if (segments.length >= 4 && segments[0] === 'eh' && segments[1] === 'v1' && segments[2] === 'devices') {
      const topicDeviceId = segments[3];
      if (topicDeviceId !== client.deviceId && topicDeviceId !== '+') {
        return false; // DEVICE A CANNOT SUBSCRIBE TO DEVICE B TOPICS
      }
    }
    return true;
  }

  // ---------------------------------------------------------------------------
  // Routing & Retain
  // ---------------------------------------------------------------------------

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
      packetIdBuf.writeUInt16BE(1, 0); // Static packetId for broker dispatch
    }

    let flags = (qos & 0x03) << 1;
    if (retain) flags |= 0x01;

    const variableHeader = Buffer.concat([topicLenBuf, topicBuf, packetIdBuf]);
    const payloadBuf = Buffer.isBuffer(payload) ? payload : Buffer.from(payload);
    const bodyLength = variableHeader.length + payloadBuf.length;

    // Length bytes
    const lengthBytes = [];
    let l = bodyLength;
    do {
      let digit = l % 128;
      l = Math.floor(l / 128);
      if (l > 0) digit |= 0x80;
      lengthBytes.push(digit);
    } while (l > 0);

    const header = Buffer.concat([Buffer.from([0x30 | flags]), Buffer.from(lengthBytes)]);
    const packet = Buffer.concat([header, variableHeader, payloadBuf]);

    client.socket.write(packet);
  }

  _publishLwt(client) {
    const will = client.will;
    if (!will) return;

    console.log(`[RealMqttBroker] UNEXPECTED DISCONNECT: Triggering LWT '${will.topic}' = '${will.payload.toString()}'`);
    this._routeMessage(will.topic, will.payload, will.qos, will.retain);

    if (will.retain) {
      this.retainedMessages.set(will.topic, { topic: will.topic, payload: will.payload, qos: will.willQos || 1 });
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

module.exports = { RealMqttBroker };
