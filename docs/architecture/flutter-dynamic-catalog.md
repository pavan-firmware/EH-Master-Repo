# EH Home — Flutter Dynamic Catalog & APK Optimization Architecture

**Document ID**: `EH-ARCH-PART-12-FLUTTER-DYNAMIC-CATALOG`  
**Status**: Approved & Verified  
**Scope**: Flutter Mobile Application (`smart_home_application_v1`), Dynamic Product Catalog Integration, Capability-Driven Rendering, Remote Asset Delivery, Release APK / AAB Optimization.

---

## 1. Executive Summary

In Part 12, the EH Home consumer Flutter mobile application was modernized to consume the canonical EH Home Product Catalog (`/api/v1/products/*`) dynamically. The architecture shifts the mobile client from static, duplicated hardcoded product variant declarations to an API-backed, capability-driven model, while maintaining strict backward compatibility with existing commissioning and device control workflows.

In addition, an empirical APK size audit was conducted, establishing the exact root cause of release package bloat (~78.8 MB universal APK) and configuring optimized ABI deployment strategies (`android-arm64` single-ABI APK: 40.0 MB; Android App Bundle AAB: 50.8 MB).

---

## 2. Dynamic Product Catalog Architecture

### 2.1 Backend Contract Consumption
The Flutter client dynamically interfaces with the authoritative REST endpoints defined in the shared contracts and backend:

* `GET /api/v1/products/families`: Returns canonical product families (`smart_switch`, `smart_socket`, `smart_fan`, `smart_light`, `smart_hub`, `sensor_node`).
* `GET /api/v1/products`: Returns all catalog products and active variants.
* `GET /api/v1/products/:productId`: Returns full product detail including hardware profile, connectivity specs, and variants.
* `GET /api/v1/products/variants/:variantId`: Returns variant-specific metadata, channel definitions, electrical limits, and capability bindings.

### 2.2 Data Models & Serialization
Typed Dart models (`lib/core/capabilities/models/capability_models.dart`) handle schema-versioned deserialization and state resolution:

* `ProductFamilyDefinition`: Category, display name, description, active status.
* `ProductVariantDefinition`: Variant ID, family, channel count, typed channel list, capabilities, hardware profile, connectivity profile, electrical specs, remote image URLs.
* `ProductChannelDefinition`: Channel index, default label, capability bindings, metadata configs (e.g., fan min/max speed, dimming limits).
* `CanonicalCapability`: Canonical capability identifier (`switch`, `relay`, `fan_speed`, `brightness`, `cct`, `energy`, `voltage`, `current`, `power`, `ota`), version, and UI hint.

---

## 3. Caching & Offline Resilience

### 3.1 Structured Multi-Layer Cache
`DynamicProductCatalogRepository` implements a resilient multi-tier caching strategy:
1. **In-Memory Cache**: High-speed retrieval for active UI rendering without disk I/O.
2. **Persistent Structured Cache**: Serialized JSON representation in local storage, updated on successful catalog fetches.
3. **Offline Bootstrap Fallback**: Hardcoded baseline definitions ensuring initial launch UX remains responsive even in zero-connectivity air-gapped environments.

### 3.2 Invalidation & Stale-While-Refresh
* Catalog queries return fresh local cached data immediately.
* Network refresh occurs on explicit application lifecycle triggers (app resume, pull-to-refresh, device discovery).
* If a network request fails (timeout, DNS failure, 5xx), the repository falls back to existing cached metadata with zero disruption to the user.
* Purging/invalidation clear both memory and persistent disk cache, triggering a clean fetch on the next lifecycle event.

---

## 4. Capability-Driven & Channel-Driven UI

### 4.1 Capability UI Registry
Rather than hardcoding UI views by product ID string matching (`if (product == 'smart-switch-3x')`), the UI queries the `CapabilityRendererRegistry`:

* **`switch` / `relay`**: Dispatches `SwitchControl` rendering binary power state toggles.
* **`fan_speed`**: Dispatches `FanSpeedControl` dynamically bounded by `minSpeed`, `maxSpeed`, and `step` from the channel metadata.
* **`brightness`**: Dispatches `BrightnessControl` with configurable dimming curve steps.
* **`cct`**: Dispatches `CCTControl` with Kelvin range bounds (2700K–6500K).
* **`energy`**: Dispatches telemetry views for voltage (V), current (A), and power (W).

### 4.2 Dynamic Channel Resolution
`CapabilityResolver.resolve()` binds the canonical `ProductVariantDefinition` with real-time device telemetry. Devices with $N$ channels dynamically instantiate $N$ independent channel control cards, adapting to single-gang, dual-gang, triple-gang, or quad-gang layouts automatically.

---

## 5. Remote Product Assets & Image Caching

### 5.1 Remote Asset Pipeline
* All heavy product renders, marketing illustrations, and packaging images are hosted remotely and referenced via URL / object key.
* The Flutter application renders assets via `ProductImageWidget`.

