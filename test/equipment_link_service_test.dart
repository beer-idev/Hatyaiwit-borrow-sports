import 'package:flutter_test/flutter_test.dart';
import 'package:hatyaiwit_borrow_sports/services/equipment_link_service.dart';

void main() {
  group('EquipmentLinkService', () {
    test('builds a production web link for an equipment id', () {
      expect(
        EquipmentLinkService.equipmentUri('ball 01').toString(),
        'https://hatyaiwit-borrow.vercel.app/equipment/ball%2001',
      );
    });

    test('extracts an id from a web or app route', () {
      expect(
        EquipmentLinkService.equipmentIdFromRoute('/equipment/abc123'),
        'abc123',
      );
      expect(
        EquipmentLinkService.equipmentIdFromQr(
          'https://hatyaiwit-borrow.vercel.app/equipment/abc123',
        ),
        'abc123',
      );
    });

    test('keeps old id-only QR labels working', () {
      expect(EquipmentLinkService.equipmentIdFromQr('SPORT-001'), 'SPORT-001');
    });

    test('rejects unrelated URLs', () {
      expect(
        EquipmentLinkService.equipmentIdFromQr('https://example.com/abc123'),
        isNull,
      );
    });
  });
}
