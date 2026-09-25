import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';
import '../settings_ui.dart';

class SupportRequestPage extends StatefulWidget {
  const SupportRequestPage({super.key});

  @override
  State<SupportRequestPage> createState() => _SupportRequestPageState();
}

class _SupportRequestPageState extends State<SupportRequestPage> {
  final _formKey = GlobalKey<FormState>();
  final _description = TextEditingController();

  @override
  void dispose() {
    _description.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.ehColors;
    return NestedSettingsScaffold(
      title: 'Contact support',
      subtitle: 'Tell us what happened and we\'ll get back to you.',
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 28),
        children: [
          Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextFormField(
                  controller: _description,
                  maxLines: 6,
                  style: TextStyle(
                    color: tokens.textPrimary,
                    fontSize: 15,
                  ),
                  validator: (v) => (v == null || v.trim().isEmpty)
                      ? 'Please describe the issue'
                      : null,
                  decoration: InputDecoration(
                    hintText: 'How can we help? Describe your issue or question in detail...',
                    hintStyle: TextStyle(
                      color: tokens.textTertiary,
                      fontSize: 14,
                    ),
                    filled: true,
                    fillColor: tokens.surfaceCard,
                    contentPadding: const EdgeInsets.all(16),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide(color: tokens.borderSubtle),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide(color: tokens.borderSubtle),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide(color: tokens.bluePrimary, width: 1.5),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: tokens.bluePrimary,
                    foregroundColor: Colors.white,
                    minimumSize: const Size.fromHeight(50),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  onPressed: () {
                    if (!_formKey.currentState!.validate()) return;
                    Navigator.pop(context);
                    showSettingsUnavailable(
                      context,
                      message:
                          'Support requests will be sent when the support backend is connected.',
                    );
                  },
                  child: const Text(
                    'Send request',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
