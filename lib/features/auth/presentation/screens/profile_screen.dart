import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../backup/presentation/screens/backup_screen.dart';
import '../providers/auth_providers.dart';
import 'login_screen.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);
    final auth = ref.watch(authServiceProvider);

    if (user == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Perfil')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.account_circle_outlined,
                  size: 96,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(height: 16),
                const Text(
                  'Você está no modo anônimo',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Seus produtos ficam salvos apenas neste celular. '
                  'Crie uma conta para fazer backup e sincronizar '
                  'entre dispositivos.',
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 32),
                ElevatedButton.icon(
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const LoginScreen()),
                  ),
                  icon: const Icon(Icons.login),
                  label: const Text('Entrar / Criar conta'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Perfil')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Cabeçalho com avatar
          Center(
            child: Column(
              children: [
                CircleAvatar(
                  radius: 48,
                  backgroundColor:
                      Theme.of(context).colorScheme.primaryContainer,
                  child: Icon(
                    Icons.person,
                    size: 56,
                    color: Theme.of(context).colorScheme.onPrimaryContainer,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  user.email ?? 'Sem e-mail',
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                ),
                const SizedBox(height: 4),
                Text(
  	        	'Conta criada em ${_formatDateString(user.createdAt)}',
  			style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
      		),
              ],
            ),
          ),
          const SizedBox(height: 32),

          // Info
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.backup),
                  title: const Text('Backup e Restauração'),
                  subtitle: const Text('Exportar ou importar seus dados'),
                  trailing: const Icon(Icons.arrow_forward_ios, size: 14),
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const BackupScreen()),
                  ),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.cloud_done_outlined),
                  title: const Text('Sincronização'),
                  subtitle: const Text('Backup dos produtos na nuvem'),
                  trailing: Switch(
                    value: true,
                    onChanged: null,
                  ),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.public),
                  title: const Text('Contribuição ao catálogo'),
                  subtitle: const Text('Você ajuda a base de produtos crescer'),
                  trailing: const Icon(Icons.arrow_forward_ios, size: 14),
                  onTap: () => _showContributionsInfo(context),
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // Sair
          Card(
            child: ListTile(
              leading: const Icon(Icons.logout, color: Colors.red),
              title: const Text(
                'Sair da conta',
                style: TextStyle(color: Colors.red),
              ),
              onTap: () async {
                final confirm = await showDialog<bool>(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    title: const Text('Sair da conta?'),
                    content: const Text(
                      'Seus produtos continuam salvos no celular. '
                      'Para acessá-los em outro dispositivo, entre novamente.',
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(ctx, false),
                        child: const Text('Cancelar'),
                      ),
                      TextButton(
                        onPressed: () => Navigator.pop(ctx, true),
                        child: const Text('Sair', style: TextStyle(color: Colors.red)),
                      ),
                    ],
                  ),
                );
                if (confirm == true && auth != null) {
                  await auth.signOut();
                  if (context.mounted) Navigator.pop(context);
                }
              },
            ),
          ),

          const SizedBox(height: 24),
          Center(
            child: Text(
              'Pre-Venc v1.0.0',
              style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
            ),
          ),
        ],
      ),
    );
  }

  String _formatDateString(String? dateStr) {
    if (dateStr == null || dateStr.isEmpty) return '—';
    try {
      final d = DateTime.parse(dateStr);
      return '${d.day.toString().padLeft(2, '0')}/'
          '${d.month.toString().padLeft(2, '0')}/${d.year}';
    } catch (_) {
      return '—';
    }
  }

  void _showContributionsInfo(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Contribuições ao catálogo'),
        content: const Text(
          'Quando você escaneia um produto desconhecido e confirma o nome, '
          'ele é adicionado ao catálogo público. Isso ajuda todos os usuários '
          'a cadastrarem produtos mais rápido.\n\n'
          'Nenhum dado pessoal (validade, lote) é compartilhado — apenas '
          'o nome, marca e código de barras do produto.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Entendi'),
          ),
        ],
      ),
    );
  }
}
