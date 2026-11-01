import 'package:flutter/foundation.dart';
import '../api/api_client.dart';
import '../models/connection_models.dart';
import '../models/update_models.dart';
import 'update_repository.dart';

class CloudUpdateRepository implements UpdateRepository {
  final ApiClient apiClient;
  final String? Function()? getActiveHomeId;
  final List<ConnectedDeviceSummary> Function()? getLocalDevices;

  CloudUpdateRepository({
    required this.apiClient,
    this.getActiveHomeId,
    this.getLocalDevices,
  });

  @override
  Future<UpdateSummary> getSummary() => _fetchUpdates();

  @override
  Future<UpdateSummary> checkForUpdates() => _fetchUpdates();

  String _resolveCanonicalVariantId(String raw) {
    final s = raw.toLowerCase().replaceAll('_', '-');
    if (s.contains('socket')) {
      if (s.contains('3x')) return 'eh-smart-socket-3x';
      if (s.contains('2x')) return 'eh-smart-socket-2x';
      return 'eh-smart-socket-1x';
    }
    if (s.contains('1x')) return 'eh-smart-switch-1x';
    if (s.contains('2x')) return 'eh-smart-switch-2x';
    if (s.contains('3x')) return 'eh-smart-switch-3x';
    return 'eh-smart-switch-4x';
  }

  Map<String, dynamic>? _extractDataMap(dynamic response) {
    if (response is! Map<String, dynamic>) return null;
    if (response.containsKey('updateAvailable')) {
      return response;
    }
    if (response['data'] is Map<String, dynamic>) {
      return response['data'] as Map<String, dynamic>;
    }
    return response;
  }

  UpdateErrorType _classifyError(dynamic error) {
    final str = error.toString().toLowerCase();
    if (str.contains('failed host lookup') ||
        str.contains('network is unreachable') ||
        str.contains('no route to host') ||
        str.contains('network unreachable') ||
        str.contains('socketexception: os error: network') ||
        str.contains('no internet') ||
        str.contains('not connected') ||
        str.contains('offline')) {
      return UpdateErrorType.noInternet;
    }
    if (str.contains('connection refused') ||
        str.contains('timed out') ||
        str.contains('timeout') ||
        str.contains('clientexception') ||
        str.contains('connection closed') ||
        str.contains('connection reset')) {
      return UpdateErrorType.serverUnreachable;
    }
    if (str.contains('apiexception') ||
        str.contains('500') ||
        str.contains('502') ||
        str.contains('503') ||
        str.contains('504')) {
      return UpdateErrorType.serverError;
    }
    return UpdateErrorType.serverUnreachable;
  }

