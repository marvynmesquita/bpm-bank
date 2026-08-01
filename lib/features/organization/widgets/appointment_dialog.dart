import 'package:flutter/material.dart';
import '../repositories/organization_repository.dart';
import '../models/appointment_model.dart';

void showAppointmentDialog(BuildContext context, OrganizationRepository repo, {AppointmentModel? appointment}) {
  final titleController = TextEditingController(text: appointment?.title);
  final costController = TextEditingController(
    text: appointment?.expectedCost != null ? appointment!.expectedCost!.toStringAsFixed(2) : ''
  );
  DateTime selectedDate = appointment?.date ?? DateTime.now();
  bool isLoading = false;

  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
    builder: (ctx) {
      return StatefulBuilder(
        builder: (context, setState) {
          return Padding(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(ctx).viewInsets.bottom,
              left: 24,
              right: 24,
              top: 24,
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    appointment == null ? 'Novo Compromisso' : 'Editar Compromisso',
                    style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: titleController,
                    decoration: const InputDecoration(labelText: 'Título do compromisso'),
                    textCapitalization: TextCapitalization.sentences,
                  ),
                  const SizedBox(height: 16),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text('Data: ${selectedDate.day}/${selectedDate.month}/${selectedDate.year}'),
                    trailing: const Icon(Icons.calendar_today),
                    onTap: () async {
                      final date = await showDatePicker(
                        context: context,
                        initialDate: selectedDate,
                        firstDate: DateTime(2000), 
                        lastDate: DateTime(2100),
                      );
                      if (date != null) {
                        setState(() => selectedDate = date);
                      }
                    },
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: costController,
                    decoration: const InputDecoration(
                      labelText: 'Custo Previsto (R\$)',
                      hintText: 'Opcional',
                    ),
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: isLoading ? null : () async {
                      final title = titleController.text.trim();
                      if (title.isEmpty) return;
                      
                      final costText = costController.text.replaceAll(',', '.');
                      final cost = double.tryParse(costText);

                      setState(() => isLoading = true);
                      try {
                        if (appointment == null) {
                          await repo.addAppointment(title, selectedDate, expectedCost: cost);
                        } else {
                          final updated = appointment.copyWith(
                            title: title,
                            date: selectedDate,
                            expectedCost: cost,
                          );
                          await repo.updateAppointment(updated);
                        }
                        if (ctx.mounted) Navigator.pop(ctx);
                      } catch (e) {
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erro: $e')));
                        setState(() => isLoading = false);
                      }
                    },
                    child: isLoading ? const CircularProgressIndicator(color: Colors.white) : const Text('Salvar'),
                  ),
                  if (appointment != null) ...[
                    const SizedBox(height: 8),
                    TextButton(
                      onPressed: isLoading ? null : () async {
                        setState(() => isLoading = true);
                        try {
                          await repo.deleteAppointment(appointment.id);
                          if (ctx.mounted) Navigator.pop(ctx);
                        } catch (e) {
                          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erro ao apagar: $e')));
                          setState(() => isLoading = false);
                        }
                      },
                      child: const Text('Excluir Compromisso', style: TextStyle(color: Colors.red)),
                    ),
                  ],
                  const SizedBox(height: 24),
                ],
              ),
            ),
          );
        },
      );
    },
  );
}
