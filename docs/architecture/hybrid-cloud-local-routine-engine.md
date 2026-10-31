# Hybrid Cloud & Local Routine Engine & Server Resource Analysis

## Executive Summary
This document addresses two core architectural questions:
1. **Can Cloud (Model 1) and Local Edge (Model 2) be combined?** How does immediate failover work when internet connectivity drops?
2. **Server Resource & Bandwidth Usage Analysis:** What happens to free hosting tiers (such as Render Free Tier) when running 24/7 background scheduler workers across 50 active routine-enabled devices?

---

## Part 1: Hybrid Architecture (Combining Cloud + Local Edge)

### 1.1 Can They Be Combined?
**Yes.** In production, top-tier consumer products like **Shelly Plus/Pro series** and **Philips Hue** use a hybrid execution model. 

The industry standard pattern is **"Local Execution with Cloud Mirroring"**:
* **Source of Truth for Schedules:** Schedules are authored in the mobile app and synchronized **both** to the Cloud Database and to the ESP32's onboard Flash (NVS).
* **Primary Executor:** The local device executes the routine independently via hardware timer.
* **Secondary / Cloud Role:** The Cloud only handles notifications, history logging, remote user controls, and cross-device automations (e.g., Switch A in Home 1 triggers Switch B in Home 2).

### 1.2 The Two Hybrid Operational Patterns

#### Pattern A: "Local-Master with Cloud Status Report" (Recommended)
```
  [User App]
      │ (Saves schedule)
      ├──────────────────────────────┬──────────────────────────────┐
      ▼                              ▼                              ▼
 [Cloud Database]             [ESP32 Switch 1]              [ESP32 Switch 2]
 (Stored for backup)          (Stored in NVS)               (Stored in NVS)
                                     │                             │
                                  [Clock]                       [Clock]
                                     │                             │
                       ┌─────────────┴─────────────┐               │
                       │ Internet Available?       │               │
                       ├─────────────┬─────────────┤               │
                       ▼             ▼             │               │
                     [YES]          [NO]           │               │
                       │             │             │               │
          Fires Relay Locally   Fires Relay        │               │
          + Posts Cloud Event   Locally (No Cloud) │               │
```
* **How it works:** The ESP32 is always the primary trigger for its own physical channels. When 9:30 PM arrives, the ESP32 flips the relay pin directly. 
* **If internet is connected:** The ESP32 posts an MQTT status update `{"event": "routine_executed", "relay": 1, "state": true}` to the cloud so the mobile app shows the updated state.
* **If internet is down:** The ESP32 still flips the relay on time. When internet reconnects later, it syncs its state log with the cloud.
* **Why it wins:** **Zero dual-execution race conditions.** The relay never flaps or gets triggered twice.

---

#### Pattern B: "Cloud-Master with Local Fallback Heartbeat" (Complex)
```
                          [Scheduled Time: 9:30:00 PM]
                                        │
                    ┌───────────────────┴───────────────────┐
                    ▼                                       ▼
             [Cloud Worker]                           [ESP32 Timer]
                    │                                       │
            Sends MQTT Command                              │
                    │                                       │
            Did ESP32 receive MQTT?                         │
            ├───────────────┬───────────────┐               │
            ▼               ▼               │               │
          [YES]            [NO]             │               │
            │               │               │               │
      Ack Received    Internet Dead         │               │
      (Skip Local)          │               │               │
                            └───────────────► If no cloud command received 
                                              within +500ms grace window, 
                                              ESP32 executes locally.
```
* **The Danger of Pattern B ("Flapping / Ghost Triggering"):**
  If the cloud sends the command at 9:30:00 PM, but cellular or Wi-Fi packet latency is delayed by 1.2 seconds, the ESP32 will think the cloud failed and fire locally at 9:30:00.5. Then at 9:30:01.2, the cloud command arrives and toggles the switch a second time!
* **Industry Rule:** Because of latency jitter, consumer products **never** make the Cloud the master for on-device simple schedules. The microcontroller itself must be the master execution engine for its own pins.

---

## Part 2: Backend Resource, Bandwidth & Hosting Analysis

### 2.1 The Render Free Tier Scenario

