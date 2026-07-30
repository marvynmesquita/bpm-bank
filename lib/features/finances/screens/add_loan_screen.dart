import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/loan_model.dart';
import '../repositories/finances_repository.dart';

class AddLoanScreen extends ConsumerStatefulWidget {
  final LoanModel? loan;

  const AddLoanScreen({super.key, this.loan});

  @override
  ConsumerState<AddLoanScreen> createState() => _AddLoanScreenState();
}

class _AddLoanScreenState extends ConsumerState<AddLoanScreen> {
  final _borrowerController = TextEditingController();
  final _amountController = TextEditingController();
  final _installmentsController = TextEditingController(text: '1');
  String? _selectedCategoryId;
  bool _isPaid = false;
  bool _isLoading = false;
  DateTime _selectedDate = DateTime.now();

  @override
  void initState() {
    super.initState();
    if (widget.loan != null) {
      final l = widget.loan!;
      _borrowerController.text = l.borrowerName;
      _amountController.text = l.amount.toStringAsFixed(2);
      _selectedCategoryId = l.categoryId;
      _isPaid = l.isPaid;
      _selectedDate = l.date;
    }
  }

  @override
  void dispose() {
    _borrowerController.dispose();
    _amountController.dispose();
    _installmentsController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final borrower = _borrowerController.text.trim();
    final amountText = _amountController.text.replaceAll(',', '.');
    final amount = double.tryParse(amountText);
    final installments = int.tryParse(_installmentsController.text) ?? 1;
    
    if (borrower.isEmpty || amount == null || amount <= 0 || _selectedCategoryId == null || installments < 1) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Preencha todos os campos corretamente.')),
      );
      return;
    }

    setState(() => _isLoading = true);
    try {
      final userId = FirebaseAuth.instance.currentUser!.uid;
      
      if (widget.loan == null) {
        final newLoan = LoanModel(
          id: '',
          userId: userId,
          borrowerName: borrower,
          amount: amount,
          categoryId: _selectedCategoryId!,
          date: _selectedDate,
          isPaid: _isPaid,
        );
        await ref.read(financesRepositoryProvider).addLoan(newLoan, installments: installments);
      } else {
        final updatedLoan = LoanModel(
          id: widget.loan!.id,
          userId: userId,
          borrowerName: borrower,
          amount: amount,
          categoryId: _selectedCategoryId!,
          date: _selectedDate,
          isPaid: _isPaid,
        );
        await ref.read(financesRepositoryProvider).updateLoan(updatedLoan);
      }
      
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

  @override
  Widget build(BuildContext context) {
    final categoriesAsync = ref.watch(categoriesProvider);
    final isEditing = widget.loan != null;

    return Scaffold(
      appBar: AppBar(title: Text(isEditing ? 'Editar Empréstimo' : 'Novo Empréstimo')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextField(
                controller: _borrowerController,
                decoration: const InputDecoration(labelText: 'Nome de quem pegou emprestado'),
                textCapitalization: TextCapitalization.words,
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _amountController,
                decoration: const InputDecoration(labelText: 'Valor (R\$)'),
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
              ),
              const SizedBox(height: 16),
              if (!isEditing)
                TextField(
                  controller: _installmentsController,
                  decoration: const InputDecoration(labelText: 'Parcelas'),
                  keyboardType: TextInputType.number,
                ),
              if (!isEditing) const SizedBox(height: 16),
              categoriesAsync.when(
                data: (categories) {
                  final creditCards = categories.where((c) => c.type == 'credito').toList();
                  if (creditCards.isEmpty) {
                    return const Text('Nenhum cartão de crédito cadastrado. Crie um na aba Perfil > Categorias.', style: TextStyle(color: Colors.red));
                  }
                  
                  return DropdownButtonFormField<String>(
                    value: _selectedCategoryId,
                    hint: const Text('Cartão Utilizado'),
                    items: creditCards.map((c) => DropdownMenuItem(
                      value: c.id,
                      child: Text(c.name),
                    )).toList(),
                    onChanged: (val) => setState(() => _selectedCategoryId = val),
                    decoration: const InputDecoration(filled: true),
                  );
                },
                loading: () => const CircularProgressIndicator(),
                error: (e, _) => Text('Erro ao carregar cartões: $e'),
              ),
              const SizedBox(height: 16),
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text('Data: ${_selectedDate.day.toString().padLeft(2, '0')}/${_selectedDate.month.toString().padLeft(2, '0')}/${_selectedDate.year}'),
                trailing: const Icon(Icons.calendar_today),
                onTap: () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: _selectedDate,
                    firstDate: DateTime(2000),
                    lastDate: DateTime(2100),
                  );
                  if (picked != null && picked != _selectedDate) {
                    setState(() {
                      _selectedDate = picked;
                    });
                  }
                },
              ),
              const SizedBox(height: 16),
              SwitchListTile(
                title: const Text('Empréstimo já foi pago?'),
                value: _isPaid,
                onChanged: (val) => setState(() => _isPaid = val),
                contentPadding: EdgeInsets.zero,
              ),
              const SizedBox(height: 32),
              ElevatedButton(
                onPressed: _isLoading ? null : _submit,
                child: _isLoading 
                    ? const CircularProgressIndicator(color: Colors.white) 
                    : Text(isEditing ? 'Salvar Alterações' : 'Adicionar Empréstimo'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
