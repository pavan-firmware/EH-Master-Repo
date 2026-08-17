import 'package:flutter/material.dart';

import '../../../core/models/update_models.dart';
import '../../settings/presentation/settings_ui.dart';

class UpdateHistoryPage extends StatelessWidget {
  const UpdateHistoryPage({super.key, required this.history});

  final List<UpdateHistoryEntry> history;

  @override
  Widget build(BuildContext context) => NestedSettingsScaffold(
    title: 'Update history',
    child: ListView(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 28),
      children: [
        SettingsSurface(
          child: Column(
            children: [
              for (var i = 0; i < history.length; i++) ...[
                Material(
                  color: Colors.transparent,
                  child: ListTile(
                    title: Text(history[i].title, style: const TextStyle(fontWeight: FontWeight.w800)),
                    subtitle: Text('${history[i].deviceName} · ${history[i].result}'),
                  ),
                ),
                if (i < history.length - 1) const Divider(height: 1, color: SettingsColors.line),
              ],
            ],
          ),
        ),
      ],
    ),
  );
}
