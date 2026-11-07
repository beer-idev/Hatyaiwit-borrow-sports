import 'package:flutter_test/flutter_test.dart';
import 'package:hatyaiwit_borrow_sports/models/app_models.dart';
import 'package:hatyaiwit_borrow_sports/services/demo_repository.dart';

void main() {
  group('complete borrowing workflow', () {
    test(
      'borrower requests, owner approves, and owner confirms return',
      () async {
        final repository = DemoAppRepository();
        await repository.signIn('52972@hatyaiwit.ac.th', '12345678');

        final equipment = (await repository.watchEquipment().first).firstWhere(
          (item) => item.id == 'eq-basketball',
        );
        final start = DateTime(2026, 9, 26, 9);
        final end = start.add(const Duration(hours: 2));
        await repository.createBooking(
          equipment: equipment,
          startAt: start,
          endAt: end,
          purpose: 'ซ้อมกีฬา',
        );

        var booking = (await repository.watchBookings().first).single;
        expect(booking.status, BookingStatus.pending);
        expect(
          () => repository.updateBookingStatus(booking, BookingStatus.approved),
          throwsException,
        );

        await repository.signOut();
        await repository.signIn('teacher-01@hatyaiwit.ac.th', '12345678');
        await repository.updateBookingStatus(booking, BookingStatus.approved);

        booking = (await repository.watchBookings().first).single;
        expect(booking.status, BookingStatus.approved);
        expect(
          (await repository.watchEquipment().first)
              .firstWhere((item) => item.id == equipment.id)
              .available,
          isFalse,
        );

        final borrowedEquipment = (await repository.watchEquipment().first)
            .firstWhere((item) => item.id == equipment.id);
        await repository.setEquipmentAvailability(
          borrowedEquipment,
          available: true,
        );
        booking = (await repository.watchBookings().first).single;
        expect(booking.status, BookingStatus.returned);
        expect(
          (await repository.watchEquipment().first)
              .firstWhere((item) => item.id == equipment.id)
              .available,
          isTrue,
        );
      },
    );

    test('rejects invalid borrowing operations', () async {
      final repository = DemoAppRepository();
      await repository.signIn('teacher-01@hatyaiwit.ac.th', '12345678');
      final equipment = (await repository.watchEquipment().first).firstWhere(
        (item) => item.id == 'eq-basketball',
      );
      final start = DateTime(2026, 9, 26, 9);

      expect(
        () => repository.createBooking(
          equipment: equipment,
          startAt: start,
          endAt: start.add(const Duration(hours: 1)),
          purpose: '',
        ),
        throwsException,
      );

      await repository.signOut();
      await repository.signIn('52972@hatyaiwit.ac.th', '12345678');
      expect(
        () => repository.createBooking(
          equipment: equipment,
          startAt: start,
          endAt: start,
          purpose: '',
        ),
        throwsException,
      );
    });

    test('owner can pause and resume an equipment listing', () async {
      final repository = DemoAppRepository();
      await repository.signIn('teacher-01@hatyaiwit.ac.th', '12345678');
      var equipment = (await repository.watchEquipment().first).firstWhere(
        (item) => item.id == 'eq-basketball',
      );

      await repository.setEquipmentAvailability(equipment, available: false);
      equipment = (await repository.watchEquipment().first).firstWhere(
        (item) => item.id == 'eq-basketball',
      );
      expect(equipment.available, isFalse);

      await repository.setEquipmentAvailability(equipment, available: true);
      equipment = (await repository.watchEquipment().first).firstWhere(
        (item) => item.id == 'eq-basketball',
      );
      expect(equipment.available, isTrue);
    });

    test('owner can edit equipment details and image URL', () async {
      final repository = DemoAppRepository();
      await repository.signIn('teacher-01@hatyaiwit.ac.th', '12345678');
      final equipment = (await repository.watchEquipment().first).firstWhere(
        (item) => item.id == 'eq-basketball',
      );

      await repository.updateEquipment(
        equipment: equipment,
        name: 'ลูกบาสเกตบอล รุ่นใหม่',
        code: 'sp-101',
        category: 'บาสเกตบอล',
        note: 'ใช้ในโรงยิม',
        imageUrl: 'https://example.com/basketball.jpg',
      );

      final updated = (await repository.watchEquipment().first).firstWhere(
        (item) => item.id == equipment.id,
      );
      expect(updated.name, 'ลูกบาสเกตบอล รุ่นใหม่');
      expect(updated.code, 'SP-101');
      expect(updated.note, 'ใช้ในโรงยิม');
      expect(updated.imageUrl, 'https://example.com/basketball.jpg');
      expect(updated.available, isTrue);
    });
  });
}
