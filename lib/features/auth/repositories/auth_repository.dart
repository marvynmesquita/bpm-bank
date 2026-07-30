import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_sign_in/google_sign_in.dart';
import '../models/user_model.dart';

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepository(FirebaseAuth.instance, FirebaseFirestore.instance);
});

final authStateProvider = StreamProvider<User?>((ref) {
  return FirebaseAuth.instance.authStateChanges();
});

final currentUserProvider = FutureProvider<UserModel?>((ref) async {
  final user = FirebaseAuth.instance.currentUser;
  if (user == null) return null;
  
  final doc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
      
  if (!doc.exists || doc.data() == null) {
    // Auto-cria o documento se estiver faltando (ex: logou com conta antiga)
    final userModel = UserModel(
      id: user.uid,
      email: user.email ?? '',
      name: user.displayName ?? 'Usuário',
    );
    await FirebaseFirestore.instance.collection('users').doc(user.uid).set(userModel.toJson());
    return userModel;
  }
  
  return UserModel.fromJson(doc.data()!, doc.id);
});

class AuthRepository {
  final FirebaseAuth _auth;
  final FirebaseFirestore _firestore;

  AuthRepository(this._auth, this._firestore);

  Future<void> signIn(String email, String password) async {
    await _auth.signInWithEmailAndPassword(email: email, password: password);
  }

  Future<void> signUp(String email, String password, String name) async {
    final cred = await _auth.createUserWithEmailAndPassword(email: email, password: password);
    final user = cred.user;
    if (user != null) {
      final userModel = UserModel(
        id: user.uid,
        email: email,
        name: name,
      );
      await _firestore.collection('users').doc(user.uid).set(userModel.toJson());
    }
  }
  
  Future<void> signInWithGoogle() async {
    final GoogleSignInAccount? googleUser = await GoogleSignIn().signIn();
    if (googleUser == null) return; // O usuário cancelou o login

    final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
    final OAuthCredential credential = GoogleAuthProvider.credential(
      accessToken: googleAuth.accessToken,
      idToken: googleAuth.idToken,
    );

    final cred = await _auth.signInWithCredential(credential);
    final user = cred.user;
    
    // Cria o documento no Firestore se for um novo usuário
    if (user != null && cred.additionalUserInfo?.isNewUser == true) {
      final userModel = UserModel(
        id: user.uid,
        email: user.email ?? '',
        name: user.displayName ?? 'Usuário',
      );
      await _firestore.collection('users').doc(user.uid).set(userModel.toJson());
    }
  }

  Future<void> resetPassword(String email) async {
    await _auth.sendPasswordResetEmail(email: email);
  }

  Future<void> signOut() async {
    await _auth.signOut();
    await GoogleSignIn().signOut();
  }

  Future<void> updateIncome(double income) async {
    final userId = _auth.currentUser?.uid;
    if (userId == null) return;
    
    await _firestore.collection('users').doc(userId).update({'monthly_income': income});
  }

  Future<void> setPartnerEmail(String partnerEmail) async {
    final currentUser = _auth.currentUser;
    if (currentUser == null) throw Exception('Usuário não autenticado');
    
    if (currentUser.email == partnerEmail) {
      throw Exception('Você não pode vincular sua própria conta.');
    }

    // Busca o usuário parceiro pelo email
    final query = await _firestore
        .collection('users')
        .where('email', isEqualTo: partnerEmail)
        .limit(1)
        .get();

    if (query.docs.isEmpty) {
      throw Exception('Parceira(o) não encontada(o). Ela/ele precisa criar uma conta primeiro.');
    }

    final partnerDoc = query.docs.first;
    final partnerUid = partnerDoc.id;

    final batch = _firestore.batch();
    
    // Atualiza a conta atual
    final currentUserRef = _firestore.collection('users').doc(currentUser.uid);
    batch.update(currentUserRef, {
      'partner_email': partnerEmail,
      'partner_uid': partnerUid,
    });

    // Atualiza a conta do parceiro (vínculo mútuo)
    final partnerRef = _firestore.collection('users').doc(partnerUid);
    batch.update(partnerRef, {
      'partner_email': currentUser.email,
      'partner_uid': currentUser.uid,
    });

    await batch.commit();
  }
}
