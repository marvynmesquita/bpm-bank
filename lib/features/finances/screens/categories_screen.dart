import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../repositories/finances_repository.dart';
import '../models/category_model.dart';

class CategoriesScreen extends ConsumerStatefulWidget {
  const CategoriesScreen({super.key});

  @override
  ConsumerState<CategoriesScreen> createState() => _CategoriesScreenState();
}

class _CategoriesScreenState extends ConsumerState<CategoriesScreen> {
  final _nameController = TextEditingController();
  final _fixedValueController = TextEditingController();
  final _closingDayController = TextEditingController();
  final _dueDayController = TextEditingController();
  String _selectedType = 'variavel';
  bool _isLoading = false;
  CategoryModel? _editingCategory;

  final List<String> _types = ['credito', 'fixa', 'variavel', 'beneficio', 'outros'];

  @override
  void dispose() {
    _nameController.dispose();
    _fixedValueController.dispose();
    _closingDayController.dispose();
    _dueDayController.dispose();
    super.dispose();
  }

  void _startEdit(CategoryModel cat) {
    setState(() {
      _editingCategory = cat;
      _nameController.text = cat.name;
      _selectedType = _types.contains(cat.type) ? cat.type : 'outros';
      _fixedValueController.text = cat.fixedValue != null ? cat.fixedValue!.toStringAsFixed(2) : '';
      _closingDayController.text = cat.closingDay != null ? cat.closingDay.toString() : '';
      _dueDayController.text = cat.dueDay != null ? cat.dueDay.toString() : '';
    });
  }

  void _cancelEdit() {
    setState(() {
      _editingCategory = null;
      _nameController.clear();
      _fixedValueController.clear();
      _closingDayController.clear();
      _dueDayController.clear();
      _selectedType = 'variavel';
    });
  }

  Future<void> _submitCategory() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) return;
    final fixedValueText = _fixedValueController.text.replaceAll(',', '.');
    final fixedValue = double.tryParse(fixedValueText);
    
    int? closingDay;
    int? dueDay;
    if (_selectedType == 'credito') {
      closingDay = int.tryParse(_closingDayController.text);
      dueDay = int.tryParse(_dueDayController.text);
    } else if (_selectedType == 'fixa') {
      dueDay = int.tryParse(_dueDayController.text);
    }

    setState(() => _isLoading = true);
    try {
      if (_editingCategory == null) {
        await ref.read(financesRepositoryProvider).addCategory(name, _selectedType, fixedValue, closingDay: closingDay, dueDay: dueDay);
      } else {
        final updated = CategoryModel(
          id: _editingCategory!.id,
          name: name,
          type: _selectedType,
          fixedValue: fixedValue,
          closingDay: closingDay,
          dueDay: dueDay,
          createdBy: _editingCategory!.createdBy,
        );
        await ref.read(financesRepositoryProvider).updateCategory(updated);
      }
      
      _cancelEdit();
      ref.invalidate(categoriesProvider);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao salvar categoria: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final categoriesAsync = ref.watch(categoriesProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Categorias')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      flex: 2,
                      child: TextField(
                        controller: _nameController,
                        decoration: InputDecoration(
                          labelText: _editingCategory == null ? 'Nova categoria' : 'Editando categoria',
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        initialValue: _selectedType,
                        items: _types.map((t) => DropdownMenuItem(value: t, child: Text(t))).toList(),
                        onChanged: (val) => setState(() => _selectedType = val!),
                        decoration: const InputDecoration(contentPadding: EdgeInsets.symmetric(horizontal: 8)),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _fixedValueController,
                        decoration: const InputDecoration(
                          labelText: 'Valor Fixo (Opcional)',
                          hintText: 'Ex: 500,00'
                        ),
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      ),
                    ),
                    const SizedBox(width: 8),
                    if (_editingCategory != null)
                      IconButton(
                        onPressed: _cancelEdit,
                        icon: const Icon(Icons.cancel),
                        color: Colors.red,
                      ),
                    IconButton(
                      onPressed: _isLoading ? null : _submitCategory,
                      icon: _isLoading 
                        ? const CircularProgressIndicator() 
                        : Icon(_editingCategory == null ? Icons.add_circle : Icons.check_circle),
                      color: Theme.of(context).primaryColor,
                      iconSize: 32,
                    ),
                  ],
                ),
                if (_selectedType == 'credito' || _selectedType == 'fixa') ...[
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      if (_selectedType == 'credito')
                        Expanded(
                          child: TextField(
                            controller: _closingDayController,
                            decoration: const InputDecoration(
                              labelText: 'Dia de Fechamento',
                              hintText: 'Ex: 5'
                            ),
                            keyboardType: TextInputType.number,
                          ),
                        ),
                      if (_selectedType == 'credito')
                        const SizedBox(width: 8),
                      Expanded(
                        child: TextField(
                          controller: _dueDayController,
                          decoration: const InputDecoration(
                            labelText: 'Dia de Vencimento',
                            hintText: 'Ex: 12'
                          ),
                          keyboardType: TextInputType.number,
                        ),
                      ),
                      if (_editingCategory == null)
                        const SizedBox(width: 48), // Padding para alinhar com o botão da row de cima
                    ],
                  ),
                ],
              ],
            ),
          ),
          const Divider(),
          Expanded(
            child: categoriesAsync.when(
              data: (categories) {
                if (categories.isEmpty) return const Center(child: Text('Nenhuma categoria criada.'));
                return ListView.builder(
                  itemCount: categories.length,
                  itemBuilder: (context, index) {
                    final cat = categories[index];
                    return Dismissible(
                      key: ValueKey(cat.id),
                      direction: DismissDirection.endToStart,
                      background: Container(
                        color: Colors.red,
                        alignment: Alignment.centerRight,
                        padding: const EdgeInsets.only(right: 20),
                        child: const Icon(Icons.delete, color: Colors.white),
                      ),
                      onDismissed: (_) {
                        ref.read(financesRepositoryProvider).deleteCategory(cat.id);
                      },
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: Theme.of(context).primaryColor.withValues(alpha: 0.1),
                          child: Icon(Icons.category, color: Theme.of(context).primaryColor),
                        ),
                        title: Text(cat.name),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Tipo: ${cat.type}'),
                            if (cat.fixedValue != null)
                              Text('Valor fixo: R\$ ${cat.fixedValue!.toStringAsFixed(2)}', style: const TextStyle(color: Colors.green)),
                            if (cat.type == 'credito' && (cat.closingDay != null || cat.dueDay != null))
                              Text('Fechamento: dia ${cat.closingDay ?? "?"} | Vencimento: dia ${cat.dueDay ?? "?"}', style: const TextStyle(color: Colors.orange)),
                            if (cat.type == 'fixa' && cat.dueDay != null)
                              Text('Vencimento: dia ${cat.dueDay}', style: const TextStyle(color: Colors.orange)),
                          ],
                        ),
                        trailing: IconButton(
                          icon: const Icon(Icons.edit),
                          onPressed: () => _startEdit(cat),
                        ),
                      ),
                    );
                  },
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('Erro: $e')),
            ),
          ),
        ],
      ),
    );
  }
}
