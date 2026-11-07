import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hatyaiwit_borrow_sports/screens/home_screen.dart';
import 'package:hatyaiwit_borrow_sports/services/demo_repository.dart';
import 'package:hatyaiwit_borrow_sports/theme/app_theme.dart';
import 'package:intl/date_symbol_data_local.dart';

void main() {
  setUpAll(() => initializeDateFormatting('th'));

  Future<DemoAppRepository> pumpHome(WidgetTester tester) async {
    final repository = DemoAppRepository();
    await tester.runAsync(
      () => repository.signIn('52972@hatyaiwit.ac.th', '12345678'),
    );
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: HomeScreen(
          repository: repository,
          user: repository.currentUser!,
          demoMode: true,
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    return repository;
  }

  testWidgets('adding equipment closes dialog without framework assertion', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(430, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await pumpHome(tester);

    await tester.tap(find.byTooltip('เพิ่มอุปกรณ์ของฉัน'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    await tester.enterText(
      find.widgetWithText(TextFormField, 'ชื่ออุปกรณ์'),
      'ลูกเทนนิส',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'รหัสอุปกรณ์'),
      'SP-900',
    );
    await tester.tap(find.widgetWithText(FilledButton, 'เพิ่มอุปกรณ์'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.text('ลูกเทนนิส'), findsOneWidget);
    expect(find.text('เพิ่มอุปกรณ์เรียบร้อยแล้ว'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('equipment sheet opens booking dialog after sheet is closed', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(430, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await pumpHome(tester);

    await tester.tap(find.text('ลูกบาสเกตบอล'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    await tester.tap(find.text('ขอยืมอุปกรณ์นี้'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.text('กรอกข้อมูลการยืม'), findsOneWidget);
    await tester.tap(find.text('ยืนยันการจอง'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.text('ส่งคำขอยืมให้เจ้าของแล้ว'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('owner can pause and resume equipment from My Equipment', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(430, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final repository = DemoAppRepository();
    await tester.runAsync(
      () => repository.signIn('teacher-01@hatyaiwit.ac.th', '12345678'),
    );
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: MyEquipmentPage(
          repository: repository,
          user: repository.currentUser!,
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    Finder basketballCard() => find
        .ancestor(of: find.text('ลูกบาสเกตบอล'), matching: find.byType(Card))
        .first;

    await tester.tap(
      find.descendant(of: basketballCard(), matching: find.text('ปิดรับยืม')),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    var equipment = (await repository.watchEquipment().first).firstWhere(
      (item) => item.id == 'eq-basketball',
    );
    expect(equipment.available, isFalse);

    await tester.tap(
      find.descendant(of: basketballCard(), matching: find.text('เปิดให้ยืม')),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    equipment = (await repository.watchEquipment().first).firstWhere(
      (item) => item.id == 'eq-basketball',
    );
    expect(equipment.available, isTrue);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('owner can edit equipment from My Equipment', (tester) async {
    await tester.binding.setSurfaceSize(const Size(430, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final repository = DemoAppRepository();
    await tester.runAsync(
      () => repository.signIn('teacher-01@hatyaiwit.ac.th', '12345678'),
    );
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: MyEquipmentPage(
          repository: repository,
          user: repository.currentUser!,
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    final basketballCard = find
        .ancestor(of: find.text('ลูกบาสเกตบอล'), matching: find.byType(Card))
        .first;
    await tester.tap(
      find.descendant(of: basketballCard, matching: find.text('แก้ไข')),
    );
    await tester.pumpAndSettle();
    expect(find.text('แก้ไขข้อมูลอุปกรณ์'), findsOneWidget);

    final nameField = find.widgetWithText(TextFormField, 'ชื่ออุปกรณ์');
    await tester.enterText(nameField, 'ลูกบาสสำหรับแข่งขัน');
    await tester.tap(find.text('บันทึกการแก้ไข'));
    await tester.pumpAndSettle();

    expect(find.text('ลูกบาสสำหรับแข่งขัน'), findsOneWidget);
    expect(find.text('แก้ไขข้อมูลอุปกรณ์เรียบร้อยแล้ว'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
