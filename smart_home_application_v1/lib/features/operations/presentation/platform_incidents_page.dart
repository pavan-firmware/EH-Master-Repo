import 'package:flutter/material.dart';

/// Platform Incident Model for Flutter Operator View (Phase 43)
class PlatformIncidentItem {
  final String id;
  final String title;
  final String description;
  final String severity; // SEV1, SEV2, SEV3, SEV4
  final String status;   // OPEN, ACKNOWLEDGED, INVESTIGATING, MITIGATING, RESOLVED, CLOSED
  final String affectedComponent;
  final String? commanderUserId;
  final String openedAt;
  final String? rootCause;
  final String? mitigationSummary;
  final List<PlatformIncidentTimelineEntry> timeline;

  const PlatformIncidentItem({
    required this.id,
    required this.title,
    required this.description,
    required this.severity,
    required this.status,
    required this.affectedComponent,
    this.commanderUserId,
    required this.openedAt,
    this.rootCause,
    this.mitigationSummary,
    this.timeline = const [],
  });
}

class PlatformIncidentTimelineEntry {
  final String type;
  final String timestamp;
  final String summary;

  const PlatformIncidentTimelineEntry({
    required this.type,
    required this.timestamp,
    required this.summary,
  });
}

abstract class PlatformIncidentsDataSource {
  Future<List<PlatformIncidentItem>> fetchIncidents({String? status, String? severity});
  Future<PlatformIncidentItem> updateIncidentStatus(String incidentId, String newStatus, {String? notes});
}

class PlatformIncidentsPage extends StatefulWidget {
  final PlatformIncidentsDataSource dataSource;

  const PlatformIncidentsPage({
    super.key,
    required this.dataSource,
  });

  @override
  State<PlatformIncidentsPage> createState() => _PlatformIncidentsPageState();
}

class _PlatformIncidentsPageState extends State<PlatformIncidentsPage> {
  List<PlatformIncidentItem> _incidents = [];
  bool _isLoading = true;
  String? _errorMessage;
  String _selectedFilter = 'ALL'; // ALL, OPEN, INVESTIGATING, RESOLVED

  @override
  void initState() {
    super.initState();
    _loadIncidents();
  }

