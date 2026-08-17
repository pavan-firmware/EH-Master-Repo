# Core Domain Contracts

This package contains the canonical JSON Schemas and strongly typed TypeScript definitions for the EH Home IoT ecosystem.

## Schemas
* `identity/device-identity.schema.json`
* `identity/network-identity.schema.json`
* `identity/device-credential.schema.json`
* `authorization/home-membership.schema.json`
* `authorization/device-authorization.schema.json`
* `product/hardware-profile.schema.json`
* `product/connectivity-profile.schema.json`
* `product/product-metadata.schema.json`
* `capability/capability-schema.schema.json`
* `state/channel-state.schema.json`
* `state/device-state.schema.json`
* `command/command.schema.json`
* `command/command-receipt.schema.json`
* `events/device-event.schema.json`
* `energy/energy-telemetry.schema.json`
* `telemetry/telemetry.schema.json`
* `automation/automation-rule.schema.json`
* `ota/ota-manifest.schema.json`
* `api/api-envelope.schema.json`

## Testing
Run contract validation test suite:
```bash
node packages/contracts/tests/contract-test.js
```
