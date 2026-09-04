// Phase 29 — Matter Ecosystem Interoperability & Multi-Platform Integration Models
//
// Represents Matter devices, multi-admin fabrics, external platform links,
// commissioning sessions, and ecosystem certification overview.

enum MatterCommissioningState {
  notCommissioned,
  commissioning,
  commissioned,
  partiallyConnected,
  connected,
  disconnected,
  decommissioned;

  String toApiValue() => switch (this) {
    MatterCommissioningState.notCommissioned => 'NOT_COMMISSIONED',
    MatterCommissioningState.commissioning => 'COMMISSIONING',
    MatterCommissioningState.commissioned => 'COMMISSIONED',
    MatterCommissioningState.partiallyConnected => 'PARTIALLY_CONNECTED',
    MatterCommissioningState.connected => 'CONNECTED',
    MatterCommissioningState.disconnected => 'DISCONNECTED',
    MatterCommissioningState.decommissioned => 'DECOMMISSIONED',
  };

  static MatterCommissioningState fromJson(String? value) => switch (value?.toUpperCase()) {
    'NOT_COMMISSIONED' => MatterCommissioningState.notCommissioned,
    'COMMISSIONING' => MatterCommissioningState.commissioning,
    'COMMISSIONED' => MatterCommissioningState.commissioned,
    'PARTIALLY_CONNECTED' => MatterCommissioningState.partiallyConnected,
    'CONNECTED' => MatterCommissioningState.connected,
    'DISCONNECTED' => MatterCommissioningState.disconnected,
    'DECOMMISSIONED' => MatterCommissioningState.decommissioned,
    _ => MatterCommissioningState.notCommissioned,
  };

  String toDisplayLabel() => switch (this) {
    MatterCommissioningState.notCommissioned => 'Ready to Pair',
    MatterCommissioningState.commissioning => 'Pairing...',
    MatterCommissioningState.commissioned => 'Connected',
    MatterCommissioningState.partiallyConnected => 'Partially Connected',
    MatterCommissioningState.connected => 'Connected',
    MatterCommissioningState.disconnected => 'Disconnected',
    MatterCommissioningState.decommissioned => 'Removed',
  };
}

enum FabricStatus {
  active,
  pending,
  revoked,
  suspended;

  static FabricStatus fromJson(String? value) => switch (value?.toUpperCase()) {
    'ACTIVE' => FabricStatus.active,
    'PENDING' => FabricStatus.pending,
    'REVOKED' => FabricStatus.revoked,
    'SUSPENDED' => FabricStatus.suspended,
    _ => FabricStatus.active,
  };

  String toApiValue() => switch (this) {
    FabricStatus.active => 'ACTIVE',
    FabricStatus.pending => 'PENDING',
    FabricStatus.revoked => 'REVOKED',
    FabricStatus.suspended => 'SUSPENDED',
  };
}

enum PlatformLinkStatus {
  active,
  pending,
  disconnected,
  error;

  static PlatformLinkStatus fromJson(String? value) => switch (value?.toUpperCase()) {
    'ACTIVE' || 'CONNECTED' => PlatformLinkStatus.active,
    'PENDING' => PlatformLinkStatus.pending,
    'DISCONNECTED' => PlatformLinkStatus.disconnected,
    'ERROR' => PlatformLinkStatus.error,
    _ => PlatformLinkStatus.disconnected,
  };

  String toApiValue() => switch (this) {
    PlatformLinkStatus.active => 'ACTIVE',
    PlatformLinkStatus.pending => 'PENDING',
    PlatformLinkStatus.disconnected => 'DISCONNECTED',
    PlatformLinkStatus.error => 'ERROR',
  };
}

enum CommissioningSessionStatus {
  open,
  inProgress,
  completed,
  expired,
  failed;

  static CommissioningSessionStatus fromJson(String? value) => switch (value?.toUpperCase()) {
    'OPEN' => CommissioningSessionStatus.open,
    'IN_PROGRESS' => CommissioningSessionStatus.inProgress,
    'COMPLETED' => CommissioningSessionStatus.completed,
    'EXPIRED' => CommissioningSessionStatus.expired,
    'FAILED' => CommissioningSessionStatus.failed,
    _ => CommissioningSessionStatus.open,
  };

