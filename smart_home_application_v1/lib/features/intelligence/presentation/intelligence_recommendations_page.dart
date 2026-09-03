import 'package:flutter/material.dart';
import '../../../core/models/intelligence_models.dart';
import '../../../core/services/intelligence_service.dart';

class IntelligenceRecommendationsPage extends StatefulWidget {
  final String homeId;
  final HomeIntelligenceService service;

  const IntelligenceRecommendationsPage({
    super.key,
    required this.homeId,
    required this.service,
  });

  @override
  State<IntelligenceRecommendationsPage> createState() => _IntelligenceRecommendationsPageState();
}

class _IntelligenceRecommendationsPageState extends State<IntelligenceRecommendationsPage> {
  DecisionStatus? _selectedStatus;

  @override
  void initState() {
    super.initState();
    _fetch();
  }

  Future<void> _fetch() async {
    await widget.service.fetchRecommendations(
      widget.homeId,
      status: _selectedStatus,
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.service,
      builder: (context, _) {
        final recs = widget.service.recommendations;
        final isLoading = widget.service.isLoading;

        return Scaffold(
          appBar: AppBar(
            title: const Text('Recommendations'),
            actions: [
              IconButton(icon: const Icon(Icons.refresh), onPressed: _fetch),
            ],
          ),
          body: Column(
            children: [
              _buildFilterBar(),
              Expanded(
                child: RefreshIndicator(
                  onRefresh: _fetch,
                  child: isLoading && recs.isEmpty
                      ? const Center(child: CircularProgressIndicator())
                      : recs.isEmpty
                          ? const Center(child: Text('No recommendations found for filter.'))
                          : ListView.builder(
                              padding: const EdgeInsets.all(16.0),
                              itemCount: recs.length,
                              itemBuilder: (context, index) {
                                return _buildFullRecommendationCard(recs[index]);
                              },
                            ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildFilterBar() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      child: Row(
        children: [
          FilterChip(
            label: const Text('All'),
            selected: _selectedStatus == null,
            onSelected: (_) {
              setState(() => _selectedStatus = null);
              _fetch();
            },
          ),
          const SizedBox(width: 8),
          FilterChip(
            label: const Text('Pending'),
            selected: _selectedStatus == DecisionStatus.generated,
            onSelected: (_) {
              setState(() => _selectedStatus = DecisionStatus.generated);
              _fetch();
            },
          ),
          const SizedBox(width: 8),
          FilterChip(
            label: const Text('Accepted'),
            selected: _selectedStatus == DecisionStatus.accepted,
            onSelected: (_) {
              setState(() => _selectedStatus = DecisionStatus.accepted);
              _fetch();
            },
          ),
          const SizedBox(width: 8),
          FilterChip(
            label: const Text('Rejected'),
            selected: _selectedStatus == DecisionStatus.rejected,
            onSelected: (_) {
              setState(() => _selectedStatus = DecisionStatus.rejected);
              _fetch();
            },
          ),
        ],
      ),
    );
  }

  Widget _buildFullRecommendationCard(IntelligenceRecommendation rec) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16.0),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    rec.title,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                ),
                _buildConfidenceBadge(rec.confidence),
              ],
            ),
            const SizedBox(height: 8),
            Text(rec.description, style: TextStyle(color: Colors.grey.shade800, fontSize: 13)),
            const SizedBox(height: 12),

            // Evidence Expansion Tile
            ExpansionTile(
              tilePadding: EdgeInsets.zero,
              title: const Text('Reasoning & Evidence', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
              children: [
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.grey.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    rec.evidence.entries.map((e) => '• ${e.key}: ${e.value}').join('\n'),
                    style: const TextStyle(fontSize: 12, fontFamily: 'monospace'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),

            // Expected Benefit
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.teal.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  const Icon(Icons.verified, color: Colors.teal, size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      rec.expectedBenefit,
                      style: const TextStyle(color: Colors.teal, fontWeight: FontWeight.w600, fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),

            if (rec.status == DecisionStatus.generated) ...[
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  OutlinedButton(
                    onPressed: () async {
                      await widget.service.rejectRecommendation(widget.homeId, rec.id);
                    },
                    child: const Text('Reject'),
                  ),
                  const SizedBox(width: 10),
                  FilledButton(
                    onPressed: () async {
                      await widget.service.acceptRecommendation(widget.homeId, rec.id);
                    },
                    child: const Text('Accept & Execute'),
                  ),
                ],
              ),
            ] else ...[
              const SizedBox(height: 12),
              Align(
                alignment: Alignment.centerRight,
                child: Chip(
                  label: Text(rec.status.toApiValue(), style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildConfidenceBadge(ConfidenceLevel level) {
    Color color;
    switch (level) {
      case ConfidenceLevel.high:
        color = Colors.green;
        break;
      case ConfidenceLevel.low:
        color = Colors.orange;
        break;
      case ConfidenceLevel.medium:
        color = Colors.blue;
        break;
    }
    return Chip(
      label: Text('Conf: ${level.toApiValue()}', style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.bold)),
      backgroundColor: color.withValues(alpha: 0.1),
      visualDensity: VisualDensity.compact,
    );
  }
}