  Future<void> _loadIncidents() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final statusParam = _selectedFilter == 'ALL' ? null : _selectedFilter;
      final results = await widget.dataSource.fetchIncidents(status: statusParam);
      if (mounted) {
        setState(() {
          _incidents = results;
          _isLoading = false;
        });
      }
    } catch (err) {
      if (mounted) {
        setState(() {
          _errorMessage = err.toString();
          _isLoading = false;
        });
      }
    }
  }

  Color _getSeverityColor(String severity) {
    switch (severity) {
      case 'SEV1':
        return Colors.red.shade700;
      case 'SEV2':
        return Colors.orange.shade800;
      case 'SEV3':
        return Colors.amber.shade800;
      case 'SEV4':
      default:
        return Colors.blue.shade700;
    }
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'OPEN':
        return Colors.red.shade600;
      case 'ACKNOWLEDGED':
        return Colors.orange.shade600;
      case 'INVESTIGATING':
        return Colors.purple.shade600;
      case 'MITIGATING':
        return Colors.indigo.shade600;
      case 'RESOLVED':
        return Colors.teal.shade600;
      case 'CLOSED':
      default:
        return Colors.grey.shade600;
    }
  }

  void _showIncidentDetails(PlatformIncidentItem incident) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return DraggableScrollableSheet(
          initialChildSize: 0.7,
          minChildSize: 0.4,
          maxChildSize: 0.95,
          expand: false,
          builder: (context, scrollController) {
            return Padding(
              padding: const EdgeInsets.all(20.0),
              child: ListView(
                controller: scrollController,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: _getSeverityColor(incident.severity),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          incident.severity,
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: _getStatusColor(incident.status),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          incident.status,
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                        ),
                      ),
                      const Spacer(),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.pop(context),
                      )
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    incident.title,
                    style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Component: ${incident.affectedComponent}',
                    style: TextStyle(color: Colors.grey.shade700, fontWeight: FontWeight.w500),
                  ),
                  if (incident.commanderUserId != null) ...[
                    const SizedBox(height: 4),
                    Text('Commander: ${incident.commanderUserId}', style: const TextStyle(color: Colors.blueGrey)),
                  ],
                  const SizedBox(height: 16),
                  const Text('Description', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  const SizedBox(height: 4),
                  Text(incident.description.isNotEmpty ? incident.description : 'No description provided.'),
                  if (incident.rootCause != null) ...[
                    const SizedBox(height: 16),
                    const Text('Root Cause', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    const SizedBox(height: 4),
                    Text(incident.rootCause!),
                  ],
                  if (incident.mitigationSummary != null) ...[
                    const SizedBox(height: 16),
                    const Text('Mitigation Summary', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    const SizedBox(height: 4),
                    Text(incident.mitigationSummary!),
                  ],
                  const SizedBox(height: 20),
                  const Text('Incident Timeline', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  const SizedBox(height: 8),
                  if (incident.timeline.isEmpty)
                    const Text('No timeline entries recorded.')
                  else
                    ...incident.timeline.map((entry) => Padding(
                          padding: const EdgeInsets.symmetric(vertical: 4.0),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Icon(Icons.timeline, size: 18, color: Colors.blueGrey),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(entry.summary, style: const TextStyle(fontWeight: FontWeight.w600)),
                                    Text(entry.timestamp, style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        )),
                  const SizedBox(height: 24),
                  // Quick Actions
                  if (incident.status != 'CLOSED' && incident.status != 'RESOLVED') ...[
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.teal),
                      onPressed: () async {
                        Navigator.pop(context);
                        await widget.dataSource.updateIncidentStatus(incident.id, 'RESOLVED');
                        _loadIncidents();
                      },
                      child: const Text('Resolve Incident', style: TextStyle(color: Colors.white)),
                    ),
                  ],
                ],
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Platform Incidents'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadIncidents,
          ),
        ],
      ),
      body: Column(
        children: [
          // Filter Chips
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: ['ALL', 'OPEN', 'INVESTIGATING', 'RESOLVED'].map((filter) {
                final isSelected = _selectedFilter == filter;
                return Padding(
                  padding: const EdgeInsets.only(right: 8.0),
                  child: ChoiceChip(
                    label: Text(filter),
                    selected: isSelected,
                    onSelected: (selected) {
                      if (selected) {
                        setState(() {
                          _selectedFilter = filter;
                        });
                        _loadIncidents();
                      }
                    },
                  ),
                );
              }).toList(),
            ),
          ),
          const Divider(height: 1),
          // Incident List
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _errorMessage != null
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text('Error: $_errorMessage', style: const TextStyle(color: Colors.red)),
                            const SizedBox(height: 8),
                            ElevatedButton(
                              onPressed: _loadIncidents,
                              child: const Text('Retry'),
                            ),
                          ],
                        ),
                      )
                    : _incidents.isEmpty
                        ? const Center(
                            child: Text(
                              'No platform incidents found',
                              style: TextStyle(color: Colors.grey, fontSize: 16),
                            ),
                          )
                        : ListView.separated(
                            itemCount: _incidents.length,
                            separatorBuilder: (context, index) => const Divider(height: 1),
                            itemBuilder: (context, index) {
                              final inc = _incidents[index];
                              return ListTile(
                                leading: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: _getSeverityColor(inc.severity),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    inc.severity,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 12,
                                    ),
                                  ),
                                ),
                                title: Text(inc.title, style: const TextStyle(fontWeight: FontWeight.bold)),
                                subtitle: Text(
                                  '${inc.affectedComponent} • Opened: ${inc.openedAt}',
                                  style: const TextStyle(fontSize: 12),
                                ),
                                trailing: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: _getStatusColor(inc.status).withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(4),
                                    border: Border.all(color: _getStatusColor(inc.status)),
                                  ),
                                  child: Text(
                                    inc.status,
                                    style: TextStyle(
                                      color: _getStatusColor(inc.status),
                                      fontWeight: FontWeight.bold,
                                      fontSize: 11,
                                    ),
                                  ),
                                ),
                                onTap: () => _showIncidentDetails(inc),
                              );
                            },
                          ),
          ),
        ],
      ),
    );
  }
}
