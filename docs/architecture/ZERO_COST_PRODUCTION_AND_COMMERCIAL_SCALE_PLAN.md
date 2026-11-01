# EH Home — Complete Zero-Cost Pilot & Commercial Production Plan

**Document Version:** 1.0.0  
**Target Audience:** Engineering, Manufacturing, Commercial Strategy  
**Lifecycle Target:** Phase A (100% Zero-Cost Pilot / Seed Stage) $\to$ Phase B (Commercial Mass-Market Enterprise)  
**Cost Baseline:** **$0.00 / Zero Credit Cards Required for Phase A**

---

## 1. Executive Summary & Core Philosophy

This architecture document defines the end-to-end deployment, operation, and scaling strategy for the **EH Home Smart Home System** across two distinct operational phases:

1. **Phase A (Initial Zero-Cost Pilot Stage):** Delivering polished, production-grade hardware units to family, friends, and tech reviewers/YouTubers with **zero software infrastructure expenditure ($0.00)** and **no credit card requirements**.
2. **Phase B (Commercial Mass-Market Production):** Seamlessly transitioning to dedicated enterprise cloud infrastructure (AWS/Hetzner, EMQX clusters, Apple/Google App Stores) when commercial revenue and capital are established.

### The Immutable Architectural Rule
> **Zero Breaking Changes:** Every data contract, MQTT topic, REST endpoint, firmware partition table, and Flutter repository interface used in Phase A is identical to Phase B. Moving to enterprise paid hosting requires updating environment variables (`.env`) and DNS records — **not a single line of firmware C or Flutter Dart code needs to be refactored or rewritten.**

---

## 2. Architecture Comparison: Free Pilot vs. Enterprise Scale

```mermaid
graph TD
    subgraph Core ["EH Home Core Application Architecture"]
        FW[ESP32 Firmware C: Dual-Slot OTA & Edge Routine Engine]
        APP[Flutter Mobile App: Dynamic Product Catalog & Local/Cloud Routing]
        API[Node.js / Fastify Microservices & DB Adapters]
    end

    subgraph PhaseA ["Phase A: 100% Free Pilot (Zero Cost / No Credit Card)"]
        A_API[Render.com Free Web Service + UptimeRobot Keep-Alive]
        A_DB[Supabase / Neon Free Managed PostgreSQL 16]
        A_MQTT[HiveMQ Cloud Free Broker: 100 TLS Nodes Forever]
        A_OTA[GitHub Releases Global CDN: Unlimited Free Bandwidth]
        A_PUSH[Firebase Cloud Messaging FCM: Spark Free Tier Unlimited]
        A_DIST[Direct APK Split-per-ABI & Firebase App Distribution]
        A_LBL[Standard A4 Adhesive Sticker Sheets on Home Inkjet/Laser]
    end

    subgraph PhaseB ["Phase B: Commercial Enterprise Scale (Paid Infrastructure)"]
        B_API[Dedicated VPS / Hetzner / AWS EC2 Container Clusters]
        B_DB[AWS RDS PostgreSQL / High-Availability Managed Cluster]
        B_MQTT[Clustered EMQX 5.8 mTLS Enterprise Broker]
        B_OTA[Cloudflare R2 / AWS S3 Object Storage CDN]
        B_PUSH[Firebase Cloud Messaging Production Plan]
        B_DIST[Google Play Store & Apple App Store Listings]
        B_LBL[High-Speed Industrial Zebra / TSPL Thermal Roll Printers]
    end

    Core -->|Phase A Configuration| PhaseA
    Core -.->|Phase B Transition via ENV update| PhaseB
```

---

## 3. Layer-by-Layer Zero-Cost Stack Architecture (Phase A)

