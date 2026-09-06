import 'package:flutter/material.dart';

import '../../../core/models/fleet_models.dart';
import '../../../core/repositories/fleet_firmware_repository.dart';
import '../../../core/theme/app_theme.dart';

class FirmwareReleasesPage extends StatefulWidget {
  const FirmwareReleasesPage({
    super.key,
    required this.repository,
  });

  final FleetFirmwareRepository repository;

  @override
  State<FirmwareReleasesPage> createState() => _FirmwareReleasesPageState();
}

class _FirmwareReleasesPageState extends State<FirmwareReleasesPage> {
  late Future<List<FirmwareReleaseModel>> _releasesFuture;
  String _selectedChannel = 'all';

  @override
  void initState() {
    super.initState();
    _loadReleases();
  }

  void _loadReleases() {
    setState(() {
      _releasesFuture = widget.repository.listReleases(
        releaseChannel: _selectedChannel == 'all' ? null : _selectedChannel,
      );
    });
  }

  Future<void> _publishRelease(String releaseId) async {
    try {
      await widget.repository.publishRelease(releaseId);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Firmware release published successfully')),
      );
      _loadReleases();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to publish release: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.ehColors;

    return Scaffold(
      backgroundColor: tokens.bgApp,
      appBar: AppBar(
        title: const Text('Firmware Releases'),
        backgroundColor: tokens.bgApp,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadReleases,
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            child: Row(
              children: [
                const Text('Channel: ', style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(width: 8),
                DropdownButton<String>(
                  value: _selectedChannel,
                  items: const [
                    DropdownMenuItem(value: 'all', child: Text('All Channels')),
                    DropdownMenuItem(value: 'production', child: Text('Production')),
                    DropdownMenuItem(value: 'beta', child: Text('Beta')),
                    DropdownMenuItem(value: 'development', child: Text('Development')),
                  ],
                  onChanged: (val) {
                    if (val != null) {
                      setState(() => _selectedChannel = val);
                      _loadReleases();
                    }
                  },
                ),
              ],
            ),
          ),
          Expanded(
            child: FutureBuilder<List<FirmwareReleaseModel>>(
              future: _releasesFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState != ConnectionState.done) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return Center(
                    child: Text('Error loading releases: ${snapshot.error}'),
                  );
                }
                final releases = snapshot.data ?? [];
                if (releases.isEmpty) {
                  return const Center(
                    child: Text('No firmware releases found'),
                  );
                }
                return ListView.builder(
                  padding: const EdgeInsets.all(16.0),
                  itemCount: releases.length,
                  itemBuilder: (context, index) {
                    final release = releases[index];
                    final isDraft = release.status == 'DRAFT';
                    return Card(
                      margin: const EdgeInsets.only(bottom: 12.0),
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  'v${release.version}',
                                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: release.status == 'PUBLISHED'
                                        ? Colors.green.withValues(alpha: 0.2)
                                        : (release.status == 'REVOKED' ? Colors.red.withValues(alpha: 0.2) : Colors.amber.withValues(alpha: 0.2)),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    release.status,
                                    style: TextStyle(
                                      color: release.status == 'PUBLISHED'
                                          ? Colors.green
                                          : (release.status == 'REVOKED' ? Colors.red : Colors.orange),
                                      fontWeight: FontWeight.bold,
                                      fontSize: 12,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text('Product: ${release.productVariantId}'),
                            Text('Channel: ${release.releaseChannel}'),
                            Text('Binary Size: ${(release.binarySizeBytes / 1024).toStringAsFixed(1)} KB'),
                            Text('SHA-256: ${release.sha256.substring(0, 16)}...'),
                            if (release.minFirmwareVersion != null)
                              Text('Min Supported Version: v${release.minFirmwareVersion}'),
                            if (release.releaseNotes != null) ...[
                              const SizedBox(height: 4),
                              Text('Notes: ${release.releaseNotes}', style: const TextStyle(fontStyle: FontStyle.italic)),
                            ],
                            if (isDraft) ...[
                              const SizedBox(height: 12),
                              ElevatedButton(
                                onPressed: () => _publishRelease(release.id),
                                child: const Text('Publish Release'),
                              ),
                            ],
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
