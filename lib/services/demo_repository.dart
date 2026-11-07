import 'dart:async';

import '../models/app_models.dart';
import 'app_repository.dart';

class DemoAppRepository implements AppRepository {
  DemoAppRepository() {
    _equipment = const [
      Equipment(
        id: 'eq-basketball',
        code: 'SP-001',
        name: 'ลูกบาสเกตบอล',
        category: 'บาสเกตบอล',
        ownerId: 'demo-teacher-01',
        ownerName: 'ครูสมชาย ใจดี',
        available: true,
        note: 'ลูกบาส เบอร์ 7',
      ),
      Equipment(
        id: 'eq-football',
        code: 'SP-002',
        name: 'ลูกฟุตบอล',
        category: 'ฟุตบอล',
        ownerId: 'demo-teacher-01',
        ownerName: 'ครูสมชาย ใจดี',
        available: false,
        note: 'เหมาะสำหรับสนามหญ้า',
      ),
      Equipment(
        id: 'eq-racket',
        code: 'SP-003',
        name: 'ไม้แบดมินตัน',
        category: 'แบดมินตัน',
        ownerId: 'demo-student-02',
        ownerName: 'ธนภัทร ม.6/2',
        available: true,
        note: 'พร้อมลูกขนไก่ 2 ลูก',
      ),
      Equipment(
        id: 'eq-volleyball',
        code: 'SP-004',
        name: 'ลูกวอลเลย์บอล',
        category: 'วอลเลย์บอล',
        ownerId: 'demo-teacher-02',
        ownerName: 'ครูวราภรณ์',
        available: true,
      ),
      Equipment(
        id: 'eq-cone',
        code: 'SP-005',
        name: 'กรวยซ้อมกีฬา 10 ชิ้น',
        category: 'อุปกรณ์ฝึกซ้อม',
        ownerId: 'demo-teacher-02',
        ownerName: 'ครูวราภรณ์',
        available: true,
      ),
    ];
  }

  final _userController = StreamController<AppUser?>.broadcast();
  final _equipmentController = StreamController<List<Equipment>>.broadcast();
  final _bookingController = StreamController<List<Booking>>.broadcast();
  AppUser? _currentUser;
  late List<Equipment> _equipment;
  final List<Booking> _bookings = [];

  @override
  AppUser? get currentUser => _currentUser;

  @override
  Stream<AppUser?> watchUser() async* {
    yield _currentUser;
    yield* _userController.stream;
  }

  @override
  Future<void> signIn(String email, String password) async {
    final error = validateSchoolEmail(email);
    if (error != null) throw Exception(error);
    if (password.length < 6) {
      throw Exception('รหัสผ่านต้องมีอย่างน้อย 6 ตัวอักษร');
    }
    await Future<void>.delayed(const Duration(milliseconds: 450));
    final id = email.split('@').first;
    _currentUser = AppUser(
      id: 'demo-$id',
      email: email.trim().toLowerCase(),
      name: id == '52972' ? 'นักเรียนทดลอง' : 'ผู้ใช้งาน $id',
      schoolId: id,
      role: id.startsWith('teacher') ? UserRole.teacher : UserRole.student,
    );
    _userController.add(_currentUser);
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
    if (password.length < 6) {
      throw Exception('รหัสผ่านต้องมีอย่างน้อย 6 ตัวอักษร');
    }
    await Future<void>.delayed(const Duration(milliseconds: 450));
    _currentUser = AppUser(
      id: 'demo-$schoolId',
      email: email.trim().toLowerCase(),
      name: name.trim(),
      schoolId: schoolId.trim(),
      role: role,
    );
    _userController.add(_currentUser);
  }

  @override
  Future<void> signOut() async {
    _currentUser = null;
    _userController.add(null);
  }

  @override
  Stream<List<Equipment>> watchEquipment() async* {
    yield List.unmodifiable(_equipment);
    yield* _equipmentController.stream;
  }

