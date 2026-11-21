# Multi-Floor, Multi-Router Network Topology & Non-Hub Coexistence Master Specification

**Document Version:** 1.0.0  
**Status:** Authoritative Architectural & Deployment Guide  
**Classification:** Network Topology, Edge Resilience, Systems Engineering & Mobile UX  
**Scope:** Multi-Floor Installations (Ground, 1st, 2nd) across Hub-Equipped vs. Standalone Non-Hub Homes.

---

## 1. Executive Overview

This specification establishes how the **EH Home Platform** functions across large residential and commercial deployments (apartments, multi-floor villas, corporate offices, and commercial malls). It defines the exact networking mechanics, signal paths, failover behaviors, and consumer flows across three distinct deployment models:

1. **Topology A (Hub-Equipped Home with Wi-Fi Extenders/Routers):** Maximum performance, sub-5ms local orchestration, and 100% offline multi-device coordination.
2. **Topology B (Standalone Non-Hub Home with Wi-Fi Extenders/Routers):** Standard autonomous deployment without a hub; direct local LAN control and autonomous on-chip hardware routines.
3. **Topology C (Standalone Non-Hub Home with Single Ground Router — No Extenders):** Challenging RF environment with weak signal penetration across concrete slabs; robust offline hardware control and direct BLE phone fallback.

---

## 2. Architectural Decision: Daisy-Chaining vs. Wi-Fi Infrastructure

### Question: Should smart devices daisy-chain (`Hub -> Device 1 -> Device 2 -> ... -> Device N`)?
> **Definitive Answer: For mains-powered Wi-Fi smart switches, daisy-chaining (mesh repeating) is a BAD idea.**

```
                           THE DAISY-CHAIN TRAP (AVOIDED)
  [ HUB ] ──> [ Switch 1 (GF) ] ──> [ Switch 2 (1F) ] ──> [ Socket 3 (2F) ]
                                          ▲
                                          │ If tripped at MCB breaker or powered off...
                                          └─── [ Socket 3 on 2F Dies Completely! ]
```

### Why Daisy-Chaining Fails in Real Homes:
1. **Single Point of Failure (Cascade Blackout):** If an intermediate switch (e.g. 1st-floor corridor switch) has its MCB breaker turned off, all downstream devices on the 2nd floor immediately disconnect.
2. **Latency Multiplication:** Every wireless hop between microcontrollers adds 25–60ms. A 4-hop chain takes 200ms+ to turn on a light.
3. **Radio & Memory Overload:** For an ESP32 chip to act as a repeater, its single 2.4GHz radio must split time between being a Wi-Fi station (client) and an Access Point (softAP). This cuts bandwidth in half, doubles packet collisions, and causes out-of-memory kernel panics.

### The Proven Best Practice: Star Topology over Home Wi-Fi
The existing residential Wi-Fi infrastructure (main router, mesh nodes, or plug-in extenders) handles long-distance RF transmission across floors. Every EH smart switch and socket connects directly to the nearest Wi-Fi Access Point on its floor. The EH Hub plugs into the main router.

---

## 3. Physical Floor Plan Example

The benchmark reference deployment consists of a 3-floor building with one internet connection (ISP):

* **Ground Floor:**
  * 1x ISP Fiber Modem / ONT with integrated Main Wi-Fi Router (`192.168.1.1`).
  * 1x EH Hub (connected via Ethernet LAN cable or Wi-Fi to main router).
  * Devices: 1x 2X Switch, 1x 3X Socket, 1x 4X Switch.
* **1st Floor:**
  * 1x Wi-Fi Range Extender or Secondary Router (Ethernet or wireless backhaul to Ground Router).
  * Devices: 1x 4X Switch, 2x 2X Sockets.
* **2nd Floor:**
  * 1x Wi-Fi Range Extender or Secondary Router.
  * Devices: 3x 1X Switches, 2x 4X Sockets.

---

## 4. Deep-Dive Flow Analysis by Deployment Model