  String toApiValue() => switch (this) {
    CommissioningSessionStatus.open => 'OPEN',
    CommissioningSessionStatus.inProgress => 'IN_PROGRESS',
    CommissioningSessionStatus.completed => 'COMPLETED',
    CommissioningSessionStatus.expired => 'EXPIRED',
    CommissioningSessionStatus.failed => 'FAILED',
  };
}

enum ExternalPlatformType {
  appleHome,
  googleHome,
  amazonAlexa,
  samsungSmartThings,
  homeAssistant,
  genericMatterController;

  String toApiValue() => switch (this) {
    ExternalPlatformType.appleHome => 'APPLE_HOME',
    ExternalPlatformType.googleHome => 'GOOGLE_HOME',
    ExternalPlatformType.amazonAlexa => 'AMAZON_ALEXA',
    ExternalPlatformType.samsungSmartThings => 'SAMSUNG_SMARTTHINGS',
    ExternalPlatformType.homeAssistant => 'HOME_ASSISTANT',
    ExternalPlatformType.genericMatterController => 'GENERIC_MATTER_CONTROLLER',
  };

  static ExternalPlatformType fromJson(String? value) => switch (value?.toUpperCase()) {
    'APPLE_HOME' => ExternalPlatformType.appleHome,
    'GOOGLE_HOME' => ExternalPlatformType.googleHome,
    'AMAZON_ALEXA' || 'ALEXA' => ExternalPlatformType.amazonAlexa,
    'SAMSUNG_SMARTTHINGS' || 'SMARTTHINGS' => ExternalPlatformType.samsungSmartThings,
    'HOME_ASSISTANT' => ExternalPlatformType.homeAssistant,
    'GENERIC_MATTER_CONTROLLER' => ExternalPlatformType.genericMatterController,
    _ => ExternalPlatformType.genericMatterController,
  };

  String toDisplayLabel() => switch (this) {
    ExternalPlatformType.appleHome => 'Apple Home',
    ExternalPlatformType.googleHome => 'Google Home',
    ExternalPlatformType.amazonAlexa => 'Amazon Alexa',
    ExternalPlatformType.samsungSmartThings => 'Samsung SmartThings',
    ExternalPlatformType.homeAssistant => 'Home Assistant',
    ExternalPlatformType.genericMatterController => 'Matter Controller',
  };
}

typedef SmartHomePlatform = ExternalPlatformType;

class MatterFabricModel {
  final String id;
  final String fabricId;
  final String matterDeviceId;
  final int fabricIndex;
  final String fabricLabel;
  final int rootVendorId;
  final String? vendorName;
  final String? rootNodeId;
  final FabricStatus status;
  final DateTime? commissionedAt;

  const MatterFabricModel({
    required this.id,
    required this.fabricId,
    required this.matterDeviceId,
    this.fabricIndex = 1,
    required this.fabricLabel,
    this.rootVendorId = 4937,
    this.vendorName,
    this.rootNodeId,
    this.status = FabricStatus.active,
    this.commissionedAt,
  });

  String get fabricName => fabricLabel;
  int get vendorId => rootVendorId;
  String? get controllerNodeId => rootNodeId;
  MatterCommissioningState get commissioningState =>
      status == FabricStatus.active ? MatterCommissioningState.connected : MatterCommissioningState.disconnected;

