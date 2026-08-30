# EH Home — Real Value Development Pre-Flight Checklist

## Pre-Flight Verification Steps

- [x] **Database Connectivity**: Relational schema migrations verified (28/28 managed tables symmetric UP/DOWN).
- [x] **MQTT Broker Connectivity**: Real EMQX 5.8 mTLS verified with TLS certificate validation.
- [x] **Capabilities Seed**: All 14 canonical capabilities verified in database catalog.
- [x] **Identity Separation**: Factory identity separate from user home authorizations.
- [x] **Zero Secret Commits**: No secrets or private keys in Git history or working tree.
