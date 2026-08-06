import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../repositories/auth_repository.dart';
import '../../finances/screens/categories_screen.dart';
import '../../../core/services/update_service.dart';

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  final _incomeController = TextEditingController();
  final _payDayController = TextEditingController();
  final _partnerEmailController = TextEditingController();
  bool _isLoading = false;
  bool _isLoadingPartner = false;
  bool _isCheckingUpdate = false;

  @override
  void dispose() {
    _incomeController.dispose();
    _payDayController.dispose();
    _partnerEmailController.dispose();
    super.dispose();
  }

  Future<void> _updateProfile() async {
    final text = _incomeController.text.replaceAll(',', '.');
    final income = double.tryParse(text);
    final payDay = int.tryParse(_payDayController.text);

    if (income == null || income < 0 || payDay == null || payDay < 1 || payDay > 31) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Valores inválidos. O dia deve ser entre 1 e 31.')),
      );
      return;
    }

    setState(() => _isLoading = true);
    try {
      await ref.read(authRepositoryProvider).updateIncome(income);
      await ref.read(authRepositoryProvider).updatePayDay(payDay);
      ref.invalidate(currentUserProvider);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Configurações atualizadas com sucesso!'), backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao atualizar: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _linkPartner() async {
    final email = _partnerEmailController.text.trim();
    if (email.isEmpty || !email.contains('@')) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('E-mail inválido')),
      );
      return;
    }

    setState(() => _isLoadingPartner = true);
    try {
      await ref.read(authRepositoryProvider).setPartnerEmail(email);
      ref.invalidate(currentUserProvider);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Parceira(o) vinculada(o) com sucesso!'), backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoadingPartner = false);
    }
  }

  Future<void> _checkUpdates() async {
    setState(() => _isCheckingUpdate = true);

    final service = UpdateService();
    final result = await service.checkForUpdatesFull();

    if (!mounted) return;
    setState(() => _isCheckingUpdate = false);

    if (result.status == UpdateStatus.error) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Não foi possível verificar atualizações. Verifique sua conexão e tente novamente.'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    if (result.hasUpdate &&
        result.latestVersion != null &&
        result.downloadUrl != null) {
      final latest = result.latestVersion!;
      final url = result.downloadUrl!;
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Atualização Disponível'),
          content: Text(
            'Uma nova versão ($latest) já está disponível!\n\n'
            'Sua versão atual: ${result.currentVersion}',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Agora não'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                service.downloadUpdate(url);
              },
              child: const Text('Baixar'),
            ),
          ],
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Você já está usando a versão mais recente (${result.currentVersion}).',
          ),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final userAsync = ref.watch(currentUserProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Meu Perfil')),
      body: userAsync.when(
        data: (user) {
          if (user == null) return const Center(child: Text('Usuário não encontrado'));
          
          return SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const CircleAvatar(
                  radius: 50,
                  child: Icon(Icons.person, size: 50),
                ),
                const SizedBox(height: 16),
                Text(
                  user.name,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                  textAlign: TextAlign.center,
                ),
                Text(
                  user.email,
                  style: Theme.of(context).textTheme.bodyMedium,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 32),
                const Text('Configurações Financeiras', style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _incomeController..text = user.monthlyIncome.toString(),
                        decoration: const InputDecoration(
                          labelText: 'Renda (R\$)',
                          prefixText: 'R\$ ',
                        ),
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: TextField(
                        controller: _payDayController..text = user.payDay?.toString() ?? '1',
                        decoration: const InputDecoration(
                          labelText: 'Dia do Pagamento',
                          hintText: 'Ex: 5',
                        ),
                        keyboardType: TextInputType.number,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: _isLoading ? null : _updateProfile,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  child: _isLoading 
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Text('Salvar Configurações'),
                ),
                const SizedBox(height: 32),
                const Text('Vínculo de Parceira(o)', style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                if (user.partnerEmail != null && user.partnerEmail!.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.green.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.green.shade200),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.favorite, color: Colors.green),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Conta vinculada com:', style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold)),
                              Text(user.partnerEmail!, style: const TextStyle(color: Colors.black87)),
                            ],
                          ),
                        ),
                      ],
                    ),
                  )
                else
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _partnerEmailController,
                          decoration: const InputDecoration(
                            labelText: 'E-mail da Parceira(o)',
                            hintText: 'email@exemplo.com',
                          ),
                          keyboardType: TextInputType.emailAddress,
                        ),
                      ),
                      const SizedBox(width: 16),
                      ElevatedButton(
                        onPressed: _isLoadingPartner ? null : _linkPartner,
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                        ),
                        child: _isLoadingPartner 
                            ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                            : const Text('Vincular'),
                      ),
                    ],
                  ),
                const SizedBox(height: 32),
                OutlinedButton.icon(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const CategoriesScreen()),
                    );
                  },
                  icon: const Icon(Icons.category, color: Colors.blue),
                  label: const Text('Gerenciar Categorias', style: TextStyle(color: Colors.blue)),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    side: const BorderSide(color: Colors.blue),
                  ),
                ),
                const SizedBox(height: 16),
                OutlinedButton.icon(
                  onPressed: _isCheckingUpdate ? null : _checkUpdates,
                  icon: _isCheckingUpdate 
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.system_update_alt, color: Colors.purple),
                  label: const Text('Verificar Atualizações', style: TextStyle(color: Colors.purple)),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    side: const BorderSide(color: Colors.purple),
                  ),
                ),
                const SizedBox(height: 16),
                OutlinedButton.icon(
                  onPressed: () async {
                    Navigator.of(context).pop();
                    await ref.read(authRepositoryProvider).signOut();
                  },
                  icon: const Icon(Icons.logout, color: Colors.red),
                  label: const Text('Sair', style: TextStyle(color: Colors.red)),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    side: const BorderSide(color: Colors.red),
                  ),
                ),
              ],
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Erro: $e')),
      ),
    );
  }
}