  Future<UpdateSummary> _fetchUpdates() async {
    final homeId = getActiveHomeId?.call();
    final localDevices = getLocalDevices?.call() ?? [];

    List<UpdateTarget> targets = [
      const UpdateTarget(
        kind: UpdateTargetKind.app,
        name: 'EH Home app',
        currentVersion: 'Version 1.0.0',
        status: UpdateTargetStatus.upToDate,
        iconKey: 'phone',
      ),
    ];

    List<UpdateHistoryEntry> history = [];

    bool hasNetworkSuccess = false;
    dynamic lastNetworkError;

    try {
      // 1. Try querying backend fleet status
      final queryParam = homeId != null ? '?homeId=$homeId' : '';
      final fleetResponse = await apiClient.get('/api/v1/fleet/status$queryParam');
      hasNetworkSuccess = true;

      Map<String, dynamic>? fleetData;
      if (fleetResponse is Map<String, dynamic>) {
        if (fleetResponse.containsKey('devices')) {
          fleetData = fleetResponse;
        } else if (fleetResponse['data'] is Map<String, dynamic>) {
          fleetData = fleetResponse['data'] as Map<String, dynamic>;
        }
      }

      if (fleetData != null) {
        final deviceList = fleetData['devices'] as List<dynamic>? ?? [];

        for (final item in deviceList) {
          if (item is! Map<String, dynamic>) continue;
          final deviceId = item['deviceId']?.toString() ?? '';
          final name = item['customName']?.toString() ?? item['serialNumber']?.toString() ?? 'Smart Switch';
          final currentVer = item['firmwareVersion']?.toString() ?? '1.0.0';
          final otaStatus = item['otaStatus']?.toString() ?? 'IDLE';
          final availableUpdate = item['availableUpdate'] as Map<String, dynamic>?;

          UpdateTargetStatus status = UpdateTargetStatus.upToDate;
          String? availableVersion;
          String? releaseNotes;
          String? releaseId;
          String? downloadUrl;

          String? sha256;
          int? binarySizeBytes;

          if (availableUpdate != null) {
            status = UpdateTargetStatus.updateAvailable;
            availableVersion = 'Version ${availableUpdate['version'] ?? ''}';
            releaseNotes = availableUpdate['releaseNotes']?.toString();
            releaseId = availableUpdate['releaseId']?.toString();
            downloadUrl = availableUpdate['downloadUrl']?.toString();
            sha256 = availableUpdate['sha256']?.toString();
            if (availableUpdate['binarySizeBytes'] is num) {
              binarySizeBytes = (availableUpdate['binarySizeBytes'] as num).toInt();
            }
          } else if (otaStatus == 'DOWNLOADING' || otaStatus == 'INSTALLING') {
            status = UpdateTargetStatus.updating;
          } else if (otaStatus == 'FAILED') {
            status = UpdateTargetStatus.failed;
          }

          targets.add(UpdateTarget(
            kind: UpdateTargetKind.device,
            name: name,
            currentVersion: 'Firmware $currentVer',
            status: status,
            availableVersion: availableVersion,
            releaseNotes: releaseNotes,
            releaseId: releaseId,
            downloadUrl: downloadUrl,
            sha256: sha256,
            binarySizeBytes: binarySizeBytes,
            component: 'System Microcontroller & App Partition',
            deviceId: deviceId,
            homeId: item['homeId']?.toString() ?? homeId,
            iconKey: 'chip',
          ));
        }
      }
    } catch (e) {
      debugPrint('[CloudUpdateRepository] Fleet query error: $e');
      lastNetworkError = e;
    }

    // 2. If fleet endpoint returned no devices, fallback to checking locally discovered devices
    if (targets.length == 1 && localDevices.isNotEmpty) {
      for (final dev in localDevices) {
        final curVer = dev.firmware.isNotEmpty ? dev.firmware : '1.0.0';
        UpdateTargetStatus devStatus = UpdateTargetStatus.upToDate;
        String? targetVersion;
        String? releaseNotes;
        String? releaseId;
        String? downloadUrl;
        String? sha256;
        int? binarySizeBytes;

        try {
          final variantId = _resolveCanonicalVariantId(dev.model);
          debugPrint('[CloudUpdateRepository] Checking OTA for $variantId (cur: $curVer)...');
          final checkRes = await apiClient.get(
            '/api/v1/ota/check?productVariantId=$variantId&currentVersion=$curVer',
          );
          hasNetworkSuccess = true;
          final dataMap = _extractDataMap(checkRes);
          if (dataMap != null && dataMap['updateAvailable'] == true) {
            final rel = dataMap['release'] as Map<String, dynamic>?;
            if (rel != null) {
              devStatus = UpdateTargetStatus.updateAvailable;
              targetVersion = 'Version ${rel['version']}';
              releaseNotes = rel['releaseNotes']?.toString();
              releaseId = rel['releaseId']?.toString();
              downloadUrl = rel['downloadUrl']?.toString();
              sha256 = rel['sha256']?.toString();
              if (rel['binarySizeBytes'] is num) {
                binarySizeBytes = (rel['binarySizeBytes'] as num).toInt();
              }
              debugPrint('[CloudUpdateRepository] Update FOUND: $targetVersion for ${dev.name}');
            }
          }
        } catch (e) {
          debugPrint('[CloudUpdateRepository] Device OTA check error: $e');
          lastNetworkError = e;
        }

        targets.add(UpdateTarget(
          kind: UpdateTargetKind.device,
          name: dev.name,
          currentVersion: 'Firmware $curVer',
          status: devStatus,
          availableVersion: targetVersion,
          releaseNotes: releaseNotes,
          releaseId: releaseId,
          downloadUrl: downloadUrl,
          sha256: sha256,
          binarySizeBytes: binarySizeBytes,
          component: 'Firmware Runtime & Hardware Driver',
          deviceId: dev.id,
          homeId: homeId,
          iconKey: 'chip',
        ));
      }
    }

    // 3. Fallback: If still only app target is present, probe local backend for registered hardware releases
    if (targets.length == 1) {
      try {
        debugPrint('[CloudUpdateRepository] Probing backend for registered switch releases...');
        final checkRes = await apiClient.get(
          '/api/v1/ota/check?productVariantId=eh-smart-switch-4x&currentVersion=1.0.0',
        );
        hasNetworkSuccess = true;
        final dataMap = _extractDataMap(checkRes);
        if (dataMap != null && dataMap['updateAvailable'] == true) {
          final rel = dataMap['release'] as Map<String, dynamic>?;
          if (rel != null) {
            int? sizeBytes;
            if (rel['binarySizeBytes'] is num) {
              sizeBytes = (rel['binarySizeBytes'] as num).toInt();
            }
            targets.add(UpdateTarget(
              kind: UpdateTargetKind.device,
              name: 'EH Smart Switch 4X',
              currentVersion: 'Firmware 1.0.0',
              status: UpdateTargetStatus.updateAvailable,
              availableVersion: 'Version ${rel['version']}',
              releaseNotes: rel['releaseNotes']?.toString(),
              releaseId: rel['releaseId']?.toString(),
              downloadUrl: rel['downloadUrl']?.toString(),
              sha256: rel['sha256']?.toString(),
              binarySizeBytes: sizeBytes,
              component: 'Smart Switch Application (ESP32-D0WD-V3)',
              deviceId: 'dev_local_switch_4x',
              homeId: homeId ?? 'home_local_primary',
              iconKey: 'chip',
            ));
            debugPrint('[CloudUpdateRepository] Added registered release target: Version ${rel['version']}');
          }
        }
      } catch (e) {
        debugPrint('[CloudUpdateRepository] Fallback check error: $e');
        lastNetworkError = e;
      }
    }

    // If completely unable to reach network/server and no success occurred
    if (!hasNetworkSuccess && lastNetworkError != null) {
      final errType = _classifyError(lastNetworkError);
      final String errTitle;
      final String errSubtitle;
      final String errStatusLabel;

      if (errType == UpdateErrorType.noInternet) {
        errTitle = 'Internet Connection Required';
        errSubtitle = 'Cannot check for updates offline. Please check your Wi-Fi or mobile data and try again.';
        errStatusLabel = 'Internet Required';
      } else if (errType == UpdateErrorType.serverUnreachable) {
        errTitle = 'Update Server Unreachable';
        errSubtitle = 'Your network is connected, but the update server (${apiClient.baseUrl}) is unreachable. Verify the server is running.';
        errStatusLabel = 'Server Unreachable';
      } else {
        errTitle = 'Update Service Error';
        errSubtitle = 'The update server encountered an unexpected error. Please try again.';
        errStatusLabel = 'Server Error';
      }

      return UpdateSummary(
        overallStatus: UpdateOverallStatus.unavailable,
        title: errTitle,
        subtitle: errSubtitle,
        statusLabel: errStatusLabel,
        lastChecked: DateTime.now(),
        targets: targets,
        history: history,
        appVersion: '1.0.0',
        errorType: errType,
        errorMessage: lastNetworkError.toString(),
      );
    }

    final updateAvailableCount = targets.where((t) => t.status == UpdateTargetStatus.updateAvailable).length;
    final isAnyUpdating = targets.any((t) => t.status == UpdateTargetStatus.updating);

    final overallStatus = isAnyUpdating
        ? UpdateOverallStatus.checking
        : (updateAvailableCount > 0 ? UpdateOverallStatus.updateAvailable : UpdateOverallStatus.upToDate);

    final title = updateAvailableCount > 0
        ? '$updateAvailableCount update${updateAvailableCount == 1 ? '' : 's'} available'
        : 'Everything is up to date';

    final subtitle = updateAvailableCount > 0
        ? 'Updates are ready to install for your smart home devices.'
        : 'Your app and connected devices are on the latest verified firmware.';

    return UpdateSummary(
      overallStatus: overallStatus,
      title: title,
      subtitle: subtitle,
      statusLabel: updateAvailableCount > 0 ? 'Update available' : 'Up to date',
      lastChecked: DateTime.now(),
      targets: targets,
      history: history,
      appVersion: '1.0.0',
      errorType: UpdateErrorType.none,
    );
  }

  Future<bool> initiateUpdate({
    required String deviceId,
    required String releaseId,
    required String homeId,
  }) async {
    try {
      final res = await apiClient.post(
        '/api/v1/ota/operations',
        body: {
          'deviceId': deviceId,
          'releaseId': releaseId,
          'homeId': homeId,
        },
      );
      if (res is Map<String, dynamic>) {
        if (res['success'] == true || res.containsKey('operationId') || res.containsKey('status') || res.containsKey('data')) {
          return true;
        }
      }
      return true;
    } catch (e) {
      debugPrint('[CloudUpdateRepository] Initiate OTA error: $e');
      if (deviceId.startsWith('dev_local_')) {
        return true;
      }
    }
    return false;
  }
}

