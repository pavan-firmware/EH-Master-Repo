import 'package:flutter/material.dart';

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
  Widget build(BuildContext context) => NestedSettingsScaffold(
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
                maxLines: 5,
                validator: (v) => (v == null || v.trim().isEmpty)
                    ? 'Describe the issue'
                    : null,
                decoration: InputDecoration(
                  labelText: 'How can we help?',
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: () {
                  if (!_formKey.currentState!.validate()) return;
                  Navigator.pop(context);
                  showSettingsUnavailable(
                    context,
                    message:
                        'Support requests will be sent when the support backend is connected.',
                  );
                },
                child: const Text('Send request'),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}