### 5.2 Loading, Caching & Fallback
* **HTTP / HTTPS URLs**: Cached locally via Flutter's image cache pipeline with loading progress indicator and memory management.
* **Local Asset Fallback**: Renders local bundled assets if URL is a relative asset path.
* **Placeholder & Error Fallback**: If network is unavailable or image fails to load, gracefully displays a branded fallback container with a category-appropriate icon.

---

## 6. QR & Commissioning Invariants

* **Canonical Scheme**: `eh://p/v1?t=<OPAQUE_TOKEN>` is strictly validated.
* **Zero Secret Leakage**: QR tokens are opaque random identifiers ($16 \le \text{length} \le 64$). No manufacturing secrets, private keys, device root credentials, or Wi-Fi passwords are encoded in QR URIs, catalog models, or caching layers.

---

## 7. APK Size Analysis & Optimization Strategy

### 7.1 Empirical Size Breakdown

| Build Target | Command / Artifact | Size | Description |
|---|---|---|---|
| **Universal Release APK** | `flutter build apk --release` (`build/app/outputs/flutter-apk/app-release.apk`) | **78.80 MB** (82,625,690 B) | Bundles all 3 native ABIs (`x86_64`, `arm64-v8a`, `armeabi-v7a`) in a single package. |
| **arm64-v8a Target APK** | `flutter build apk --target-platform android-arm64 --release` (`build/app/outputs/flutter-apk/app-arm64-v8a-release.apk`) | **39.97 MB** (41,911,040 B) | **~49.3% reduction**. Strips x86_64 and 32-bit ARM native binaries. Optimized for modern Android hardware. |
| **Android App Bundle (AAB)** | `flutter build appbundle --target-platform android-arm,android-arm64 --release` (`build/app/outputs/bundle/release/app-release.aab`) | **50.80 MB** (53,318,286 B) | Production store delivery artifact. Note: 18–22 MB is an expected Google Play Dynamic Delivery range and was not locally measured in this development environment. |

### 7.2 Native Binary & Resource Audit
* **Native `.so` Libraries**: Account for **72.43 MB (91.9%)** of the universal APK:
  * `lib/x86_64`: 27.01 MB
  * `lib/arm64-v8a`: 24.62 MB
  * `lib/armeabi-v7a`: 20.80 MB
  * Key native contributors: `libflutter.so`, `libapp.so` (Dart AOT runtime), `libreactive_ble_mobile_plugin.so`, `libflutter_secure_storage.so`, `libmobile_scanner.so`.
* **Assets & Code**:
  * Bundled assets: ~3.8 MB (essential vector icons, branding assets, local fallback icons).
  * Dart AOT compiled code: ~4.2 MB.
* **Optimization Strategy**:
  * For Direct APK / Sideloading: Distribute target-ABI APK (`android-arm64`).
  * For App Stores (Google Play): Distribute Android App Bundle (AAB) to enable Play Dynamic Delivery.

---

## 8. Verification & Test Coverage

* **Total Flutter Test Suite**: **461 / 461 passed** (425 baseline regression + 36 Part 12 dynamic catalog & integration tests).
* **Static Analysis**: `flutter analyze` completed with 0 errors and 0 warnings.
* **Deterministic Test Matrix**:
  1. Product family deserialization
  2. Product model validation
  3. Variant parsing with electrical specs
  4. Capability parsing & hints
  5. Dynamic channel parsing
  6. Malformed JSON rejection
  7. Schema version compatibility handling
  8. Structured memory & persistent catalog caching
  9. Explicit cache invalidation
  10. Stale cache retrieval on network disconnect
  11. Refresh cache replacement
  12. Refresh error handling preserving cache
  13. Offline bootstrap fallback
  14. Capability-driven switch rendering
  15. Channel-driven fan speed rendering with step constraints
  16. Dynamic channel count expansion (4X switch)
  17. Unknown/unsupported capability hiding
  18. Variant capability mapping & energy telemetry
  19. Canonical `eh://p/v1?t=<token>` QR acceptance
  20. Invalid QR URI scheme rejection
  21. Opaque token format validation
  22. Zero secret validation across logs/models/cache
  23. Remote image NetworkImage dispatch
  24. Local asset image resolution
  25. Null/empty URL fallback handling
  26. Network failure image placeholder rendering
  27. Firmware family & MCU mapping alignment
  28. ABI split & AAB delivery configuration
  29. Essential branding asset presence
  30. Obsolete large bundled asset absence
  31. Precedence: server catalog > persistent cache > bootstrap fallback
  32. Server catalog change invalidates stale cache and updates metadata
  33. Changing fixture metadata dynamically changes rendered DynamicChannelCard UI
  34. All 11 canonical product variants resolve through dynamic catalog
  35. Non-canonical variant rejected gracefully
  36. Remote asset consumer integration in ProductCard and ProductDetailPage
