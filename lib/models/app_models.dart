import 'package:cloud_firestore/cloud_firestore.dart';

enum UserRole { student, teacher }

class AppUser {
  const AppUser({
    required this.id,
    required this.email,
    required this.name,
    required this.schoolId,
    required this.role,
  });

  final String id;
  final String email;
  final String name;
  final String schoolId;
  final UserRole role;

  factory AppUser.fromMap(String id, Map<String, dynamic> data) => AppUser(
    id: id,
    email: data['email'] as String? ?? '',
    name: data['name'] as String? ?? '',
    schoolId: data['schoolId'] as String? ?? '',
    role: data['role'] == 'teacher' ? UserRole.teacher : UserRole.student,
  );

  Map<String, dynamic> toMap() => {
    'email': email,
    'name': name,
    'schoolId': schoolId,
    'role': role.name,
  };
}

class Equipment {
  const Equipment({
    required this.id,
    required this.code,
    required this.name,
    required this.category,
    required this.ownerId,
    required this.ownerName,
    required this.available,
    this.note = '',
    this.imageUrl = '',
  });

  final String id;
  final String code;
  final String name;
  final String category;
  final String ownerId;
  final String ownerName;
  final bool available;
  final String note;
  final String imageUrl;

  factory Equipment.fromMap(String id, Map<String, dynamic> data) => Equipment(
    id: id,
    code: data['code'] as String? ?? id,
    name: data['name'] as String? ?? '',
    category: data['category'] as String? ?? 'อื่น ๆ',
    ownerId: data['ownerId'] as String? ?? '',
    ownerName: data['ownerName'] as String? ?? '-',
    available: data['available'] as bool? ?? true,
    note: data['note'] as String? ?? '',
    imageUrl: data['imageUrl'] as String? ?? '',
  );

  Map<String, dynamic> toMap() => {
    'code': code,
    'name': name,
    'category': category,
    'ownerId': ownerId,
    'ownerName': ownerName,
    'available': available,
    'note': note,
    'imageUrl': imageUrl,
    'updatedAt': FieldValue.serverTimestamp(),
  };
}

enum BookingStatus { pending, approved, rejected, returned }

bool canTransitionBookingStatus(BookingStatus current, BookingStatus next) =>
    (current == BookingStatus.pending &&
        (next == BookingStatus.approved || next == BookingStatus.rejected)) ||
    (current == BookingStatus.approved && next == BookingStatus.returned);

class Booking {
  const Booking({
    required this.id,
    required this.equipmentId,
    required this.equipmentName,
    required this.equipmentCode,
    required this.ownerId,
    required this.ownerName,
    required this.borrowerId,
    required this.borrowerName,
    required this.borrowerSchoolId,
    required this.startAt,
    required this.endAt,
    required this.status,
    this.purpose = '',
  });

  final String id;
  final String equipmentId;
  final String equipmentName;
  final String equipmentCode;
  final String ownerId;
  final String ownerName;
  final String borrowerId;
  final String borrowerName;
  final String borrowerSchoolId;
  final DateTime startAt;
  final DateTime endAt;
  final BookingStatus status;
  final String purpose;

  factory Booking.fromMap(String id, Map<String, dynamic> data) {
    DateTime readDate(dynamic value) {
      if (value is Timestamp) return value.toDate();
      if (value is String) return DateTime.tryParse(value) ?? DateTime.now();
      return DateTime.now();
    }

    return Booking(
      id: id,
      equipmentId: data['equipmentId'] as String? ?? '',
      equipmentName: data['equipmentName'] as String? ?? '',
      equipmentCode: data['equipmentCode'] as String? ?? '',
      ownerId: data['ownerId'] as String? ?? '',
      ownerName: data['ownerName'] as String? ?? '',
      borrowerId: data['borrowerId'] as String? ?? '',
      borrowerName: data['borrowerName'] as String? ?? '',
      borrowerSchoolId: data['borrowerSchoolId'] as String? ?? '',
      startAt: readDate(data['startAt']),
      endAt: readDate(data['endAt']),
      status: BookingStatus.values.firstWhere(
        (status) => status.name == data['status'],
        orElse: () => BookingStatus.pending,
      ),
      purpose: data['purpose'] as String? ?? '',
    );
  }

  Map<String, dynamic> toMap() => {
    'equipmentId': equipmentId,
    'equipmentName': equipmentName,
    'equipmentCode': equipmentCode,
    'ownerId': ownerId,
    'ownerName': ownerName,
    'borrowerId': borrowerId,
    'borrowerName': borrowerName,
    'borrowerSchoolId': borrowerSchoolId,
    'startAt': Timestamp.fromDate(startAt),
    'endAt': Timestamp.fromDate(endAt),
    'status': status.name,
    'purpose': purpose,
    'createdAt': FieldValue.serverTimestamp(),
  };
}
