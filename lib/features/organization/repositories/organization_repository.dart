import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/shopping_item_model.dart';
import '../models/todo_item_model.dart';
import '../models/appointment_model.dart';
import '../../auth/repositories/auth_repository.dart';
import '../../../core/services/notification_service.dart';

final organizationRepositoryProvider = Provider<OrganizationRepository>((ref) {
  return OrganizationRepository(FirebaseFirestore.instance, FirebaseAuth.instance);
});

final shoppingListProvider = StreamProvider<List<ShoppingItemModel>>((ref) async* {
  final repo = ref.watch(organizationRepositoryProvider);
  final user = await ref.watch(currentUserProvider.future);
  if (user == null) {
    yield [];
    return;
  }
  await for (final items in repo.getShoppingList(user.id, user.partnerUid)) {
    yield items;
  }
});

final todosProvider = StreamProvider<List<TodoItemModel>>((ref) async* {
  final repo = ref.watch(organizationRepositoryProvider);
  final user = await ref.watch(currentUserProvider.future);
  if (user == null) {
    yield [];
    return;
  }
  await for (final items in repo.getTodos(user.id, user.partnerUid)) {
    yield items;
  }
});

final appointmentsProvider = StreamProvider<List<AppointmentModel>>((ref) async* {
  final repo = ref.watch(organizationRepositoryProvider);
  final user = await ref.watch(currentUserProvider.future);
  if (user == null) {
    yield [];
    return;
  }
  await for (final items in repo.getAppointments(user.id, user.partnerUid)) {
    yield items;
  }
});

class OrganizationRepository {
  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;
  final NotificationService _notificationService = NotificationService();

  OrganizationRepository(this._firestore, this._auth);

  // --- SHOPPING LIST ---
  Stream<List<ShoppingItemModel>> getShoppingList(String userId, String? partnerUid) {
    final ids = [userId];
    if (partnerUid != null && partnerUid.isNotEmpty) {
      ids.add(partnerUid);
    }
    return _firestore
        .collection('shopping_list')
        .where('created_by', whereIn: ids)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => ShoppingItemModel.fromJson(doc.data(), doc.id))
            .toList());
  }

  Future<void> addShoppingItem(String name) async {
    final userId = _auth.currentUser?.uid;
    if (userId == null) return;
    final item = ShoppingItemModel(id: '', name: name, createdBy: userId);
    await _firestore.collection('shopping_list').add(item.toJson());
  }

  Future<void> toggleShoppingItem(ShoppingItemModel item) async {
    await _firestore.collection('shopping_list').doc(item.id).update({'is_bought': !item.isBought});
  }

  Future<void> deleteShoppingItem(String id) async {
    await _firestore.collection('shopping_list').doc(id).delete();
  }

  // --- TODOS ---
  Stream<List<TodoItemModel>> getTodos(String userId, String? partnerUid) {
    final ids = [userId];
    if (partnerUid != null && partnerUid.isNotEmpty) {
      ids.add(partnerUid);
    }
    return _firestore
        .collection('todos')
        .where('created_by', whereIn: ids)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => TodoItemModel.fromJson(doc.data(), doc.id))
            .toList());
  }

  Future<void> addTodo(String title, String assignedTo) async {
    final userId = _auth.currentUser?.uid;
    if (userId == null) return;
    final item = TodoItemModel(id: '', title: title, createdBy: userId, assignedTo: assignedTo);
    await _firestore.collection('todos').add(item.toJson());
  }

  Future<void> toggleTodo(TodoItemModel item) async {
    await _firestore.collection('todos').doc(item.id).update({'is_completed': !item.isCompleted});
  }

  Future<void> deleteTodo(String id) async {
    await _firestore.collection('todos').doc(id).delete();
  }

  // --- APPOINTMENTS ---
  Stream<List<AppointmentModel>> getAppointments(String userId, String? partnerUid) {
    final ids = [userId];
    if (partnerUid != null && partnerUid.isNotEmpty) {
      ids.add(partnerUid);
    }
    return _firestore
        .collection('appointments')
        .where('created_by', whereIn: ids)
        .orderBy('date')
        .snapshots()
        .map((snapshot) {
          final appointments = snapshot.docs
              .map((doc) => AppointmentModel.fromJson(doc.data(), doc.id))
              .toList();
          
          // Schedule notifications automatically
          for (var appt in appointments) {
            if (appt.date.isAfter(DateTime.now())) {
              _notificationService.scheduleAppointmentNotification(
                id: appt.id.hashCode,
                title: 'Lembrete de Compromisso Hoje',
                body: appt.title,
                appointmentDate: appt.date,
              );
            }
          }
          return appointments;
        });
  }

  Future<void> addAppointment(String title, DateTime date, {double? expectedCost}) async {
    final userId = _auth.currentUser?.uid;
    if (userId == null) return;
    final item = AppointmentModel(
      id: '', 
      title: title, 
      date: date, 
      createdBy: userId,
      expectedCost: expectedCost,
    );
    await _firestore.collection('appointments').add(item.toJson());
  }

  Future<void> updateAppointment(AppointmentModel appointment) async {
    await _firestore.collection('appointments').doc(appointment.id).update(appointment.toJson());
    
    // Reschedule notification
    await _notificationService.cancelNotification(appointment.id.hashCode);
    if (appointment.date.isAfter(DateTime.now())) {
      await _notificationService.scheduleAppointmentNotification(
        id: appointment.id.hashCode,
        title: 'Lembrete de Compromisso Hoje',
        body: appointment.title,
        appointmentDate: appointment.date,
      );
    }
  }

  Future<void> deleteAppointment(String id) async {
    await _firestore.collection('appointments').doc(id).delete();
    await _notificationService.cancelNotification(id.hashCode);
  }
}
