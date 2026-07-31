import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:rxdart/rxdart.dart';
import '../models/category_model.dart';
import '../models/expense_model.dart';
import '../models/loan_model.dart';
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

  final stream = repo.getExpensesForCurrentMonth(payDay: payDay, baseDate: baseDate);
  
  await for (final expenses in stream) {
    yield expenses.map((e) {
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
  }
});

final loansProvider = StreamProvider<List<LoanModel>>((ref) {
  final repo = ref.watch(financesRepositoryProvider);
  return repo.getLoans();
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

  Stream<List<ExpenseModel>> getExpensesForCurrentMonth({int payDay = 1, DateTime? baseDate}) {
    final userId = _auth.currentUser?.uid;
    if (userId == null) return Stream.value([]);

    final now = baseDate ?? DateTime.now();
    DateTime start, end;

    int daysInMonth(int year, int month) => DateTime(year, month + 1, 0).day;
    int safeDay(int year, int month, int day) {
      final max = daysInMonth(year, month);
      return day > max ? max : day;
    }

    if (now.day >= payDay) {
      start = DateTime(now.year, now.month, safeDay(now.year, now.month, payDay));
      final endMonth = now.month + 1;
      final endYear = endMonth > 12 ? now.year + 1 : now.year;
      final eMonth = endMonth > 12 ? 1 : endMonth;
      final nextPayDay = safeDay(endYear, eMonth, payDay);
      end = DateTime(endYear, eMonth, nextPayDay).subtract(const Duration(days: 1));
    } else {
      final startMonth = now.month - 1;
      final startYear = startMonth < 1 ? now.year - 1 : now.year;
      final sMonth = startMonth < 1 ? 12 : startMonth;
      start = DateTime(startYear, sMonth, safeDay(startYear, sMonth, payDay));
      
      final nextPayDay = safeDay(now.year, now.month, payDay);
      end = DateTime(now.year, now.month, nextPayDay).subtract(const Duration(days: 1));
    }

    final startStr = start.toIso8601String().split('T').first;
    final endStr = end.toIso8601String().split('T').first;

    // Despesas do mês atual
    final currentMonthStream = _firestore
        .collection('expenses')
        .where(Filter.or(
          Filter('user_id', isEqualTo: userId),
          Filter('shared_with_user_id', isEqualTo: userId),
        ))
        .where('date', isGreaterThanOrEqualTo: startStr)
        .where('date', isLessThanOrEqualTo: endStr)
        .orderBy('date', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => ExpenseModel.fromJson(doc.data(), doc.id))
            .toList());

    // Despesas recorrentes passadas (que refletem no mês atual)
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
            .map((e) {
                  DateTime projectedDate;
                  if (e.date.day >= payDay) {
                     projectedDate = DateTime(start.year, start.month, safeDay(start.year, start.month, e.date.day));
                  } else {
                     projectedDate = DateTime(end.year, end.month, safeDay(end.year, end.month, e.date.day));
                  }
                  
                  return ExpenseModel(
                    id: e.id,
                    userId: e.userId,
                    categoryId: e.categoryId,
                    amount: e.amount,
                    description: e.description,
                    date: projectedDate,
                    sharedWithUserId: e.sharedWithUserId,
                    isPaid: e.isPaid,
                    isRecurring: e.isRecurring,
                    currentInstallment: e.currentInstallment,
                    totalInstallments: e.totalInstallments,
                  );
                })
            .toList());

    return Rx.combineLatest2(currentMonthStream, pastRecurringStream, 
      (List<ExpenseModel> current, List<ExpenseModel> pastRecurring) {
        final all = [...current, ...pastRecurring];
        // Evita duplicatas se uma despesa recorrente foi criada neste mês (já estará em currentMonth)
        final uniqueMap = <String, ExpenseModel>{};
        for (var e in all) {
          uniqueMap[e.id] = e;
        }
        final result = uniqueMap.values.toList();
        result.sort((a, b) => b.date.compareTo(a.date));
        return result;
      });
  }

  Future<void> addExpense(ExpenseModel expense, {int installments = 1}) async {
    if (installments <= 1) {
      await _firestore.collection('expenses').add(expense.toJson());
      return;
    }

    final amountPerInstallment = expense.amount / installments;
    final batch = _firestore.batch();

    for (int i = 1; i <= installments; i++) {
      final newDate = DateTime(
        expense.date.year,
        expense.date.month + (i - 1),
        expense.date.day,
      );
      
      final installmentDesc = expense.description != null && expense.description!.isNotEmpty 
          ? '${expense.description} ($i/$installments)'
          : 'Parcela $i/$installments';

      final e = ExpenseModel(
        id: '', 
        userId: expense.userId,
        categoryId: expense.categoryId,
        amount: amountPerInstallment,
        description: installmentDesc,
        date: newDate,
        sharedWithUserId: expense.sharedWithUserId,
        isPaid: i == 1 ? expense.isPaid : false,
        isRecurring: expense.isRecurring,
        currentInstallment: i,
        totalInstallments: installments,
      );
      
      final docRef = _firestore.collection('expenses').doc();
      batch.set(docRef, e.toJson());
    }

    await batch.commit();
  }

  Future<void> updateExpense(ExpenseModel expense) async {
    await _firestore.collection('expenses').doc(expense.id).update(expense.toJson());
  }

  Future<void> deleteExpense(String expenseId) async {
    await _firestore.collection('expenses').doc(expenseId).delete();
  }

  // --- EMPRÉSTIMOS ---

  Stream<List<LoanModel>> getLoans() {
    final userId = _auth.currentUser?.uid;
    if (userId == null) return Stream.value([]);

    return _firestore
        .collection('loans')
        .where('user_id', isEqualTo: userId)
        .orderBy('date', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => LoanModel.fromJson(doc.data(), doc.id))
            .toList());
  }

  Future<void> addLoan(LoanModel loan, {int installments = 1}) async {
    if (installments <= 1) {
      await _firestore.collection('loans').add(loan.toJson());
      return;
    }

    final amountPerInstallment = loan.amount / installments;
    final batch = _firestore.batch();

    for (int i = 1; i <= installments; i++) {
      final newDate = DateTime(
        loan.date.year,
        loan.date.month + (i - 1),
        loan.date.day,
      );
      
      final l = LoanModel(
        id: '',
        userId: loan.userId,
        borrowerName: loan.borrowerName,
        categoryId: loan.categoryId,
        amount: amountPerInstallment,
        date: newDate,
        isPaid: i == 1 ? loan.isPaid : false,
        currentInstallment: i,
        totalInstallments: installments,
      );
      
      final docRef = _firestore.collection('loans').doc();
      batch.set(docRef, l.toJson());
    }

    await batch.commit();
  }

  Future<void> updateLoan(LoanModel loan) async {
    await _firestore.collection('loans').doc(loan.id).update(loan.toJson());
  }

  Future<void> deleteLoan(String loanId) async {
    await _firestore.collection('loans').doc(loanId).delete();
  }
}