  factory MatterFabricModel.fromJson(Map<String, dynamic> json) {
    return MatterFabricModel(
      id: json['id'] as String? ?? '',
      fabricId: json['fabricId'] as String? ?? json['fabric_id'] as String? ?? '',
      matterDeviceId: json['matterDeviceId'] as String? ?? json['matter_device_id'] as String? ?? '',
      fabricIndex: json['fabricIndex'] as int? ?? json['fabric_index'] as int? ?? 1,
      fabricLabel: json['fabricLabel'] as String? ?? json['fabric_label'] as String? ?? json['fabricName'] as String? ?? json['fabric_name'] as String? ?? 'Apple Home',
      rootVendorId: json['rootVendorId'] as int? ?? json['root_vendor_id'] as int? ?? json['vendorId'] as int? ?? json['vendor_id'] as int? ?? 4937,
      vendorName: json['vendorName'] as String? ?? json['vendor_name'] as String?,
      rootNodeId: json['rootNodeId'] as String? ?? json['root_node_id'] as String? ?? json['controllerNodeId'] as String? ?? json['controller_node_id'] as String?,
      status: FabricStatus.fromJson(json['status'] as String?),
      commissionedAt: json['commissionedAt'] != null || json['commissioned_at'] != null || json['pairedAt'] != null
          ? DateTime.tryParse(json['commissionedAt'] as String? ?? json['commissioned_at'] as String? ?? json['pairedAt'] as String? ?? '')
          : null,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'fabricId': fabricId,
    'matterDeviceId': matterDeviceId,
    'fabricIndex': fabricIndex,
    'fabricLabel': fabricLabel,
    'rootVendorId': rootVendorId,
    'vendorName': vendorName,
    'rootNodeId': rootNodeId,
    'status': status.toApiValue(),
    'commissionedAt': commissionedAt?.toIso8601String(),
  };
}

class ExternalPlatformLinkModel {
  final String id;
  final String homeId;
  final String? deviceId;
  final ExternalPlatformType platformType;
  final String fabricId;
  final String? platformHomeName;
  final String? externalBridgeNodeId;
  final int linkedDevicesCount;
  final PlatformLinkStatus status;
  final DateTime? lastSyncAt;
  final DateTime? linkedAt;

  const ExternalPlatformLinkModel({
    required this.id,
    required this.homeId,
    this.deviceId,
    required this.platformType,
    required this.fabricId,
    this.platformHomeName,
    this.externalBridgeNodeId,
    this.linkedDevicesCount = 0,
    this.status = PlatformLinkStatus.active,
    this.lastSyncAt,
    this.linkedAt,
  });

  ExternalPlatformType get platform => platformType;
  String get displayName => platformType.toDisplayLabel();

  factory ExternalPlatformLinkModel.fromJson(Map<String, dynamic> json) {
    return ExternalPlatformLinkModel(
      id: json['id'] as String? ?? json['linkId'] as String? ?? '',
      homeId: json['homeId'] as String? ?? json['home_id'] as String? ?? '',
      deviceId: json['deviceId'] as String? ?? json['device_id'] as String?,
      platformType: ExternalPlatformType.fromJson(json['platformType'] as String? ?? json['platform'] as String?),
      fabricId: json['fabricId'] as String? ?? json['fabric_id'] as String? ?? '',
      platformHomeName: json['platformHomeName'] as String? ?? json['platform_home_name'] as String?,
      externalBridgeNodeId: json['externalBridgeNodeId'] as String? ?? json['external_bridge_node_id'] as String?,
      linkedDevicesCount: json['linkedDevicesCount'] as int? ?? json['linked_devices_count'] as int? ?? 0,
      status: PlatformLinkStatus.fromJson(json['status'] as String?),
      lastSyncAt: json['lastSyncAt'] != null || json['last_sync_at'] != null
          ? DateTime.tryParse(json['lastSyncAt'] as String? ?? json['last_sync_at'] as String? ?? '')
          : null,
      linkedAt: json['linkedAt'] != null || json['linked_at'] != null
          ? DateTime.tryParse(json['linkedAt'] as String? ?? json['linked_at'] as String? ?? '')
          : null,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'homeId': homeId,
    if (deviceId != null) 'deviceId': deviceId,
    'platformType': platformType.toApiValue(),
    'fabricId': fabricId,
    if (platformHomeName != null) 'platformHomeName': platformHomeName,
    if (externalBridgeNodeId != null) 'externalBridgeNodeId': externalBridgeNodeId,
    'linkedDevicesCount': linkedDevicesCount,
    'status': status.toApiValue(),
    'lastSyncAt': lastSyncAt?.toIso8601String(),
    'linkedAt': linkedAt?.toIso8601String(),
  };
}

class MatterCommissioningSessionModel {
  final String sessionId;
  final String deviceId;
  final String homeId;
  final String manualPairingCode;
  final String qrCodePayload;
  final int pairingWindowSeconds;
  final DateTime expiresAt;
  final CommissioningSessionStatus status;
  final int discriminator;
  final int setupPasscode;

