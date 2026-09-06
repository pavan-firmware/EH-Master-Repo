# Phase 36 — Flutter Runtime, Authentication & Navigation Architecture

## 1. Overview

Phase 36 completes the production Flutter application runtime for `smart_home_application_v1`. It establishes end-to-end integration across user authentication, dynamic home resolution, authoritative SSE lifecycle management, authenticated cloud command dispatch, and role-aware navigation for all platform feature screens (Phase 19–35).

---

## 2. Authentication Lifecycle & Cloud Enablement

### 2.1 Single Authority
The authentication lifecycle is driven solely by `AuthController` and `AuthRepository`. `HomeController` does not maintain a separate authentication database.

```
┌─────────────────┐
│ AuthController  │ ──(Authenticated)──► SmartHomeApp / SplashScreen
└─────────────────┘                              │
         │                                       ▼
         │                             Dynamic Home Resolution
         │                                       │
         │                                       ▼
         │                             ┌────────────────────┐
         ├────────────────────────────►│   HomeController   │
         │                             │  setCloudEnabled   │
         │                             │  setActiveHomeId   │
         │                             └────────────────────┘
         │                                       │
         │                                       ▼
         │                             ┌────────────────────┐
         └────────────────────────────►│  RealtimeService   │
                                       │   connect(homeId)  │
                                       └────────────────────┘
```

### 2.2 Lifecycle Rules
1. **Unauthenticated Initialization:** `HomeController` initializes with `_cloudEnabled = false`. Cloud operations and hardware actuators report `ActuatorConfidence.unavailable` and refuse unauthenticated cloud transmissions.
2. **Post-Authentication Enablement:** Upon successful login and profile verification, `SmartHomeApp` dynamically enables `HomeController.setCloudEnabled(true)` and sets `_activeHomeId`.
3. **Session Invalidation & Logout:**
   - Calls `authController.logout()`.
   - Clears `_cloudEnabled = false` and resets transient state via `homeController.resetSession()`.
   - Disconnects SSE stream cleanly (`realtimeService.disconnect()`).
   - Resets active navigation stack to `LoginScreen`.
4. **Token Expiry / 401 Handling:** `ApiClient` and `SSEClient` trigger auth refresh or session invalidation through standard token storage delegates.

---

## 3. Dynamic Authenticated Home Resolution

### 3.1 Flow
Hardcoded `"default"` home identity has been eradicated. The authoritative home ID is resolved dynamically:
1. User logs in with valid credentials.
2. `AccountHomeRepository.listHomes()` queries the backend `/v1/homes` endpoint.
3. If user has active memberships, the primary authoritative home (`homes.first.id`) is selected.
4. If no homes exist, the UI gracefully renders the empty home state with onboarding options without crashing.
5. Multiple homes are cleanly identified and stored deterministically.

---

## 4. SSE Home Routing & Realtime Sync

### 4.1 Subscription Routing
`RealtimeEventService` subscribes to SSE stream via:
```
GET /v1/realtime/events?homeId={authoritativeHomeId}
```
with `Authorization: Bearer <token>`.

### 4.2 Lifecycle Management
- **App Paused/Backgrounded:** Stream pauses / disconnects safely.
- **App Resumed:** `AppLifecycleListener` checks authentication and reconnects with the current `_activeHomeId`.
- **Logout:** Explicitly disconnects SSE, resets connection counters, and closes streams.

---

## 5. Command Execution Runtime

```
Flutter UI (Switch/Slider/Action)
    ↓
HomeController (enforces _cloudEnabled check)
    ↓
CloudHomeRepository / BLE Fallback
    ↓
Backend API / Realtime Pipeline
    ↓
Hardware Execution (ESP32 Smart Switch / Mist Maker)
    ↓
SSE Receipt / State Broadcast
    ↓
HomeController Event Reconciler -> UI Confidence Confirmed
```

