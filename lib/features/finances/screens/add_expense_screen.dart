import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/expense_model.dart';
import '../repositories/finances_repository.dart';
import '../../auth/repositories/auth_repository.dart';

class AddExpenseScreen extends ConsumerStatefulWidget {
  final ExpenseModel? expense;

  const AddExpenseScreen({super.key, this.expense});

  @override
  ConsumerState<AddExpenseScreen> createState() => _AddExpenseScreenState();
}

class _AddExpenseScreenState extends ConsumerState<AddExpenseScreen> {
  final _amountController = TextEditingController();
  final _descController = TextEditingController();
  final _installmentsController = TextEditingController(text: '1');
  String? _selectedCategoryId;
  bool _isShared = false;
  bool _isRecurring = false;
  bool _isIncome = false;
  bool _isLoading = false;
  DateTime _selectedDate = DateTime.now();

  @override
  void initState() {
    super.initState();
    if (widget.expense != null) {
      final e = widget.expense!;
      if (e.totalInstallments > 1) {
        _amountController.text = (e.amount * e.totalInstallments).toStringAsFixed(2);
      } else {
        _amountController.text = e.amount.toStringAsFixed(2);
      }
      _descController.text = (e.description ?? '').replaceAll(RegExp(r'\s*\(\d+/\d+\)$'), '');
      _installmentsController.text = e.totalInstallments.toString();
      _selectedCategoryId = e.categoryId;
      _isShared = e.sharedWithUserId != null;
      _isRecurring = e.isRecurring;
      _isIncome = e.isIncome;
      _selectedDate = e.date;
    }
  }