  const MatterCommissioningSessionModel({
    required this.sessionId,
    required this.deviceId,
    required this.homeId,
    required this.manualPairingCode,
    required this.qrCodePayload,
    this.pairingWindowSeconds = 900,
    required this.expiresAt,
    this.status = CommissioningSessionStatus.open,
    this.discriminator = 3840,
    this.setupPasscode = 20202021,
  });

  factory MatterCommissioningSessionModel.fromJson(Map<String, dynamic> json) {
    return MatterCommissioningSessionModel(
      sessionId: json['sessionId'] as String? ?? json['session_id'] as String? ?? '',
      deviceId: json['deviceId'] as String? ?? json['device_id'] as String? ?? '',
      homeId: json['homeId'] as String? ?? json['home_id'] as String? ?? '',
      manualPairingCode: json['manualPairingCode'] as String? ?? json['manual_pairing_code'] as String? ?? '',
      qrCodePayload: json['qrCodePayload'] as String? ?? json['qr_code_payload'] as String? ?? '',
      pairingWindowSeconds: json['pairingWindowSeconds'] as int? ?? json['pairing_window_seconds'] as int? ?? 900,
      expiresAt: json['expiresAt'] != null || json['expires_at'] != null
          ? DateTime.tryParse(json['expiresAt'] as String? ?? json['expires_at'] as String? ?? '') ?? DateTime.now().add(const Duration(minutes: 15))
          : DateTime.now().add(const Duration(minutes: 15)),
      status: CommissioningSessionStatus.fromJson(json['status'] as String?),
      discriminator: json['discriminator'] as int? ?? 3840,
      setupPasscode: json['setupPasscode'] as int? ?? json['setup_passcode'] as int? ?? 20202021,
    );
  }

  Map<String, dynamic> toJson() => {
    'sessionId': sessionId,
    'deviceId': deviceId,
    'homeId': homeId,
    'manualPairingCode': manualPairingCode,
    'qrCodePayload': qrCodePayload,
    'pairingWindowSeconds': pairingWindowSeconds,
    'expiresAt': expiresAt.toIso8601String(),
    'status': status.toApiValue(),
    'discriminator': discriminator,
    'setupPasscode': setupPasscode,
  };
}

class MatterDeviceSummary {
  final String id;
  final String deviceId;
  final String homeId;
  final String deviceName;
  final int vendorId;
  final int productId;
  final String nodeId;
  final String deviceType;
  final int deviceTypeId;
  final bool isCommissioned;
  final int activeFabricsCount;
  final int maxFabricsSupported;
  final int passcode;
  final int discriminator;
  final String softwareVersion;
  final int hardwareVersion;
  final DateTime? lastSyncedAt;
  final DateTime createdAt;
  final DateTime updatedAt;
  final List<MatterFabricModel> fabrics;

  const MatterDeviceSummary({
    required this.id,
    required this.deviceId,
    required this.homeId,
    required this.deviceName,
    this.vendorId = 4937,
    this.productId = 1,
    required this.nodeId,
    this.deviceType = 'ON_OFF_LIGHT',
    this.deviceTypeId = 256,
    this.isCommissioned = false,
    this.activeFabricsCount = 0,
    this.maxFabricsSupported = 5,
    this.passcode = 20202021,
    this.discriminator = 3840,
    this.softwareVersion = '1.0.0',
    this.hardwareVersion = 1,
    this.lastSyncedAt,
    required this.createdAt,
    required this.updatedAt,
    this.fabrics = const [],
  });

