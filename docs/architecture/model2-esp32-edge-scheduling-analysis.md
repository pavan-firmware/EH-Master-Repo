# Model 2: ESP32 Edge-On-Chip Scheduling Architecture (Best & Worst Cases)

## Executive Summary
Model 2 (Edge-On-Chip) is the architecture popularized by **Shelly**, **Tasmota**, and **ESPHome**. In this model, the microcontroller (ESP32) acts as an autonomous computing device that stores, evaluates, and triggers its own schedules using onboard FreeRTOS tasks and flash memory, completely independent of smartphones, PCs, or cloud servers.

---

## Part 1: Best Cases (Why Top Consumer Brands Use Model 2)

```
       [Home Wi-Fi Router / No Internet]
                       │
       ┌───────────────┴───────────────┐
       ▼                               ▼
 [ESP32 Smart Switch]         [Mobile App (Phone)]
  • Internal SNTP Clock        • Direct Local LAN IP Control
  • Flash-Stored Schedules     • Zero Cloud Account Required
  • Physical Relay Actuation   • Instant UI Latency (<20ms)
```

### 1. 100% True Offline Independence
* If the user's home fiber internet cable is cut, or their ISP goes down for 3 days, **the water motor, aquarium pump, geyser, and outdoor lights still turn on and off exactly at the scheduled minute**.

### 2. Zero Recurring Server Infrastructure Costs
* As a manufacturer, you can sell 10,000 or 1,000,000 switches and your server hosting bill is **$0.00**. You never have to pay for cloud computing, MQTT brokers, or cron workers to evaluate schedules.

### 3. Millisecond Real-Time Latency
* The trigger runs directly inside the microcontroller. There is zero network round-trip time, zero packet loss, and zero queue delays. Actuation happens within **2 to 5 milliseconds** of the scheduled second.

### 4. Consumer Privacy & Market Differentiation
* Privacy-conscious homeowners, businesses, and industrial users prefer devices that don't depend on proprietary Chinese or American cloud servers. You can market the product as:
  > *"True Edge Privacy: Works offline forever with zero cloud dependency."*

---

## Part 2: Worst Cases & Real-World Engineering Pitfalls

While Model 2 is superior for single-device reliability, it introduces several firmware and edge challenges that must be engineered properly:

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                      MODEL 2 ENGINEERING PITFALLS                           │
├───────────────────────┬─────────────────────────────────────────────────────┤
│ 1. Clock Drift        │ ESP32 internal RTC drifts 2–5 minutes/month if no  │
│                       │ NTP refresh is available.                           │
├───────────────────────┼─────────────────────────────────────────────────────┤
│ 2. Post-Blackout Time │ After a power cut with NO internet, ESP32 clock     │
│                       │ resets to 1970-01-01 00:00:00.                      │
├───────────────────────┼─────────────────────────────────────────────────────┤
│ 3. Flash Memory Wear  │ Careless writes to NVS flash can exhaust flash      │
│                       │ sector erase cycles (100,000 limit).                │
├───────────────────────┼─────────────────────────────────────────────────────┤
│ 4. Cross-Device Scope │ Switch A in the bedroom cannot easily trigger       │
│                       │ Switch B in the kitchen without a central broker.   │
├───────────────────────┼─────────────────────────────────────────────────────┤
│ 5. Timezones & DST    │ Microcontroller needs POSIX timezone strings to     │
│                       │ calculate daylight savings and local offsets.       │
└───────────────────────┴─────────────────────────────────────────────────────┘
```

### 2.1 The "Power Cut + No Internet" Clock Loss (The Biggest Flaw)
* **The Problem:** The standard ESP32 does not have a coin-cell battery backup for its RTC. When power cuts and restores:
  1. The ESP32 boots up.
  2. Its internal clock resets to **Jan 1, 1970 00:00:00**.
  3. If your Wi-Fi has active internet, it connects to NTP (`pool.ntp.org`) in 1.5 seconds and restores real time.
  4. **The Worst Case:** If the power restored but the home internet is still down, the ESP32 has **no way to know what time it is**. Schedules will not fire until internet restores or until the user opens the mobile app on the local Wi-Fi to sync the phone's clock to the ESP32.
* **Production Fix Used by Shelly:**
  * When the Flutter app connects to the ESP32 over local LAN, it sends a time-sync heartbeat (`POST /api/v1/time {"epoch": 1791823900}`) to set the ESP32's clock directly from the phone.
  * For premium industrial models: Add a $0.40 DS3231 or PCF8563 I2C hardware RTC chip with a tiny supercapacitor.

### 2.2 Flash Memory Wear (NVS Cycle Limits)
* **The Problem:** Microcontroller SPI flash memory supports approximately **100,000 erase/write cycles** per sector.
* If a poorly written firmware writes schedule execution state or logs to NVS flash every minute, the flash chip will be physically destroyed within 3 months.
* **Production Solution:**
  * Only write to NVS when the user explicitly adds, edits, or deletes a routine.
  * Runtime execution flags (e.g., "fired at 9:30 PM today") must reside strictly in **RAM**.

### 2.3 Cross-Device Multi-Room Automations
* **The Problem:**
  * *Single-Device Routine:* "Turn on Water Motor at 6:00 AM" -> **Trivial for ESP32.**
  * *Cross-Device Routine:* "When Hall Sensor detects motion, turn on Bedroom Light on a different switch" -> **Difficult for Model 2.** Microcontrollers must either discover each other via UDP multicast (mDNS/CoAP) or establish direct peer-to-peer HTTP calls, which fails if IP addresses change.

---

## Part 3: Production Implementation Blueprint on ESP32

To implement Model 2 on your ESP32 switch, the firmware requires three standard modules:

### 3.1 Data Structure (Stored in NVS / LittleFS)
```c
typedef struct {
    uint8_t  id;                // Schedule ID (1..16)
    bool     enabled;           // Is active
    uint8_t  channel;           // Relay channel (1..4)
    bool     target_state;      // true = ON, false = OFF
    uint8_t  hour;              // 0..23
    uint8_t  minute;            // 0..59
    uint8_t  days_mask;         // Bitmask: Bit 0=Sun, 1=Mon, ..., 6=Sat
    uint16_t pulse_duration_s;  // Auto-off timer (e.g., 300s = 5m), 0 = infinite
} esp_schedule_rule_t;
```

### 3.2 Time Synchronization Task (SNTP)
```c
#include "esp_sntp.h"