Actuator confidence states:
- `ActuatorConfidence.confirmed` — authoritative confirmation via SSE state or receipt.
- `ActuatorConfidence.speculative` — optimistic local UI feedback awaiting backend confirmation.
- `ActuatorConfidence.unavailable` — cloud is disabled or user is unauthenticated.
- `ActuatorConfidence.unknown` — initial or reset state.

---

## 6. Navigation Hierarchy & Feature Integration

All Phase 19–35 feature modules are connected into a coherent Material 3 navigation structure in `SettingsPage`:

| Category | Screen | Route Entry | Role Gating |
|---|---|---|---|
| **Your System** | `ConnectionPage` | Connect your home | User / Admin |
| | `SystemUpdatePage` | System update | User / Admin |
| | `DeviceHealthPage` | Device health | User / Admin |
| | `AddRoomDevicePage` | Add a room device | User / Admin |
| **Home & People** | `PeoplePage` | People at home | User / Admin |
| | `HomeDetailsPage` | Home details | User / Admin |
| | `NotificationPreferencesPage` | Notification preferences | User / Admin |
| **Energy & Efficiency** | `HomeEnergyDashboardPage` | Energy dashboard | User / Admin |
| | `EnergyOptimizationPage` | Energy optimization | User / Admin |
| | `TariffManagementPage` | Electricity tariffs | User / Admin |
| **Intelligence & Context** | `IntelligenceCenterPage` | Intelligence center | User / Admin |
| | `PresenceDashboardPage` | Presence context | User / Admin |
| | `HomeContextPage` | Context history | User / Admin |
| **Devices & Ecosystem** | `ProductDiscoveryPage` | Product discovery | User / Admin |
| | `FleetHealthPage` | Fleet reliability | User / Admin |
| | `DeviceConnectivityPage` | Multi-protocol connectivity | User / Admin |
| | `MatterIntegrationPage` | Matter & Ecosystems | User / Admin |
| | `EdgeExecutionDashboardPage` | Edge control dashboard | User / Admin |
| **Notifications & Sync** | `NotificationCenterPage` | Notification center | User / Admin |
| | `SyncCenterPage` | Sync center | User / Admin |
| **Observability & Ops** | `OperationsDashboardPage` | Operations dashboard | **Admin Only** |
| | `SystemOperationalStatusPage` | System operational status | **Admin Only** |
| **Security & Resilience** | `DeviceSecurityStatusPage` | Device security trust | **Admin Only** |
| | `RecoveryDashboardPage` | Disaster recovery | **Admin Only** |
| **Help & Privacy** | `HelpSupportPage` | Help and support | User / Admin |
| | `PrivacyPage` | Privacy | User / Admin |
| **Account Session** | Sign Out Dialog | Sign out | User / Admin |
| **Danger Zone** | `FactoryResetPage` | Factory reset | User / Admin |

---

## 7. Role-Based Access Control (RBAC)

1. **User Profile Model:** `UserProfile` provides `role` (e.g. `'USER'`, `'ADMIN'`) and helper `bool get isAdmin => role.toUpperCase() == 'ADMIN'`.
2. **UI Role Gating:**
   - Restricted management tiles display an `Admin only` status chip for non-admin accounts.
   - Admin pages (`OperationsDashboardPage`, `SystemOperationalStatusPage`, `DeviceSecurityStatusPage`, `RecoveryDashboardPage`) enforce `isAdmin` checks and display access restricted warnings if invoked without privileges.
   - Backend APIs remain the authoritative gate and return `403 FORBIDDEN` for non-admin tokens.

---

## 8. App Configuration & Environment Control

`AppConfig` dynamically resolves backend endpoints:
- `AppConfig.setBaseUrl(String? url)` allows runtime and integration test overrides.
- In `kReleaseMode` or when unspecified, it checks `String.fromEnvironment('BACKEND_URL')`.
- Safe default fallback dynamically targets Android emulator (`http://10.0.2.2:3000`) or standard local host (`http://localhost:3000`).
- No hardcoded LAN IP addresses (such as `192.168.1.8`) or embedded secrets exist in production code paths.