```mermaid
flowchart TD
    subgraph ScenarioA ["Topology A: Hub + Extenders"]
        A_Phone["Mobile Phone App"] -->|Local LAN <3ms| A_Hub["EH Hub (Ground Floor)"]
        A_Hub -->|Direct Unicast IP| A_Dev1["Ground Devices"]
        A_Hub -->|Direct Unicast IP| A_Dev2["1st Floor Devices"]
        A_Hub -->|Direct Unicast IP| A_Dev3["2nd Floor Devices"]
    end

    subgraph ScenarioB ["Topology B: Non-Hub + Extenders"]
        B_Phone["Mobile Phone App"] -->|Local LAN Direct HTTP| B_Dev1["Ground Devices"]
        B_Phone -->|Local LAN Direct HTTP| B_Dev2["1st Floor Devices"]
        B_Phone -->|Local LAN Direct HTTP| B_Dev3["2nd Floor Devices"]
        B_Dev1 -.->|Internet MQTT| B_Cloud["EH Cloud Backend"]
        B_Dev2 -.->|Internet MQTT| B_Cloud
        B_Dev3 -.->|Internet MQTT| B_Cloud
    end

    subgraph ScenarioC ["Topology C: Non-Hub + No Extenders (Weak RF)"]
        C_Phone["Mobile Phone App"] -->|Strong Wi-Fi| C_Dev1["Ground Devices"]
        C_Phone -->|Fringe Wi-Fi or Direct BLE| C_Dev2["1st Floor Devices"]
        C_Phone -->|Direct BLE (10m)| C_Dev3["2nd Floor Devices"]
        C_Dev1 -->|Cap Touch Button| C_Relay1["Relay Action (0ms)"]
        C_Dev2 -->|Cap Touch Button| C_Relay2["Relay Action (0ms)"]
        C_Dev3 -->|Cap Touch Button| C_Relay3["Relay Action (0ms)"]
    end
```

---

### TOPOLOGY A: Hub-Equipped Home with Wi-Fi Extenders

#### 1. Device Discovery Across Extenders
* **Problem:** Low-cost Wi-Fi extenders drop UDP broadcast packets (`255.255.255.255`) to save airtime.
* **EH Resolution (Unicast Registration):**
  When a 2nd-floor switch boots and connects to the 2nd-floor extender, it obtains an IP (e.g. `192.168.1.85`). It then sends a direct **Unicast HTTP POST** to the Hub's known IP (`192.168.1.100:4210/api/v1/hub/register-device`).
* **Result:** Extenders and routers NEVER drop unicast IP packets. All devices across all floors are registered in the Hub's SQLite database within 1.5 seconds.

#### 2. Local Control Flow (Ground Floor Phone $\to$ 2nd Floor Light)
1. Phone sends `POST http://192.168.1.100:4210/api/v1/control` to the Hub.
2. Hub looks up `targetDeviceId` in SQLite cache $\to$ resolves IP `192.168.1.85`.
3. Hub dispatches `POST http://192.168.1.85/api/v1/control` through the router and 2nd-floor extender.
4. Relay clicks ON in **$<8\text{ms}$**. Zero internet or cloud latency.

#### 3. Cross-Floor Automation (100% Offline)
* **Rule:** *"Pressing Switch 1 on Ground Floor toggles 1st Floor Stair Light and 2nd Floor Balcony Socket."*
1. Ground switch broadcasts state change over local UDP / HTTP to the Hub.
2. Hub evaluates cross-device rule in RAM in $<1\text{ms}$.
3. Hub fires parallel commands to `192.168.1.50` (1F) and `192.168.1.85` (2F).
4. Both appliances toggle simultaneously in **$<10\text{ms}$** with zero internet connection.

#### 4. Total ISP Fiber Cable Cut
* Local routers and extenders keep running local Wi-Fi.
* Hub acts as local NTP server (UDP 123) $\to$ morning 6:00 AM geyser routine fires exactly on time.
* 100% of local features, app controls, and energy logging continue without disruption.

---

### TOPOLOGY B: Standalone Non-Hub Home with Wi-Fi Extenders

#### 1. Setup & Pairing Flow
* User pairs each device floor-by-floor using the Flutter app via Bluetooth Low Energy (BLE).
* Each device connects to the nearest floor's extender Wi-Fi.
* Ground devices receive IPs: `192.168.1.10` to `192.168.1.12`.
* 1st Floor devices receive IPs: `192.168.1.20` to `192.168.1.22`.
* 2nd Floor devices receive IPs: `192.168.1.30` to `192.168.1.34`.

#### 2. In-Home Local App Control
* When the user's phone is connected to the home Wi-Fi, the app discovers switches via UDP beacon (`EH_BEACON`) or queries cached IPs.
* Tapping a toggle sends `POST http://192.168.1.30/api/v1/control` directly from the phone to the 2nd-floor switch.
* Response time is **sub-15ms**. The command traverses:
  `Phone (Wi-Fi) -> Router -> 2nd Floor Extender -> Switch`. No hub needed!

#### 3. Out-of-Home Control (Mobile 4G/5G)
* When the user is away from home, the switches maintain a lightweight outbound MQTT connection to the secure EH Cloud Broker (`eh/{deviceId}/cmd/power`).
* Commands execute in 80–120ms over mobile data.

#### 4. Single-Device Routines & Schedules
* Schedules (e.g. 6:00 AM Geyser, 6:30 PM Porch Light) are written directly into each switch's **on-chip ESP32 NVS flash** (`edge_routine_engine.c`).
* The switch's internal FreeRTOS timer evaluates the schedule in RAM.
* **If the internet goes down, on-chip routines fire on time with zero dependency on a hub or cloud.**