If you deploy your backend (`node backend/src/server.js`) to **Render.com's Free Web Service Tier**, here is the technical breakdown:

| Render Free Tier Spec | Limit | Impact on 24/7 Smart Home Backend |
| :--- | :--- | :--- |
| **RAM** | 512 MB | Schedulers and DB connection pools fit easily (uses ~65–120 MB). |
| **CPU** | 0.1 CPU core (shared) | Sufficient for 50 devices doing basic JSON payloads. |
| **Bandwidth** | 100 GB / month free | More than 10x what 50 devices need (see math below). |
| **Sleep / Inactivity Policy** | **Spins down after 15 min of no incoming HTTP traffic** | 🚨 **CRITICAL BLOCKER** (See Section 2.2). |
| **Free Hours** | 750 hours / month | Exactly enough for 1 instance running 31 days (24h × 31d = 744h). |

### 2.2 The Render Inactivity Sleep Trap

Render Free Tier Web Services **automatically spin down into sleep mode** if no external inbound HTTP traffic arrives within 15 minutes.
* While the server is asleep, **`setInterval` timers (like `AutomationSchedulerWorker`) stop running completely**.
* When an HTTP request finally arrives, Render takes **50 to 90 seconds ("cold start")** to wake up the container.
* **Result for Routines:** If a routine is scheduled for 9:30 PM, but no user opened the app between 9:15 PM and 9:30 PM, the server will be asleep and the routine **will not trigger**.

#### How to bypass Render sleep on Free Tier (If chosen):
1. **Keep-Alive Ping (Cron-Job.org / UptimeRobot):** Set up a free external monitoring ping to `GET https://your-app.onrender.com/health` every 10 minutes. This prevents the container from ever sleeping.
2. **Alternative Zero-Cost Always-On VPS:**
   * **Oracle Cloud Always Free Tier:** Provides 4 ARM Ampere cores, 24 GB RAM, and a public static IP that never sleeps.
   * **Hetzner Cloud / DigitalOcean Basic Droplet:** $3.50 to $4.00 per month for an unthrottled 24/7 Ubuntu server with dedicated cron.

---

### 2.3 Bandwidth & CPU Calculations for 50 Devices

Suppose you have **50 active ESP32 devices** with scheduled routines running 24/7:

#### 1. Keep-Alive / Ping Bandwidth (MQTT):
* **MQTT PingReq / PingResp:** 2 bytes sent every 30 seconds per device.
  $$\text{Ping Bytes per day} = \frac{86,400\text{ sec}}{30\text{ sec}} \times 4\text{ bytes} \times 50\text{ devices} = 576\text{ KB/day} \approx 17.2\text{ MB/month}$$

#### 2. Telemetry & State Reporting:
* If each device reports heartbeat/state every 60 seconds (payload ~150 bytes):
  $$\text{Telemetry per day} = \frac{86,400}{60} \times 150\text{ bytes} \times 50\text{ devices} \approx 10.8\text{ MB/day} \approx 324\text{ MB/month}$$

#### 3. Routine Scheduler Execution:
* Running a time check in Node.js memory every 1 second across 50 records in PostgreSQL:
  * In-memory evaluation CPU load: **< 0.5% CPU** on a single thread.
  * Routine command dispatch payload: ~300 bytes per actuation.
  * 50 daily actuations: **< 15 KB/day**.

#### Total Monthly Server Consumption (50 Devices):
* **Bandwidth:** Less than **500 MB per month** (Well within Render's 100 GB free quota).
* **RAM Usage:** Node.js server + PostgreSQL adapter = **~90 MB RAM**.
* **Database Storage:** 50 devices + 100 automations + 30 days of execution logs = **~12 MB storage**.

---

## Part 3: Architecture Recommendation

For a commercial product targeting reliability and consumer satisfaction:

1. **Deploy the Backend to an Always-On Host:**
   Use an external ping service on Render or move to a $4/month VPS so background workers never get suspended.
2. **Store Schedules on the ESP32 (Model 2):**
   Implement on-chip FreeRTOS scheduling on the ESP32. Even if the customer experiences an internet outage, router reboot, or server maintenance, their lights, geyser, and water motor still turn on and off reliably.
