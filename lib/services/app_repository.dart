import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' as auth;
import 'package:flutter/foundation.dart';

import '../models/app_models.dart';

abstract class AppRepository {
  Stream<AppUser?> watchUser();
  Stream<List<Equipment>> watchEquipment();
  Stream<List<Booking>> watchBookings();
  AppUser? get currentUser;
  Future<void> signIn(String email, String password);
  Future<void> signUp({
    required String email,
    required String password,
    required String name,
    required String schoolId,
    required UserRole role,
  });
  Future<void> signOut();
  Future<void> addEquipment({
    required String name,
    required String code,
    required String category,
    required String note,
    String imageUrl = '',
  });
  Future<void> updateEquipment({
    required Equipment equipment,
    required String name,
    required String code,
    required String category,
    required String note,
    required String imageUrl,
  });
  Future<void> setEquipmentAvailability(
    Equipment equipment, {
    required bool available,
  });
  Future<void> createBooking({
    required Equipment equipment,
    required DateTime startAt,
    required DateTime endAt,
    required String purpose,
  });
  Future<void> updateBookingStatus(Booking booking, BookingStatus status);
}

String? validateSchoolEmail(String? value) {
  final email = value?.trim().toLowerCase() ?? '';
  if (email.isEmpty) return 'กรุณากรอกอีเมลโรงเรียน';
  final pattern = RegExp(r'^[a-z0-9._%+-]+@hatyaiwit\.ac\.th$');
  if (!pattern.hasMatch(email)) return 'ใช้ได้เฉพาะอีเมล @hatyaiwit.ac.th';
  return null;
}

class FirebaseAppRepository implements AppRepository {
  FirebaseAppRepository()
    : _auth = auth.FirebaseAuth.instance,
      _db = FirebaseFirestore.instance {
    _authSubscription = _auth.authStateChanges().listen(_loadUser);
  }

  final auth.FirebaseAuth _auth;
  final FirebaseFirestore _db;
  final _userController = StreamController<AppUser?>.broadcast();
  StreamSubscription<auth.User?>? _authSubscription;
  AppUser? _currentUser;

  @override
  AppUser? get currentUser => _currentUser;

  Future<void> _loadUser(auth.User? firebaseUser) async {
    if (firebaseUser == null) {
      _currentUser = null;
      _userController.add(null);
      return;
    }
    final snapshot = await _db.collection('users').doc(firebaseUser.uid).get();
    if (snapshot.exists) {
      _currentUser = AppUser.fromMap(snapshot.id, snapshot.data()!);
    } else {
      _currentUser = AppUser(
        id: firebaseUser.uid,
        email: firebaseUser.email ?? '',
        name: firebaseUser.displayName ?? 'ผู้ใช้งาน',
        schoolId: (firebaseUser.email ?? '').split('@').first,
        role: UserRole.student,
      );
      await _db
          .collection('users')
          .doc(firebaseUser.uid)
          .set(_currentUser!.toMap());
    }
    _userController.add(_currentUser);
  }

  @override
  Stream<AppUser?> watchUser() async* {
    yield _currentUser;
    yield* _userController.stream;
  }

  @override
  Future<void> signIn(String email, String password) async {
    final error = validateSchoolEmail(email);
    if (error != null) throw Exception(error);
    await _auth.signInWithEmailAndPassword(
      email: email.trim().toLowerCase(),
      password: password,
    );
  }

  @override
  Future<void> signUp({
    required String email,
    required String password,
    required String name,
    required String schoolId,
    required UserRole role,
  }) async {
    final error = validateSchoolEmail(email);
    if (error != null) throw Exception(error);
    final normalizedEmail = email.trim().toLowerCase();
    final credential = await _auth.createUserWithEmailAndPassword(
      email: normalizedEmail,
      password: password,
    );
    final user = AppUser(
      id: credential.user!.uid,
      email: normalizedEmail,
      name: name.trim(),
      schoolId: schoolId.trim(),
      role: role,
    );
    await credential.user!.updateDisplayName(user.name);
    await _db.collection('users').doc(user.id).set(user.toMap());
    _currentUser = user;
    _userController.add(user);
  }

  @override
  Future<void> signOut() => _auth.signOut();

  @override
  Stream<List<Equipment>> watchEquipment() => _db
      .collection('equipment')
      .orderBy('name')
      .snapshots()
      .map(
        (snapshot) => snapshot.docs
            .map((doc) => Equipment.fromMap(doc.id, doc.data()))
            .toList(),
      );

  @override
  Stream<List<Booking>> watchBookings() {
    final user = _currentUser;
    if (user == null) return Stream.value(const []);

    // Firestore rules are not filters. Query only documents the signed-in user
    // is allowed to read, then merge borrower and owner results locally.
    return Stream.multi((controller) {
      var borrowed = <Booking>[];
      var owned = <Booking>[];

      void publish() {
        final merged = [...borrowed, ...owned]
          ..sort((a, b) => b.startAt.compareTo(a.startAt));
        controller.add(merged);
      }

      final borrowerSubscription = _db
          .collection('bookings')
          .where('borrowerId', isEqualTo: user.id)
          .snapshots()
          .listen((snapshot) {
            borrowed = snapshot.docs
                .map((doc) => Booking.fromMap(doc.id, doc.data()))
                .toList();
            publish();
          }, onError: controller.addError);

      final ownerSubscription = _db
          .collection('bookings')
          .where('ownerId', isEqualTo: user.id)
          .snapshots()
          .listen((snapshot) {
            owned = snapshot.docs
                .map((doc) => Booking.fromMap(doc.id, doc.data()))
                .toList();
            publish();
          }, onError: controller.addError);

      controller.onCancel = () async {
        await borrowerSubscription.cancel();
        await ownerSubscription.cancel();
      };
    });
  }

