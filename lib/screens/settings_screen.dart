import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../app_state.dart';
import '../services/ai/ai_factory.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _key = TextEditingController();
  String _provider = 'stub';
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    final st = context.read<AppState>().settings;
    () async {
      _key.text = await st.apiKey();
      _provider = await st.provider();
      if (mounted) setState(() => _loaded = true);
    }();
  }

  @override
  void dispose() {
    _key.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final st = context.read<AppState>().settings;
    await st.setApiKey(_key.text);
    await st.setProvider(_provider);
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Настройки')),
      body: !_loaded
          ? const Center(child: CircularProgressIndicator())
          : ListView(padding: const EdgeInsets.all(16), children: [
              DropdownButtonFormField<String>(
                initialValue: _provider,
                decoration: const InputDecoration(labelText: 'AI-провайдер'),
                items: [
                  for (final e in kProviderIds.entries)
                    DropdownMenuItem(value: e.key, child: Text(e.value)),
                ],
                onChanged: (v) => setState(() => _provider = v ?? 'stub'),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _key,
                obscureText: true,
                autocorrect: false,
                enableSuggestions: false,
                decoration: const InputDecoration(
                  labelText: 'API-ключ',
                  helperText: 'Хранится только на этом телефоне',
                ),
              ),
              const SizedBox(height: 24),
              FilledButton(onPressed: _save, child: const Text('Сохранить')),
            ]),
    );
  }
}