  @override
  void dispose() {
    _amountController.dispose();
    _descController.dispose();
    _installmentsController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final amountText = _amountController.text.replaceAll(',', '.');
    final amount = double.tryParse(amountText);
    final installments = int.tryParse(_installmentsController.text) ?? 1;
    
    if (amount == null || amount <= 0 || installments < 1) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Valores inválidos')),
      );
      return;
    }

    setState(() => _isLoading = true);
    try {
      final currentUser = await ref.read(currentUserProvider.future);
      final partnerUid = currentUser?.partnerUid;
      
      if (_isShared && (partnerUid == null || partnerUid.isEmpty)) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Vincule uma parceira(o) no seu Perfil primeiro.')),
          );
          setState(() => _isLoading = false);
        }
        return;
      }

      final userId = FirebaseAuth.instance.currentUser!.uid;
      
      if (widget.expense == null) {
        // Nova despesa
        final newExpense = ExpenseModel(
          id: '',
          userId: userId,
          amount: amount,
          description: _descController.text,
          categoryId: _selectedCategoryId,
          date: _selectedDate,
          sharedWithUserId: _isShared ? partnerUid : null, 
          isRecurring: _isRecurring,
          isIncome: _isIncome,
        );
        await ref.read(financesRepositoryProvider).addExpense(newExpense, installments: installments);
      } else {
        // Editar despesa
        final e = widget.expense!;
        if (e.totalInstallments <= 1 && installments > 1) {
          // Changed from 1 installment (or recurring) to multiple installments
          await ref.read(financesRepositoryProvider).deleteExpense(e.id);
          final newExpense = ExpenseModel(
            id: '',
            userId: userId,
            amount: amount,
            description: _descController.text,
            categoryId: _selectedCategoryId,
            date: _selectedDate,
            sharedWithUserId: _isShared ? partnerUid : null, 
            isRecurring: false, // Se tem parcelas, não é assinatura infinita
            isIncome: _isIncome,
          );
          await ref.read(financesRepositoryProvider).addExpense(newExpense, installments: installments);
        } else {
          final updatedExpense = ExpenseModel(
            id: e.id,
            userId: userId,
            amount: amount,
            description: _descController.text,
            categoryId: _selectedCategoryId,
            date: _selectedDate,
            sharedWithUserId: _isShared ? partnerUid : null, 
            isRecurring: _isRecurring,
            isIncome: _isIncome,
            isPaid: e.isPaid,
            groupId: e.groupId,
            currentInstallment: e.currentInstallment,
            totalInstallments: e.totalInstallments,
          );
          await ref.read(financesRepositoryProvider).updateExpense(updatedExpense);
        }
      }

      ref.invalidate(currentMonthExpensesProvider);
      
      if (mounted) {
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _deleteExpense(String id) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Excluir Registro'),
        content: const Text('Tem certeza que deseja apagar?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Excluir', style: TextStyle(color: Colors.red))),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => _isLoading = true);
    try {
      await ref.read(financesRepositoryProvider).deleteExpense(id);
      ref.invalidate(currentMonthExpensesProvider);
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erro ao excluir: $e')));
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final categoriesAsync = ref.watch(categoriesProvider);
    final isEditing = widget.expense != null;

    return Scaffold(
      appBar: AppBar(
        title: Text(isEditing ? 'Editar Registro' : 'Nova Adição'),
        actions: [
          if (isEditing)
            IconButton(
              icon: const Icon(Icons.delete, color: Colors.red),
              onPressed: () => _deleteExpense(widget.expense!.id),
            ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (!isEditing)
                SegmentedButton<bool>(
                  segments: const [
                    ButtonSegment(value: false, label: Text('Despesa', style: TextStyle(fontSize: 13)), icon: Icon(Icons.arrow_downward, size: 18)),
                    ButtonSegment(value: true, label: Text('Renda Extra', style: TextStyle(fontSize: 13)), icon: Icon(Icons.arrow_upward, size: 18)),
                  ],
                  selected: {_isIncome},
                  onSelectionChanged: (Set<bool> newSelection) {
                    setState(() {
                      _isIncome = newSelection.first;
                    });
                  },
                ),
              if (!isEditing) const SizedBox(height: 16),
              TextField(
                controller: _amountController,
                decoration: const InputDecoration(labelText: 'Valor (R\$)'),
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _descController,
                decoration: const InputDecoration(labelText: 'Descrição'),
              ),
              const SizedBox(height: 16),
              ListTile(
                title: const Text('Data da despesa', style: TextStyle(fontSize: 14, color: Colors.grey)),
                subtitle: Text(
                  '${_selectedDate.day.toString().padLeft(2, '0')}/${_selectedDate.month.toString().padLeft(2, '0')}/${_selectedDate.year}',
                  style: const TextStyle(fontSize: 16, color: Colors.black87),
                ),
                trailing: const Icon(Icons.calendar_today),
                onTap: () async {
                  final date = await showDatePicker(
                    context: context,
                    initialDate: _selectedDate,
                    firstDate: DateTime(2000),
                    lastDate: DateTime(2100),
                  );
                  if (date != null) {
                    setState(() => _selectedDate = date);
                  }
                },
                contentPadding: const EdgeInsets.symmetric(horizontal: 4),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _installmentsController,
                decoration: const InputDecoration(labelText: 'Parcelas'),
                keyboardType: TextInputType.number,
                enabled: !isEditing || widget.expense!.totalInstallments <= 1,
              ),
              const SizedBox(height: 16),
              categoriesAsync.when(
                data: (categories) => DropdownButtonFormField<String>(
                  initialValue: _selectedCategoryId,
                  hint: const Text('Categoria'),
                  items: categories.map((c) => DropdownMenuItem(
                    value: c.id,
                    child: Text(c.name),
                  )).toList(),
                  onChanged: (val) {
                    setState(() => _selectedCategoryId = val);
                    if (!isEditing && val != null) {
                      final selectedCategory = categories.firstWhere((c) => c.id == val);
                      if (selectedCategory.fixedValue != null) {
                        _amountController.text = selectedCategory.fixedValue!.toStringAsFixed(2);
                      }
                    }
                  },
                  decoration: const InputDecoration(filled: true),
                ),
                loading: () => const CircularProgressIndicator(),
                error: (e, _) => Text('Erro ao carregar categorias: $e'),
              ),
              const SizedBox(height: 16),
              SwitchListTile(
                title: const Text('Despesa Recorrente (Assinatura)'),
                value: _isRecurring,
                onChanged: (val) => setState(() => _isRecurring = val),
                contentPadding: EdgeInsets.zero,
              ),
              SwitchListTile(
                title: const Text('Dividir despesa com parceiro(a)'),
                value: _isShared,
                onChanged: (val) => setState(() => _isShared = val),
                contentPadding: EdgeInsets.zero,
              ),
              const SizedBox(height: 32),
              ElevatedButton(
                onPressed: _isLoading ? null : _submit,
                child: _isLoading 
                    ? const CircularProgressIndicator(color: Colors.white) 
                    : Text(isEditing ? 'Salvar' : 'Adicionar'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