#### 5. Cross-Device Automations in Non-Hub Mode
* Because there is no local Hub to bridge Floor 1 and Floor 2, multi-device rules (*"Switch A turns on Socket B"*) are processed by the **EH Cloud Automation Worker**.
* Requires active internet. If internet cuts, single-device routines continue firing, but cross-device rules pause until internet restores.

---

### TOPOLOGY C: Standalone Non-Hub Home with Single Ground Router (No Extenders)

In this scenario, a single router on the Ground floor must reach devices across concrete slabs to the 1st and 2nd floors without any repeaters.

#### 1. Radio Frequency (RF) Signal Attenuation through Concrete
* **Ground Floor:** Strong signal (`-35dBm` to `-50dBm`). 100% reliable high-speed Wi-Fi.
* **1st Floor (through 1 reinforced concrete slab):** Moderate signal (`-68dBm` to `-76dBm`). Reliable for lightweight JSON HTTP/MQTT packets.
* **2nd Floor (through 2 reinforced concrete slabs):** Fringe / Weak signal (`-82dBm` to `-89dBm`), with potential dead zones behind thick brick walls.

#### 2. Firmware Resilience Under Weak Signal
* **Zero System Freezing:** In `wifi_manager.c`, the Wi-Fi reconnection state machine uses non-blocking asynchronous reconnection with exponential backoff. Even if 2nd-floor Wi-Fi drops, the microcontroller **never freezes or stops controlling physical relays**.
* **Zero Relay Clicking:** Reconnection attempts do not cause relays to toggle or lights to blink.

#### 3. Wall Capacitive Touch Control Never Fails (0ms)
* Even if a 2nd-floor bedroom switch has **zero Wi-Fi reception** (`RSSI = 0`), tapping the physical capacitive touch plate on the wall switches the relay in **0 milliseconds**.
* The smart switch remains 100% reliable as a premium wall switch even in an RF dead zone.

#### 4. Direct Bluetooth Low Energy (BLE) Fallback
* If the user is in a 2nd-floor room where Wi-Fi cannot penetrate:
  1. The user walks into the room with their smartphone.
  2. The EH Mobile App automatically detects the device over **Bluetooth Low Energy (BLE)** within 10 meters.
  3. The app displays an active **BLE Direct Link** badge.
  4. The user can toggle switches, view energy consumption, and edit schedules directly over Bluetooth with **zero Wi-Fi signal required**.

---

## 5. Comprehensive Feature & Coexistence Comparison Matrix

| Feature | Topology A (Hub + Extenders) | Topology B (Non-Hub + Extenders) | Topology C (Non-Hub + No Extenders) |
| :--- | :--- | :--- | :--- |
| **Physical Wall Touch Buttons** | Instant (0ms) | Instant (0ms) | Instant (0ms) |
| **In-Home Phone App Latency** | $<8\text{ms}$ (via Hub LAN proxy) | $10\text{--}15\text{ms}$ (direct switch IP) | $10\text{ms}$ on GF; BLE fallback on 2F |
| **Out-of-Home Remote Control** | Cloud MQTT via Hub / Switch | Cloud MQTT direct to Switch | Cloud MQTT (where Wi-Fi reaches) |
| **Single-Device Schedules** | Hub DB (comfort) + NVS (critical) | Stored directly in Switch NVS | Stored directly in Switch NVS |
| **Cross-Device Automations** | **100% Offline via Hub ($<10\text{ms}$)** | Cloud-orchestrated (~100ms) | Cloud-orchestrated (requires Wi-Fi) |
| **Internet Cable Cut Behavior** | **100% fully functional** | Local app & on-chip rules work | Local app & on-chip rules work |
| **Timekeeper in Long Internet Outage**| **Local NTP Server on Hub** | Passive sync when phone connects | Passive sync when phone connects |
| **365-Day Energy Telemetry** | **Stored locally on Hub SQLite** | Cloud-stored (when online) | Cloud-stored (when online) |
| **Extender / Mesh Traversal** | Unicast HTTP reverse registration | Direct Unicast IP / Cloud MQTT | N/A (single router) |
| **Flash Wear Protection** | Yes (90% routines run in Hub RAM) | Normal NVS wear-leveling (27+ yrs) | Normal NVS wear-leveling (27+ yrs) |

---

## 6. Architectural Summary

1. **The Hub is an optional accelerator, never a requirement:** Standalone devices are completely self-sufficient.
2. **Daisy chaining is avoided:** Star topology over home Wi-Fi extenders avoids single-point-of-failure chains and latency pileup.
3. **Unicast ensures extender traversal:** Directed IP-to-IP messaging punches through mesh APs and repeaters that drop broadcast packets.
4. **Offline resilience is paramount:** Whether a home has a Hub, no Hub, or zero internet, wall switches always switch relays, and single-device timers always fire on time.
