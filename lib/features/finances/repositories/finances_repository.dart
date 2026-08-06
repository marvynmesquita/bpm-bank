import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:rxdart/rxdart.dart';
import '../models/category_model.dart';
import '../models/expense_model.dart';
import '../models/loan_model.dart';
import '../../auth/repositories/auth_repository.dart';
import '../../../core/services/notification_service.dart';

final financesRepositoryProvider = Provider<FinancesRepository>((ref) {
  return FinancesRepository(FirebaseFirestore.instance, FirebaseAuth.instance);
});

final categoriesProvider = StreamProvider<List<CategoryModel>>((ref) async* {
  final repo = ref.watch(financesRepositoryProvider);
  final user = await ref.watch(currentUserProvider.future);
  
  if (user == null) {
    yield [];
    return;
  }
  
  await for (final categories in repo.getCategories(user.id, user.partnerUid)) {
    yield categories;
  }
});

final selectedMonthProvider = StateProvider<DateTime>((ref) => DateTime.now());

final currentMonthExpensesProvider = StreamProvider<List<ExpenseModel>>((ref) async* {
  final repo = ref.watch(financesRepositoryProvider);
  final categories = await ref.watch(categoriesProvider.future);
  final user = await ref.watch(currentUserProvider.future);
  final payDay = user?.payDay ?? 1;
  final baseDate = ref.watch(selectedMonthProvider);

  int safeDay(int year, int month, int day) {
    final max = DateTime(year, month + 1, 0).day;
    return day > max ? max : day;
  }

  DateTime start, end;
  if (baseDate.day >= payDay) {
    start = DateTime(baseDate.year, baseDate.month, safeDay(baseDate.year, baseDate.month, payDay));
    end = DateTime(baseDate.year, baseDate.month + 1, safeDay(baseDate.year, baseDate.month + 1, payDay)).subtract(const Duration(days: 1));
  } else {
    start = DateTime(baseDate.year, baseDate.month - 1, safeDay(baseDate.year, baseDate.month - 1, payDay));
    end = DateTime(baseDate.year, baseDate.month, safeDay(baseDate.year, baseDate.month, payDay)).subtract(const Duration(days: 1));
  }

  // Widen the query to account for credit card closing days (up to 40 days shift)
  final queryStart = start.subtract(const Duration(days: 45));
  final queryEnd = end.add(const Duration(days: 45));

  final stream = repo.getExpensesStream(queryStart: queryStart, queryEnd: queryEnd, payDay: payDay);
  
  await for (final expenses in stream) {
    final mapped = expenses.map((e) {
      final category = categories.where((c) => c.id == e.categoryId).firstOrNull;
      return ExpenseModel(
        id: e.id,
        userId: e.userId,
        categoryId: e.categoryId,
        category: category,
        amount: e.amount,
        description: e.description,
        date: e.date,
        sharedWithUserId: e.sharedWithUserId,
        isPaid: e.isPaid,
        isRecurring: e.isRecurring,
        currentInstallment: e.currentInstallment,
        totalInstallments: e.totalInstallments,
      );
    }).toList();

    // Filtra localmente baseado na data efetiva (para cartões de crédito)
    final filtered = mapped.where((e) {
      DateTime effectiveDate = e.date;
      if (e.category != null && e.category!.type == 'credito' && e.category!.closingDay != null) {
        int closingDay = e.category!.closingDay!;
        int dueDay = e.category!.dueDay ?? closingDay;
        
        int invoiceMonth = e.date.month;
        int invoiceYear = e.date.year;

        if (e.date.day >= closingDay) invoiceMonth += 1;
        if (dueDay < closingDay) invoiceMonth += 1;

        effectiveDate = DateTime(invoiceYear, invoiceMonth, dueDay);
      }

      final normalizedEffective = DateTime(effectiveDate.year, effectiveDate.month, effectiveDate.day);
      final normalizedStart = DateTime(start.year, start.month, start.day);
      final normalizedEnd = DateTime(end.year, end.month, end.day);

      return (normalizedEffective.isAfter(normalizedStart) || normalizedEffective.isAtSameMomentAs(normalizedStart)) &&
             (normalizedEffective.isBefore(normalizedEnd) || normalizedEffective.isAtSameMomentAs(normalizedEnd));
    }).toList();

    filtered.sort((a, b) => b.date.compareTo(a.date));
    yield filtered;
  }
});