### 3.1 Backend API Layer ($0.00 / No Credit Card)
* **Hosting Platform:** **[Render.com](https://render.com)** Free Web Service
  * **Specifications:** 512 MB RAM, shared CPU, native Node.js runtime, free automatic SSL (`https://your-api.onrender.com`).
  * **Overcoming the 15-Minute Inactivity Sleep Limit:**
    * Render free instances enter sleep mode if no incoming HTTP traffic is detected for 15 minutes, causing background scheduler workers to pause.
    * **Solution:** Create a free account at **[UptimeRobot](https://uptimerobot.com)** or **[Cron-Job.org](https://cron-job.org)** (requires zero credit cards).
    * Configure an automated HTTP `GET` health ping to `https://your-api.onrender.com/health` every **8 to 10 minutes**.
    * **Result:** The service remains awake 24 hours a day, 365 days a year without cold starts or suspended routines.
  * **Alternative Local Cloud Server:**
    * An old laptop, mini-PC, or Raspberry Pi running Ubuntu and `docker-compose.prod.yml` can be exposed to the public internet for free using a **[Cloudflare Tunnel](https://www.cloudflare.com/products/tunnel/)** (`cloudflared`). Cloudflare Tunnels provide DDoS protection, automatic SSL, and public access without opening router ports or paying for static IPs.

### 3.2 Relational Database Layer ($0.00 / No Credit Card)
* **Hosting Platform:** **[Supabase](https://supabase.com)** or **[Neon.tech](https://neon.tech)**
  * **Specifications:** Free managed PostgreSQL 16 database with **500 MB persistent storage** and connection pooling.
  * **Capacity:** 500 MB comfortably stores over **150,000 device telemetry records**, 10,000 user profiles, and thousands of automation routines.
  * **Integration:** Paste the connection URI directly into your backend `.env` configuration:
    ```env
    DATABASE_URL=postgresql://postgres:[PASSWORD]@db.[PROJECT-REF].supabase.co:5432/postgres?sslmode=require
    DB_ADAPTER=postgres
    ```
  * Run migrations seamlessly:
    ```bash
    npm run migrate:up
    ```

### 3.3 MQTT Telemetry & Remote Control Broker ($0.00 / No Credit Card)
* **Cloud Broker:** **[HiveMQ Cloud Free](https://www.hivemq.com/pricing/)**
  * **Specifications:** **Up to 100 active devices connected simultaneously forever for $0.00**.
  * **Security:** Native TLS encryption on port `8883`.
  * **Firmware Compatibility:** The ESP32's `mqtt_transport.c` connects cleanly using the provided TLS CA certificate and device username/password.
* **Autonomous Local Edge Fallback:**
  * Even if the cloud connection is disrupted, the device's **Edge Routine Engine** (`edge_routine_engine.c`) and local HTTP micro-server (`/api/v1/control`) execute schedules and respond to mobile app commands over local Wi-Fi with zero internet dependency.

### 3.4 Firmware OTA Binary Distribution ($0.00 / No Credit Card)
* **Distribution CDN:** **GitHub Releases**
  * **Bandwidth & Storage:** 100% Free, unlimited public bandwidth, distributed worldwide across Fastly's CDN.
  * **Workflow:**
    1. Build the production binary:
       ```powershell
       powershell .\scripts\build_firmware.ps1 -Target esp32 -ProductType switch -Variant 3x
       ```
    2. Sign the binary cryptographically using Ed25519 (`tools/manufacturing/factory_provisioner.py`).
    3. Create a GitHub Release tag (e.g., `v1.0.1`) and upload `eh-smart-switch-app.bin`.
    4. Provide the public asset URL in the cloud release manifest:
       ```json
       {
         "firmwareFamily": "esp32c6-switch-platform",
         "version": "1.0.1",
         "downloadUrl": "https://github.com/USER/REPO/releases/download/v1.0.1/eh-smart-switch-app.bin",
         "sha256": "4a5b6c...",
         "ed25519Signature": "9f8e7d..."
       }
       ```
    5. The ESP32 `ota_manager.c` streams the update directly from GitHub over HTTPS into passive flash partition `ota_1` and reboots safely.

### 3.5 Mobile Application Distribution ($0.00 / No Store Fees)
* During the pilot review phase, bypass the Google Play ($25) and Apple Developer ($99/year) registration fees.
* **Option A — Optimized Direct Release APK:**
  ```powershell
  cd smart_home_application_v1
  flutter build apk --release --split-per-abi
  ```
  * Generates lightweight APKs (~15 MB to 20 MB each) targeting `arm64-v8a` and `armeabi-v7a`.
  * Distribute directly via WhatsApp, Telegram, Google Drive, or GitHub Releases.
* **Option B — Firebase App Distribution (Free):**
  * Upload APKs to Firebase App Distribution.
  * Add reviewers' email addresses. Reviewers receive an email invite, install the app with one tap, and get automatic update notifications when you build new versions.
* **Option C — Progressive Web Application (PWA):**
  * Build Flutter for web (`flutter build web`) and deploy free to **GitHub Pages** (`https://username.github.io/smart-home`).
  * Family members can open the URL and tap **"Add to Home Screen"** for a full-screen, native-feeling app experience with app icon and offline caching.

### 3.6 Push Notifications ($0.00 / No Credit Card)
* **Provider:** **Google Firebase Cloud Messaging (FCM Spark Plan)**
  * **Quota:** **100% Free Forever with unlimited push notifications**.
  * **Integration:**
    * Backend already includes the complete [`FcmHttpV1PushProvider`](file:///c:/Users/pavan/Downloads/Flutter/SMART_HOME_V1/backend/src/services/push-notification-provider.js#L154).
    * Create a free Firebase project, download `google-services.json` into `smart_home_application_v1/android/app/`, and generate a service account key for the backend.

### 3.7 Physical QR Codes & Packaging Labels ($0.00 Equipment Cost)
* Avoid purchasing an expensive industrial Zebra/TSC thermal roll printer ($400+).
* **Zero-Cost Production Printing:**
  * Purchase standard **A4 Adhesive Sticker Sheets** (matte or glossy) from any stationery store.
  * The desktop provisioner and web tools generate 300 DPI vector QR codes (`eh://p/v1?t=...`).
  * Print 24 to 30 product and packaging labels per sheet using any regular household inkjet or laser printer.
  * The Flutter app camera scanner scans these labels with identical speed and precision.

### 3.8 Transactional Emails ($0.00 / No Credit Card)
* **Provider:** **[Resend.com](https://resend.com)** (Free Tier: 3,000 emails/month, 100 emails/day, no credit card) or **[Brevo](https://brevo.com)** (300 emails/day free forever).
* Used for account confirmations, password resets, and household member invitation tokens.

---

## 4. Hardware Calibration & Production Assembly (Pilot Units)

### 4.1 Device Identity & Cryptographic Keys
* Each prototype unit requires a unique device ID, serial number, and private key burned into the ESP32 NVS storage.
* Run the local manufacturing provisioner:
  ```powershell
  python tools/manufacturing/factory_provisioner.py --port COM3 --variant eh-smart-switch-3x
  ```
* This creates:
  1. Factory identity record in NVS partition `factory_identity`.
  2. Printable QR code file for pairing (`EH-DEV-XXXXXX`).
  3. Pre-registered device record in your PostgreSQL database.

### 4.2 Energy Metering (BL0942) Factory Calibration
* For devices with energy monitoring (`-EM` variants):
  1. Connect a known resistive load (e.g., a 100W light bulb or standard 1000W heating element).
  2. Measure actual mains voltage with a calibrated multimeter (e.g. $230.5\text{ V}$).
  3. Read the raw telemetry reported by the ESP32 over serial or UDP.
  4. Write the reference voltage calibration factor $V_{cal}$ and current factor $I_{cal}$ to the NVS partition:
     ```c
     nvs_set_u32(my_handle, "v_cal", 23050);
     nvs_set_u32(my_handle, "i_cal", 4347);
     ```

### 4.3 Pilot Packaging & Presentation for YouTubers & Family
To deliver a high-quality unboxing experience:
1. **Physical Enclosure:** Clean 3D-printed enclosure (PETG or ABS for flame retardancy) with snap-fit lid.
2. **Labeling:** Clean A4 adhesive label stuck to the back showing:
   * Device Model: `EH Smart Switch 3X` (or `EH Smart Socket 2X`).
   * Voltage/Current: `110-240V ~ 50/60Hz, Max 16A`.
   * Clear Commissioning QR Code + Serial Number.
3. **Quick-Start Insert Card:** A 1-page folded instruction card:
   * Step 1: Install `EH Home` app (via direct APK link or QR).
   * Step 2: Power on device (Status LED pulses Blue).
   * Step 3: Tap **"Add Device"** in app and scan the QR code.
   * Step 4: Enter home Wi-Fi credentials. Device connects in <10 seconds.

---

## 5. Transition Path to Commercial Mass Production (Phase B)

When your pilot units have proven reliability, youtubers have published reviews, and you are ready for commercial retail launch:

| Component | Phase A (Free Pilot) | Phase B (Commercial Scale) | Migration Action Required |
| :--- | :--- | :--- | :--- |
| **Backend Host** | Render Free + UptimeRobot | $20/mo Dedicated Hetzner/AWS VPS | Deploy `docker-compose.prod.yml`; update DNS A-record. |
| **Database** | Supabase Free (500 MB) | AWS RDS / Managed PostgreSQL | Run `pg_dump` on Supabase $\to$ `pg_restore` to new RDS. Zero data loss. |
| **MQTT Broker** | HiveMQ Cloud Free (100 nodes) | Clustered EMQX 5.8 with mTLS | Update `MQTT_HOST` environment variable. |
| **Firmware OTA** | GitHub Releases CDN | Cloudflare R2 / AWS S3 | Update `OTA_BASE_URL` in backend manifest configuration. |
| **App Delivery** | Direct APK / Firebase Dist | Google Play Store ($25 one-time)<br>Apple App Store ($99/yr) | Sign APK/AAB with production keystore; upload to developer consoles. |
| **Silicon Security** | Open eFuses (Dev Flash) | Burned eFuses (Secure Boot v2 + AES Flash Encryption) | Enable `CONFIG_SECURE_ENABLE_SECURE_BOOT=y` in production release build. |
| **Labeling** | A4 Sticker Sheets | Industrial Zebra ZD421 Thermal Printer | Use existing TSPL driver via Desktop Provisioner. |

---

## 6. Step-by-Step Pilot Deployment Runbook

### Step 1: Database Setup
1. Create a free account at [Supabase.com](https://supabase.com).
2. Create a new project named `eh-home-pilot`.
3. Copy the Transaction connection string from `Project Settings` $\to$ `Database`.
4. Run migrations from your terminal:
   ```powershell
   $env:DATABASE_URL="postgresql://postgres:[PASSWORD]@db.[REF].supabase.co:5432/postgres?sslmode=require"
   node backend/migrations/run-migrations.js
   ```

### Step 2: Backend Deployment on Render.com
1. Create a free account at [Render.com](https://render.com).
2. Create a **New Web Service** connected to your repository.
3. Root Directory: `backend` (or use Dockerfile).
4. Build Command: `npm install`
5. Start Command: `node src/server.js`
6. Add Environment Variables:
   * `DATABASE_URL` = (Supabase connection string)
   * `NODE_ENV` = `production`
   * `PORT` = `10000`
   * `JWT_SECRET` = (Generate a random 32-byte hex string)
7. Once deployed, copy your URL: `https://eh-home-api.onrender.com`.
8. Go to [UptimeRobot.com](https://uptimerobot.com), create a free HTTP monitor for `https://eh-home-api.onrender.com/health` every 10 minutes.

### Step 3: MQTT Setup on HiveMQ Cloud
1. Sign up at [HiveMQ Cloud](https://www.hivemq.com/pricing/).
2. Create a free serverless cluster (free for up to 100 devices).
3. Copy your broker URL (e.g. `xxxxxxxx.hivemq.cloud`) and TLS port `8883`.
4. Create device credentials in the HiveMQ access management tab.
5. Add these credentials to your backend `.env` and firmware `mqtt_transport.c`.

### Step 4: Build & Export Release App
1. Set the production backend URL in `smart_home_application_v1/lib/core/config/app_config.dart`:
   ```dart
   static const String defaultApiUrl = 'https://eh-home-api.onrender.com';
   ```
2. Build the optimized release APKs:
   ```powershell
   cd smart_home_application_v1
   flutter build apk --release --split-per-abi
   ```
3. Locate your distribution file:
   `smart_home_application_v1/build/app/outputs/flutter-apk/app-arm64-v8a-release.apk`.
4. Upload to Google Drive or attach to a GitHub Release for your reviewers.

### Step 5: Flash Hardware & Print Stickers
1. Connect prototype board to USB.
2. Run build & flash:
   ```powershell
   powershell .\scripts\build_firmware.ps1 -Target esp32 -ProductType switch -Variant 3x -Flash -Port COM3
   ```
3. Print pairing QR sticker on A4 adhesive sheet.
4. Affix label to enclosure.
5. Ship or hand over unit to family / YouTuber with APK download link!

---

## 7. Verification Checklist Before Handing to Reviewers

- [x] Device boots with relays in safe **OFF** state.
- [x] Physical toggle switches work with instant debounced hardware response.
- [x] Pairing via QR scan connects over BLE and provisions Wi-Fi in <10 seconds.
- [x] Onboarding assigns canonical variant (`eh-smart-switch-3x` or `eh-smart-socket-2x`) without channel mismatch.
- [x] Local LAN direct control works instantly without internet dependency.
- [x] Offline routine scheduling triggers on time via ESP32 FreeRTOS timer.
- [x] Cloud backup and restore synchronizes exact room, device, and channel labels.
- [x] Total recurring software maintenance cost: **$0.00**.