  @override
  Future<void> addEquipment({
    required String name,
    required String code,
    required String category,
    required String note,
    String imageUrl = '',
  }) async {
    final user = _requireUser();
    if (name.trim().isEmpty) throw Exception('กรุณากรอกชื่ออุปกรณ์');
    if (code.trim().isEmpty) throw Exception('กรุณากรอกรหัสอุปกรณ์');
    final reference = _db.collection('equipment').doc();
    await reference.set(
      Equipment(
        id: reference.id,
        code: code.trim().toUpperCase(),
        name: name.trim(),
        category: category,
        ownerId: user.id,
        ownerName: user.name,
        available: true,
        note: note.trim(),
        imageUrl: imageUrl.trim(),
      ).toMap(),
    );
  }

  @override
  Future<void> updateEquipment({
    required Equipment equipment,
    required String name,
    required String code,
    required String category,
    required String note,
    required String imageUrl,
  }) async {
    final user = _requireUser();
    if (equipment.ownerId != user.id) {
      throw Exception('เฉพาะเจ้าของอุปกรณ์เท่านั้น');
    }
    if (name.trim().isEmpty) throw Exception('กรุณากรอกชื่ออุปกรณ์');
    if (code.trim().isEmpty) throw Exception('กรุณากรอกรหัสอุปกรณ์');

    await _db.collection('equipment').doc(equipment.id).update({
      'name': name.trim(),
      'code': code.trim().toUpperCase(),
      'category': category,
      'note': note.trim(),
      'imageUrl': imageUrl.trim(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  @override
  Future<void> setEquipmentAvailability(
    Equipment equipment, {
    required bool available,
  }) async {
    final user = _requireUser();
    if (equipment.ownerId != user.id) {
      throw Exception('เฉพาะเจ้าของอุปกรณ์เท่านั้น');
    }

    if (available) {
      final bookings = await _db
          .collection('bookings')
          .where('ownerId', isEqualTo: user.id)
          .get();
      for (final document in bookings.docs) {
        final booking = Booking.fromMap(document.id, document.data());
        if (booking.equipmentId == equipment.id &&
            booking.status == BookingStatus.approved) {
          await updateBookingStatus(booking, BookingStatus.returned);
          return;
        }
      }
    }

    await _db.collection('equipment').doc(equipment.id).update({
      'available': available,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  @override
  Future<void> createBooking({
    required Equipment equipment,
    required DateTime startAt,
    required DateTime endAt,
    required String purpose,
  }) async {
    final user = _requireUser();
    if (equipment.ownerId == user.id) {
      throw Exception('ไม่สามารถยืมอุปกรณ์ของตัวเองได้');
    }
    if (!equipment.available) {
      throw Exception('อุปกรณ์นี้ยังไม่พร้อมให้ยืม');
    }
    if (!endAt.isAfter(startAt)) {
      throw Exception('เวลาคืนต้องอยู่หลังเวลารับของ');
    }
    final reference = _db.collection('bookings').doc();
    await reference.set(
      Booking(
        id: reference.id,
        equipmentId: equipment.id,
        equipmentName: equipment.name,
        equipmentCode: equipment.code,
        ownerId: equipment.ownerId,
        ownerName: equipment.ownerName,
        borrowerId: user.id,
        borrowerName: user.name,
        borrowerSchoolId: user.schoolId,
        startAt: startAt,
        endAt: endAt,
        status: BookingStatus.pending,
        purpose: purpose.trim(),
      ).toMap(),
    );
  }

  @override
  Future<void> updateBookingStatus(
    Booking booking,
    BookingStatus status,
  ) async {
    final user = _requireUser();
    if (booking.ownerId != user.id) {
      throw Exception('เฉพาะเจ้าของอุปกรณ์เท่านั้น');
    }
    final bookingReference = _db.collection('bookings').doc(booking.id);
    final equipmentReference = _db
        .collection('equipment')
        .doc(booking.equipmentId);

    await _db.runTransaction((transaction) async {
      final bookingSnapshot = await transaction.get(bookingReference);
      if (!bookingSnapshot.exists) throw Exception('ไม่พบรายการยืมนี้');

      final currentName = bookingSnapshot.data()?['status'] as String?;
      final current = BookingStatus.values.firstWhere(
        (value) => value.name == currentName,
        orElse: () => BookingStatus.pending,
      );
      if (!canTransitionBookingStatus(current, status)) {
        throw Exception('ไม่สามารถเปลี่ยนสถานะรายการนี้ได้');
      }

      if (status == BookingStatus.approved) {
        final equipmentSnapshot = await transaction.get(equipmentReference);
        if (!equipmentSnapshot.exists) throw Exception('ไม่พบอุปกรณ์นี้');
        if (equipmentSnapshot.data()?['available'] != true) {
          throw Exception('อุปกรณ์นี้ถูกยืมไปแล้ว');
        }
      }

      transaction.update(bookingReference, {
        'status': status.name,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      if (status == BookingStatus.approved ||
          status == BookingStatus.returned) {
        transaction.update(equipmentReference, {
          'available': status == BookingStatus.returned,
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }
    });
  }

  AppUser _requireUser() {
    final user = _currentUser;
    if (user == null) throw Exception('กรุณาเข้าสู่ระบบ');
    return user;
  }

  @visibleForTesting
  void dispose() {
    _authSubscription?.cancel();
    _userController.close();
  }
}