void init_sntp_time(const char* timezone_posix) {
    esp_sntp_setoperatingmode(SNTP_OPMODE_POLL);
    esp_sntp_setservername(0, "pool.ntp.org");
    esp_sntp_setservername(1, "time.google.com");
    esp_sntp_init();
    
    // Set POSIX timezone (e.g. "IST-5:30" for India Standard Time)
    setenv("TZ", timezone_posix, 1);
    tzset();
}
```

### 3.3 FreeRTOS Scheduler Worker (Ticks every 1 second)
```c
void vScheduleWorkerTask(void *pvParameters) {
    time_t now;
    struct tm timeinfo;
    int last_checked_min = -1;

    for (;;) {
        vTaskDelay(pdMS_TO_TICKS(1000)); // Sleep 1 second
        
        time(&now);
        localtime_r(&now, &timeinfo);
        
        // If system time has not synced yet (before year 2024), skip
        if (timeinfo.tm_year < (2024 - 1900)) continue;

        // Only evaluate once per minute transition
        if (timeinfo.tm_min != last_checked_min) {
            last_checked_min = timeinfo.tm_min;
            
            int current_day_bit = 1 << timeinfo.tm_wday; // 0 = Sunday
            
            for (int i = 0; i < g_schedule_count; i++) {
                esp_schedule_rule_t *rule = &g_schedules[i];
                if (!rule->enabled) continue;
                
                // Day check
                if (!(rule->days_mask & current_day_bit)) continue;
                
                // Hour & Minute check
                if (rule->hour == timeinfo.tm_hour && rule->minute == timeinfo.tm_min) {
                    ESP_LOGI("SCHEDULE", "Actuating Relay %d -> %d", rule->channel, rule->target_state);
                    relay_set_power(rule->channel, rule->target_state);
                    
                    // Handle pulse timer if configured
                    if (rule->pulse_duration_s > 0) {
                        relay_start_auto_off_timer(rule->channel, rule->pulse_duration_s);
                    }
                }
            }
        }
    }
}
```

---

## Part 4: Conclusion & Recommendation

| Use Case | Best Model |
| :--- | :--- |
| Single-switch timer / daily scheduled routine | **Model 2 (Edge-on-Chip)** |
| Multi-room automations across 10 switches | **Model 1 (Cloud) or Model 3 (Local Hub)** |
| Critical appliances (Water pumps, Geysers) | **Model 2 (Must never fail during internet cut)** |