  factory MatterDeviceSummary.fromJson(Map<String, dynamic> json) {
    return MatterDeviceSummary(
      id: json['id'] as String? ?? '',
      deviceId: json['deviceId'] as String? ?? json['device_id'] as String? ?? '',
      homeId: json['homeId'] as String? ?? json['home_id'] as String? ?? '',
      deviceName: json['deviceName'] as String? ?? json['device_name'] as String? ?? 'Device',
      vendorId: json['vendorId'] as int? ?? json['vendor_id'] as int? ?? 4937,
      productId: json['productId'] as int? ?? json['product_id'] as int? ?? 1,
      nodeId: json['nodeId'] as String? ?? json['node_id'] as String? ?? '0x0000000000000001',
      deviceType: json['deviceType'] as String? ?? json['device_type'] as String? ?? 'ON_OFF_LIGHT',
      deviceTypeId: json['deviceTypeId'] as int? ?? json['device_type_id'] as int? ?? 256,
      isCommissioned: json['isCommissioned'] as bool? ?? json['is_commissioned'] as bool? ?? false,
      activeFabricsCount: json['activeFabricsCount'] as int? ?? json['active_fabrics_count'] as int? ?? 0,
      maxFabricsSupported: json['maxFabricsSupported'] as int? ?? json['max_fabrics_supported'] as int? ?? 5,
      passcode: json['passcode'] as int? ?? 20202021,
      discriminator: json['discriminator'] as int? ?? 3840,
      softwareVersion: json['softwareVersion'] as String? ?? '1.0.0',
      hardwareVersion: json['hardwareVersion'] as int? ?? 1,
      lastSyncedAt: json['lastSyncedAt'] != null || json['last_sync_at'] != null
          ? DateTime.tryParse(json['lastSyncedAt'] as String? ?? json['last_sync_at'] as String? ?? '')
          : null,
      createdAt: json['createdAt'] != null ? DateTime.tryParse(json['createdAt'] as String) ?? DateTime.now() : DateTime.now(),
      updatedAt: json['updatedAt'] != null ? DateTime.tryParse(json['updatedAt'] as String) ?? DateTime.now() : DateTime.now(),
      fabrics: (json['fabrics'] as List<dynamic>?)
              ?.map((item) => MatterFabricModel.fromJson(item as Map<String, dynamic>))
              .toList() ??
          [],
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'deviceId': deviceId,
    'homeId': homeId,
    'deviceName': deviceName,
    'vendorId': vendorId,
    'productId': productId,
    'nodeId': nodeId,
    'deviceType': deviceType,
    'deviceTypeId': deviceTypeId,
    'isCommissioned': isCommissioned,
    'activeFabricsCount': activeFabricsCount,
    'maxFabricsSupported': maxFabricsSupported,
    'passcode': passcode,
    'discriminator': discriminator,
    'softwareVersion': softwareVersion,
    'hardwareVersion': hardwareVersion,
    'lastSyncedAt': lastSyncedAt?.toIso8601String(),
    'createdAt': createdAt.toIso8601String(),
    'updatedAt': updatedAt.toIso8601String(),
  };
}

typedef MatterDeviceModel = MatterDeviceSummary;

class MatterCertificationOverview {
  final String matterCertification;
  final String appleHomeCertification;
  final String googleHomeCertification;
  final String alexaCertification;
  final String physicalHardwareValidation;

  const MatterCertificationOverview({
    this.matterCertification = 'NOT CLAIMED',
    this.appleHomeCertification = 'NOT CLAIMED',
    this.googleHomeCertification = 'NOT CLAIMED',
    this.alexaCertification = 'NOT CLAIMED',
    this.physicalHardwareValidation = 'NOT RUN',
  });

  factory MatterCertificationOverview.initial() => const MatterCertificationOverview();

  factory MatterCertificationOverview.fromJson(Map<String, dynamic> json) {
    return MatterCertificationOverview(
      matterCertification: json['matterCertification'] as String? ?? json['matter_certification'] as String? ?? 'NOT CLAIMED',
      appleHomeCertification: json['appleHomeCertification'] as String? ?? json['apple_home_certification'] as String? ?? 'NOT CLAIMED',
      googleHomeCertification: json['googleHomeCertification'] as String? ?? json['google_home_certification'] as String? ?? 'NOT CLAIMED',
      alexaCertification: json['alexaCertification'] as String? ?? json['alexa_certification'] as String? ?? 'NOT CLAIMED',
      physicalHardwareValidation: json['physicalHardwareValidation'] as String? ?? json['physical_hardware_validation'] as String? ?? 'NOT RUN',
    );
  }

  Map<String, dynamic> toJson() => {
    'matterCertification': matterCertification,
    'appleHomeCertification': appleHomeCertification,
    'googleHomeCertification': googleHomeCertification,
    'alexaCertification': alexaCertification,
    'physicalHardwareValidation': physicalHardwareValidation,
  };
}