  @override
  Stream<List<Booking>> watchBookings() async* {
    yield List.unmodifiable(_bookings);
    yield* _bookingController.stream;
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
    _equipment = [
      Equipment(
        id: 'demo-${DateTime.now().millisecondsSinceEpoch}',
        code: code.trim().toUpperCase(),
        name: name.trim(),
        category: category,
        ownerId: user.id,
        ownerName: user.name,
        available: true,
        note: note.trim(),
        imageUrl: imageUrl.trim(),
      ),
      ..._equipment,
    ];
    _equipmentController.add(List.unmodifiable(_equipment));
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

    _equipment = _equipment
        .map(
          (item) => item.id == equipment.id
              ? Equipment(
                  id: item.id,
                  code: code.trim().toUpperCase(),
                  name: name.trim(),
                  category: category,
                  ownerId: item.ownerId,
                  ownerName: item.ownerName,
                  available: item.available,
                  note: note.trim(),
                  imageUrl: imageUrl.trim(),
                )
              : item,
        )
        .toList();
    _equipmentController.add(List.unmodifiable(_equipment));
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
      for (final booking in _bookings) {
        if (booking.equipmentId == equipment.id &&
            booking.status == BookingStatus.approved) {
          await updateBookingStatus(booking, BookingStatus.returned);
          return;
        }
      }
    }

    _equipment = _equipment
        .map(
          (item) => item.id == equipment.id
              ? Equipment(
                  id: item.id,
                  code: item.code,
                  name: item.name,
                  category: item.category,
                  ownerId: item.ownerId,
                  ownerName: item.ownerName,
                  available: available,
                  note: item.note,
                  imageUrl: item.imageUrl,
                )
              : item,
        )
        .toList();
    _equipmentController.add(List.unmodifiable(_equipment));
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
    if (!equipment.available) throw Exception('อุปกรณ์นี้ยังไม่พร้อมให้ยืม');
    if (!endAt.isAfter(startAt)) {
      throw Exception('เวลาคืนต้องอยู่หลังเวลารับของ');
    }
    _bookings.insert(
      0,
      Booking(
        id: 'booking-${DateTime.now().millisecondsSinceEpoch}',
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
      ),
    );
    _bookingController.add(List.unmodifiable(_bookings));
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
    final index = _bookings.indexWhere((item) => item.id == booking.id);
    if (index < 0) throw Exception('ไม่พบรายการยืมนี้');
    final old = _bookings[index];
    if (!canTransitionBookingStatus(old.status, status)) {
      throw Exception('ไม่สามารถเปลี่ยนสถานะรายการนี้ได้');
    }
    if (status == BookingStatus.approved) {
      final equipment = _equipment.firstWhere(
        (item) => item.id == booking.equipmentId,
        orElse: () => throw Exception('ไม่พบอุปกรณ์นี้'),
      );
      if (!equipment.available) throw Exception('อุปกรณ์นี้ถูกยืมไปแล้ว');
    }
    _bookings[index] = Booking(
      id: old.id,
      equipmentId: old.equipmentId,
      equipmentName: old.equipmentName,
      equipmentCode: old.equipmentCode,
      ownerId: old.ownerId,
      ownerName: old.ownerName,
      borrowerId: old.borrowerId,
      borrowerName: old.borrowerName,
      borrowerSchoolId: old.borrowerSchoolId,
      startAt: old.startAt,
      endAt: old.endAt,
      status: status,
      purpose: old.purpose,
    );
    if (status == BookingStatus.approved || status == BookingStatus.returned) {
      _equipment = _equipment
          .map(
            (item) => item.id == booking.equipmentId
                ? Equipment(
                    id: item.id,
                    code: item.code,
                    name: item.name,
                    category: item.category,
                    ownerId: item.ownerId,
                    ownerName: item.ownerName,
                    available: status == BookingStatus.returned,
                    note: item.note,
                    imageUrl: item.imageUrl,
                  )
                : item,
          )
          .toList();
    }
    _bookingController.add(List.unmodifiable(_bookings));
    _equipmentController.add(List.unmodifiable(_equipment));
  }

  AppUser _requireUser() {
    if (_currentUser == null) throw Exception('กรุณาเข้าสู่ระบบ');
    return _currentUser!;
  }
}
