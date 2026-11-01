import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/services/notification_service.dart';
import '../../domain/entities/alert_settings.dart';
import '../providers/alerts_providers.dart';

class AlertSettingsScreen extends ConsumerStatefulWidget {
  const AlertSettingsScreen({super.key});

  @override
  ConsumerState<AlertSettingsScreen> createState() =>
      _AlertSettingsScreenState();
}

class _AlertSettingsScreenState extends ConsumerState<AlertSettingsScreen> {
  static const _availableDays = [30, 15, 7, 3, 1, 0];

  late Set<int> _selectedDays;
  bool _enabled = true;
  bool _loaded = false;
  bool _saving = false;
  bool _hasPermission = true;

  @override
  void initState() {
    super.initState();
    _selectedDays = {30, 1};
    _checkPermission();
  }

  Future<void> _checkPermission() async {
    final has = await NotificationService.hasPermission();
    if (mounted) setState(() => _hasPermission = has);
  }

  Future<void> _requestPermission() async {
    final granted = await NotificationService.requestPermission();
    if (mounted) setState(() => _hasPermission = granted);
    if (!granted && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Permissão negada. Os alertas não funcionarão.'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final settingsAsync = ref.watch(alertSettingsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Alertas de vencimento'),
      ),
      body: settingsAsync.when(
        data: (settings) {
          if (!_loaded) {
            _selectedDays = settings.daysBefore.toSet();
            _enabled = settings.enabled;
            _loaded = true;
          }

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // Permissão
              if (!_hasPermission)
                Card(
                  color: Colors.orange.shade50,
                  child: ListTile(
                    leading: const Icon(Icons.warning_amber_rounded,
                        color: Colors.orange),
                    title: const Text('Notificações desativadas'),
                    subtitle: const Text(
                        'Autorize as notificações para receber alertas.'),
                    trailing: TextButton(
                      onPressed: _requestPermission,
                      child: const Text('Autorizar'),
                    ),
                  ),
                ),

              // Toggle geral
              SwitchListTile(
                title: const Text('Alertas ativos'),
                subtitle: const Text(
                    'Receber notificação antes dos produtos vencerem'),
                value: _enabled,
                onChanged: (v) => setState(() => _enabled = v),
              ),

              const Divider(height: 32),

              // Seleção de dias
              Text(
                'Quando avisar?',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              Text(
                'Escolha quantos dias antes do vencimento você quer ser '
                'notificado. Você pode marcar várias opções.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 16),

              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _availableDays.map((d) {
                  final selected = _selectedDays.contains(d);
                  final label = d == 0 ? 'No dia' : '$d dia${d > 1 ? 's' : ''} antes';
                  return FilterChip(
                    label: Text(label),
                    selected: selected,
                    onSelected: _enabled
                        ? (v) {
                            setState(() {
                              if (v) {
                                _selectedDays.add(d);
                              } else {
                                _selectedDays.remove(d);
                              }
                            });
                          }
                        : null,
                  );
                }).toList(),
              ),

              const SizedBox(height: 24),

              if (_enabled && _selectedDays.isEmpty)
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.red.shade50,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.info_outline, color: Colors.red),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Selecione pelo menos um dia para receber alertas.',
                          style: TextStyle(fontSize: 13),
                        ),
                      ),
                    ],
                  ),
                ),

              const SizedBox(height: 24),

              SizedBox(
                height: 48,
                child: ElevatedButton.icon(
                  onPressed: _saving ? null : _save,
                  icon: _saving
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.check),
                  label: Text(_saving ? 'Salvando...' : 'Salvar configurações'),
                ),
              ),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Erro: $e')),
      ),
    );
  }

  Future<void> _save() async {
    if (_enabled && _selectedDays.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Selecione pelo menos um dia.')),
      );
      return;
    }

    if (_enabled && !_hasPermission) {
      await _requestPermission();
      if (!_hasPermission) return;
    }

    setState(() => _saving = true);

    try {
      final sorted = _selectedDays.toList()..sort((a, b) => b.compareTo(a));
      await ref.read(saveAlertSettingsProvider)(
        AlertSettings(daysBefore: sorted, enabled: _enabled),
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Alertas atualizados!')),
      );
      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erro: $e')),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }
}