final loansProvider = StreamProvider<List<LoanModel>>((ref) {
  final repo = ref.watch(financesRepositoryProvider);
  final baseDate = ref.watch(selectedMonthProvider);
  return repo.getLoans(baseDate: baseDate);
});

class FinancesRepository {
  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;

  FinancesRepository(this._firestore, this._auth);

  // --- CATEGORIAS ---

  Stream<List<CategoryModel>> getCategories(String userId, String? partnerUid) {
    final ids = [userId];
    if (partnerUid != null && partnerUid.isNotEmpty) {
      ids.add(partnerUid);
    }

    return _firestore
        .collection('categories')
        .where('created_by', whereIn: ids)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => CategoryModel.fromJson(doc.data(), doc.id))
            .toList());
  }

  Future<void> addCategory(String name, String type, double? fixedValue, {int? closingDay, int? dueDay}) async {
    final userId = _auth.currentUser?.uid;
    if (userId == null) throw Exception("User not logged in");

    final category = CategoryModel(
      id: '',
      name: name,
      type: type,
      fixedValue: fixedValue,
      closingDay: closingDay,
      dueDay: dueDay,
      createdBy: userId,
    );

    final docRef = await _firestore.collection('categories').add(category.toJson());
    
    if (type == 'credito' && (closingDay != null || dueDay != null)) {
      final savedCategory = CategoryModel(
        id: docRef.id,
        name: name,
        type: type,
        fixedValue: fixedValue,
        closingDay: closingDay,
        dueDay: dueDay,
        createdBy: userId,
      );
      await NotificationService().scheduleCardNotifications(savedCategory);
    }
  }

  Future<void> updateCategory(CategoryModel category) async {
    await _firestore.collection('categories').doc(category.id).update(category.toJson());
    if (category.type == 'credito') {
      await NotificationService().cancelCardNotifications(category.id);
      await NotificationService().scheduleCardNotifications(category);
    }
  }

  Future<void> deleteCategory(String categoryId) async {
    await _firestore.collection('categories').doc(categoryId).delete();
    await NotificationService().cancelCardNotifications(categoryId);
  }

  // --- DESPESAS ---

  Stream<List<ExpenseModel>> getExpensesStream({required DateTime queryStart, required DateTime queryEnd, int payDay = 1}) {
    final userId = _auth.currentUser?.uid;
    if (userId == null) return Stream.value([]);

    final startStr = queryStart.toIso8601String().split('T').first;
    final endStr = queryEnd.toIso8601String().split('T').first;

    // Despesas do período
    final currentStream = _firestore
        .collection('expenses')
        .where(Filter.or(
          Filter('user_id', isEqualTo: userId),
          Filter('shared_with_user_id', isEqualTo: userId),
        ))
        .where('date', isGreaterThanOrEqualTo: startStr)
        .where('date', isLessThanOrEqualTo: endStr)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => ExpenseModel.fromJson(doc.data(), doc.id))
            .toList());

    // Despesas recorrentes passadas
    final pastRecurringStream = _firestore
        .collection('expenses')
        .where(Filter.or(
          Filter('user_id', isEqualTo: userId),
          Filter('shared_with_user_id', isEqualTo: userId),
        ))
        .where('is_recurring', isEqualTo: true)
        .where('date', isLessThan: startStr)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => ExpenseModel.fromJson(doc.data(), doc.id))
            .expand((e) {
              // Geramos instâncias virtuais para os meses dentro da janela (queryStart até queryEnd)
              final List<ExpenseModel> virtualExpenses = [];
              DateTime current = DateTime(queryStart.year, queryStart.month, e.date.day);
              if (current.isBefore(queryStart)) {
                current = DateTime(queryStart.year, queryStart.month + 1, e.date.day);
              }
              
              while (current.isBefore(queryEnd) || current.isAtSameMomentAs(queryEnd)) {
                virtualExpenses.add(ExpenseModel(
                  id: '${e.id}_${current.year}_${current.month}', // fake id
                  userId: e.userId,
                  categoryId: e.categoryId,
                  amount: e.amount,
                  description: e.description,
                  date: current,
                  sharedWithUserId: e.sharedWithUserId,
                  isPaid: e.isPaid,
                  isRecurring: e.isRecurring,
                  currentInstallment: e.currentInstallment,
                  totalInstallments: e.totalInstallments,
                ));
                current = DateTime(current.year, current.month + 1, e.date.day);
              }
              return virtualExpenses;
            })
            .toList());

    return Rx.combineLatest2(currentStream, pastRecurringStream, 
      (List<ExpenseModel> current, List<ExpenseModel> pastRecurring) {
        final all = [...current, ...pastRecurring];
        return all;
      });
  }

  Future<void> addExpense(ExpenseModel expense, {int installments = 1}) async {
    final batch = _firestore.batch();
    final groupId = installments > 1 ? _firestore.collection('expenses').doc().id : null;

    for (int i = 0; i < installments; i++) {
      final newDate = DateTime(
        expense.date.year,
        expense.date.month + i,
        expense.date.day,
      );
      
      final installmentDesc = expense.description != null && expense.description!.isNotEmpty && installments > 1
          ? '${expense.description} (${i + 1}/$installments)'
          : expense.description;

      final e = ExpenseModel(
        id: '', 
        userId: expense.userId,
        categoryId: expense.categoryId,
        amount: expense.amount / installments,
        description: installmentDesc,
        date: newDate,
        sharedWithUserId: expense.sharedWithUserId,
        isPaid: i == 0 ? expense.isPaid : false,
        isRecurring: expense.isRecurring,
        isIncome: expense.isIncome,
        groupId: groupId,
        currentInstallment: i + 1,
        totalInstallments: installments,
      );
      
      final docRef = _firestore.collection('expenses').doc();
      batch.set(docRef, e.toJson());
    }

    await batch.commit();
  }

  Future<void> updateExpense(ExpenseModel expense) async {
    if (expense.id.contains('_')) {
      final originalId = expense.id.split('_').first;
      await _firestore.collection('expenses').doc(originalId).update({
        'amount': expense.amount,
        'category_id': expense.categoryId,
        'description': expense.description,
        'is_recurring': expense.isRecurring,
        'shared_with_user_id': expense.sharedWithUserId,
        'is_income': expense.isIncome,
      });
      return;
    }
    
    if (expense.groupId != null && expense.totalInstallments > 1) {
      final snapshot = await _firestore.collection('expenses').where('group_id', isEqualTo: expense.groupId).get();
      final batch = _firestore.batch();
      
      for (var doc in snapshot.docs) {
        final existing = ExpenseModel.fromJson(doc.data(), doc.id);
        
        String desc = expense.description ?? '';
        if (desc.isNotEmpty) {
           desc = '${desc.replaceAll(RegExp(r'\s*\(\d+/\d+\)$'), '')} (${existing.currentInstallment}/${existing.totalInstallments})';
        }

        final int monthOffset = existing.currentInstallment - expense.currentInstallment;
        final DateTime updatedDate = DateTime(
          expense.date.year,
          expense.date.month + monthOffset,
          expense.date.day,
        );

        final updated = ExpenseModel(
          id: existing.id,
          userId: expense.userId,
          amount: expense.amount / expense.totalInstallments,
          categoryId: expense.categoryId,
          groupId: existing.groupId,
          date: updatedDate,
          description: desc,
          sharedWithUserId: expense.sharedWithUserId,
          isPaid: existing.id == expense.id ? expense.isPaid : existing.isPaid,
          isRecurring: expense.isRecurring,
          isIncome: expense.isIncome,
          currentInstallment: existing.currentInstallment,
          totalInstallments: existing.totalInstallments,
        );
        batch.update(doc.reference, updated.toJson());
      }
      await batch.commit();
    } else if (expense.groupId == null && expense.totalInstallments > 1) {
      // Retroactive grouping for old debts
      final doc = await _firestore.collection('expenses').doc(expense.id).get();
      if (doc.exists) {
        final existingData = doc.data()!;
        final oldDesc = existingData['description'] as String? ?? '';
        final baseOldDesc = oldDesc.replaceAll(RegExp(r'\s*\(\d+/\d+\)$'), '').trim();
        
        final snapshot = await _firestore.collection('expenses')
            .where('user_id', isEqualTo: expense.userId)
            .where('total_installments', isEqualTo: expense.totalInstallments)
            .get();
            
        final matchingDocs = snapshot.docs.where((d) {
           final dDesc = d.data()['description'] as String? ?? '';
           final dBaseDesc = dDesc.replaceAll(RegExp(r'\s*\(\d+/\d+\)$'), '').trim();
           return dBaseDesc == baseOldDesc;
        }).toList();
        
        if (matchingDocs.length > 1) {
           final newGroupId = _firestore.collection('expenses').doc().id;
           final batch = _firestore.batch();
           for (var d in matchingDocs) {
              final existingInst = ExpenseModel.fromJson(d.data(), d.id);
              
              String desc = expense.description ?? '';
              if (desc.isNotEmpty) {
                 desc = '${desc.replaceAll(RegExp(r'\s*\(\d+/\d+\)$'), '')} (${existingInst.currentInstallment}/${existingInst.totalInstallments})';
              }
              
              final int monthOffset = existingInst.currentInstallment - expense.currentInstallment;
              final DateTime updatedDate = DateTime(
                expense.date.year,
                expense.date.month + monthOffset,
                expense.date.day,
              );
              
              final updated = ExpenseModel(
                id: existingInst.id,
                userId: expense.userId,
                amount: expense.amount / expense.totalInstallments,
                categoryId: expense.categoryId,
                groupId: newGroupId,
                date: updatedDate,
                description: desc,
                sharedWithUserId: expense.sharedWithUserId,
                isPaid: existingInst.id == expense.id ? expense.isPaid : existingInst.isPaid,
                isRecurring: expense.isRecurring,
                isIncome: expense.isIncome,
                currentInstallment: existingInst.currentInstallment,
                totalInstallments: existingInst.totalInstallments,
              );
              batch.update(d.reference, updated.toJson());
           }
           await batch.commit();
           return;
        }
      }
      
      // Fallback Se não encontrou outras ou deu erro
      final singleExpense = ExpenseModel(
        id: expense.id,
        userId: expense.userId,
        amount: expense.amount / expense.totalInstallments,
        categoryId: expense.categoryId,
        groupId: expense.groupId,
        date: expense.date,
        description: expense.description,
        sharedWithUserId: expense.sharedWithUserId,
        isPaid: expense.isPaid,
        isRecurring: expense.isRecurring,
        isIncome: expense.isIncome,
        currentInstallment: expense.currentInstallment,
        totalInstallments: expense.totalInstallments,
      );
      await _firestore.collection('expenses').doc(expense.id).update(singleExpense.toJson());
    } else {
      final singleExpense = ExpenseModel(
        id: expense.id,
        userId: expense.userId,
        amount: expense.amount / expense.totalInstallments,
        categoryId: expense.categoryId,
        groupId: expense.groupId,
        date: expense.date,
        description: expense.description,
        sharedWithUserId: expense.sharedWithUserId,
        isPaid: expense.isPaid,
        isRecurring: expense.isRecurring,
        isIncome: expense.isIncome,
        currentInstallment: expense.currentInstallment,
        totalInstallments: expense.totalInstallments,
      );
      await _firestore.collection('expenses').doc(expense.id).update(singleExpense.toJson());
    }
  }

  Future<void> deleteExpense(String expenseId) async {
    if (expenseId.contains('_')) {
      final originalId = expenseId.split('_').first;
      await _firestore.collection('expenses').doc(originalId).delete();
      return;
    }
    
    final doc = await _firestore.collection('expenses').doc(expenseId).get();
    if (doc.exists) {
      final data = doc.data();
      final groupId = data?['group_id'];
      if (groupId != null) {
        final snapshot = await _firestore.collection('expenses').where('group_id', isEqualTo: groupId).get();
        final batch = _firestore.batch();
        for (var s in snapshot.docs) {
          batch.delete(s.reference);
        }
        await batch.commit();
        return;
      } else if ((data?['total_installments'] as num?) != null && (data!['total_installments'] as num) > 1) {
        // Retroactive delete for old orphaned installments
        final totalInstallments = (data['total_installments'] as num).toInt();
        final userId = data['user_id'];
        final oldDesc = data['description'] as String? ?? '';
        final baseOldDesc = oldDesc.replaceAll(RegExp(r'\s*\(\d+/\d+\)$'), '').trim();

        final snapshot = await _firestore.collection('expenses')
            .where('user_id', isEqualTo: userId)
            .where('total_installments', isEqualTo: totalInstallments)
            .get();
            
        final matchingDocs = snapshot.docs.where((d) {
           final dDesc = d.data()['description'] as String? ?? '';
           final dBaseDesc = dDesc.replaceAll(RegExp(r'\s*\(\d+/\d+\)$'), '').trim();
           return dBaseDesc == baseOldDesc;
        }).toList();
        
        if (matchingDocs.length > 1) {
           final batch = _firestore.batch();
           for (var s in matchingDocs) {
             batch.delete(s.reference);
           }
           await batch.commit();
           return;
        }
      }
    }
    
    await _firestore.collection('expenses').doc(expenseId).delete();
  }

  // --- EMPRÉSTIMOS ---

  Stream<List<LoanModel>> getLoans({DateTime? baseDate}) {
    final userId = _auth.currentUser?.uid;
    if (userId == null) return Stream.value([]);

    final targetDate = baseDate ?? DateTime.now();

    return _firestore
        .collection('loans')
        .where('user_id', isEqualTo: userId)
        .orderBy('date', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => LoanModel.fromJson(doc.data(), doc.id))
            .expand((loan) {
              if (!loan.isRecurring) return [loan];
              
              final List<LoanModel> virtualLoans = [];
              DateTime current = DateTime(loan.date.year, loan.date.month, loan.date.day);
              final limit = DateTime(targetDate.year, targetDate.month, loan.date.day);

              while (current.isBefore(limit) || current.isAtSameMomentAs(limit)) {
                virtualLoans.add(LoanModel(
                  id: current == loan.date ? loan.id : '${loan.id}_${current.year}_${current.month}',
                  userId: loan.userId,
                  borrowerName: loan.borrowerName,
                  amount: loan.amount,
                  categoryId: loan.categoryId,
                  date: current,
                  isPaid: current == loan.date ? loan.isPaid : false,
                  isRecurring: true,
                  currentInstallment: 1,
                  totalInstallments: 1,
                ));
                current = DateTime(current.year, current.month + 1, loan.date.day);
              }
              return virtualLoans;
            })
            .toList());
  }

  Future<void> addLoan(LoanModel loan, {int installments = 1}) async {
    final batch = _firestore.batch();
    final groupId = installments > 1 ? _firestore.collection('loans').doc().id : null;
    
    for (int i = 0; i < installments; i++) {
      final docRef = _firestore.collection('loans').doc();
      final instDate = DateTime(loan.date.year, loan.date.month + i, loan.date.day);
      
      final instLoan = LoanModel(
        id: docRef.id,
        userId: loan.userId,
        borrowerName: loan.borrowerName,
        amount: loan.amount / installments,
        categoryId: loan.categoryId,
        groupId: groupId,
        date: instDate,
        isPaid: loan.isPaid,
        isRecurring: loan.isRecurring,
        currentInstallment: i + 1,
        totalInstallments: installments,
      );
      
      batch.set(docRef, instLoan.toJson());
    }
    
    await batch.commit();
  }

  Future<void> updateLoan(LoanModel loan) async {
    if (loan.id.contains('_')) {
      // It's a virtual recurring loan, we should update the original loan
      final originalId = loan.id.split('_').first;
      await _firestore.collection('loans').doc(originalId).update({
        'borrower_name': loan.borrowerName,
        'amount': loan.amount,
        'category_id': loan.categoryId,
        'is_recurring': loan.isRecurring,
      });
      return;
    }

    if (loan.groupId != null && loan.totalInstallments > 1) {
      final snapshot = await _firestore.collection('loans').where('group_id', isEqualTo: loan.groupId).get();
      final batch = _firestore.batch();
      
      for (var doc in snapshot.docs) {
        final existingLoan = LoanModel.fromJson(doc.data(), doc.id);
        final instLoan = LoanModel(
          id: existingLoan.id,
          userId: loan.userId,
          borrowerName: loan.borrowerName,
          amount: loan.amount / loan.totalInstallments,
          categoryId: loan.categoryId,
          groupId: existingLoan.groupId,
          date: existingLoan.date,
          isPaid: existingLoan.id == loan.id ? loan.isPaid : existingLoan.isPaid,
          isRecurring: loan.isRecurring,
          currentInstallment: existingLoan.currentInstallment,
          totalInstallments: existingLoan.totalInstallments,
        );
        batch.update(doc.reference, instLoan.toJson());
      }
      await batch.commit();
    } else {
      await _firestore.collection('loans').doc(loan.id).update(loan.toJson());
    }
  }

  Future<void> deleteLoan(String loanId) async {
    await _firestore.collection('loans').doc(loanId).delete();
  }
}
