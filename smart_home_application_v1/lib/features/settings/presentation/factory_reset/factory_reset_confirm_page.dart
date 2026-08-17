import 'package:flutter/material.dart';

import '../../../../core/repositories/factory_reset_repository.dart';import '../settings_ui.dart';import 'factory_reset_result_page.dart';

class FactoryResetConfirmPage extends StatefulWidget {
  const FactoryResetConfirmPage({super.key, required this.repository});

  final FactoryResetRepository repository;

  @override
  State<FactoryResetConfirmPage> createState() => _FactoryResetConfirmPageState();
}

class _FactoryResetConfirmPageState extends State<FactoryResetConfirmPage> {
  final _controller = TextEditingController();
  bool _busy = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _reset() async {
    if (_controller.text.trim() != 'RESET') {
      showSettingsUnavailable(context, message: 'Type RESET to continue.');
      return;
    }
    setState(() => _busy = true);
    final result = await widget.repository.executeReset(confirmation: _controller.text.trim());
    if (!mounted) return;
    if (!result.success) {
      setState(() => _busy = false);
      showSettingsUnavailable(context, message: result.message);
      return;
    }
    final verified = await widget.repository.verifyReset();
    if (!mounted) return;
    setState(() => _busy = false);
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => FactoryResetResultPage(success: verified.success, message: verified.message),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => NestedSettingsScaffold(
    title: 'Confirm factory reset',
    subtitle: 'This permanently removes the device home configuration.',
    child: ListView(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 28),
      children: [
        const SettingsDestructiveBanner(
          title: 'Confirm factory reset',
          body: 'Type RESET to confirm you understand this action cannot be undone.',
        ),
        const SizedBox(height: 20),
        TextField(
          controller: _controller,
          textCapitalization: TextCapitalization.characters,
          decoration: InputDecoration(
            labelText: 'Type RESET to continue',
            filled: true,
            fillColor: Colors.white,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
          ),
        ),
        const SizedBox(height: 20),
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: _busy ? null : () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: FilledButton(
                style: FilledButton.styleFrom(backgroundColor: SettingsColors.red),
                onPressed: _busy ? null : _reset,
                child: _busy
                    ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Text('Factory reset'),
              ),
            ),
          ],
        ),
      ],
    ),
  );
}
