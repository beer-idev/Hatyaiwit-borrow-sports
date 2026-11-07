import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../models/app_models.dart';
import '../services/app_repository.dart';
import '../services/equipment_link_service.dart';
import '../services/image_storage_service.dart';
import '../theme/app_theme.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({
    super.key,
    required this.repository,
    required this.user,
    required this.demoMode,
    this.initialEquipmentId,
  });

  final AppRepository repository;
  final AppUser user;
  final bool demoMode;
  final String? initialEquipmentId;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _index = 0;
  bool _openedInitialEquipment = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _openInitialLink());
  }

  Future<void> _openInitialLink() async {
    final equipmentId = widget.initialEquipmentId;
    if (_openedInitialEquipment || equipmentId == null || equipmentId.isEmpty) {
      return;
    }
    _openedInitialEquipment = true;

    final equipment = await widget.repository.watchEquipment().first;
    if (!mounted) return;
    final found = _findEquipment(equipment, equipmentId);
    if (found == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('ไม่พบอุปกรณ์จากลิงก์นี้'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }
    await _showEquipment(context, widget.repository, widget.user, found);
  }

  @override
  Widget build(BuildContext context) {
    final pages = [
      EquipmentCatalog(repository: widget.repository, user: widget.user),
      BookingList(
        repository: widget.repository,
        user: widget.user,
        incoming: false,
      ),
      BookingList(
        repository: widget.repository,
        user: widget.user,
        incoming: true,
      ),
      ProfilePage(
        repository: widget.repository,
        user: widget.user,
        demoMode: widget.demoMode,
      ),
    ];
    return Scaffold(
      body: IndexedStack(index: _index, children: pages),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (value) => setState(() => _index = value),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.grid_view_rounded),
            selectedIcon: Icon(Icons.grid_view_rounded, color: AppTheme.blue),
            label: 'อุปกรณ์',
          ),
          NavigationDestination(
            icon: Icon(Icons.receipt_long_outlined),
            selectedIcon: Icon(
              Icons.receipt_long_rounded,
              color: AppTheme.blue,
            ),
            label: 'การยืมของฉัน',
          ),
          NavigationDestination(
            icon: Icon(Icons.approval_outlined),
            selectedIcon: Icon(Icons.approval_rounded, color: AppTheme.blue),
            label: 'คำขอถึงฉัน',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline_rounded),
            selectedIcon: Icon(Icons.person_rounded, color: AppTheme.blue),
            label: 'โปรไฟล์',
          ),
        ],
      ),
      floatingActionButton: _index == 0
          ? FloatingActionButton.extended(
              onPressed: () => _openScanner(context),
              backgroundColor: AppTheme.navy,
              foregroundColor: Colors.white,
              icon: const Icon(Icons.qr_code_scanner_rounded),
              label: const Text(
                'สแกน QR',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
            )
          : null,
    );
  }

  Future<void> _openScanner(BuildContext context) async {
    final code = await Navigator.of(
      context,
    ).push<String>(MaterialPageRoute(builder: (_) => const QrScannerPage()));
    if (!context.mounted || code == null) return;
    final equipmentId = EquipmentLinkService.equipmentIdFromQr(code);
    if (equipmentId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('QR นี้ไม่ใช่ลิงก์อุปกรณ์ของระบบ'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }
    final equipment = await widget.repository.watchEquipment().first;
    final found = _findEquipment(equipment, equipmentId);
    if (!context.mounted) return;
    if (found == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('ไม่พบอุปกรณ์จาก QR นี้'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } else {
      _showEquipment(context, widget.repository, widget.user, found);
    }
  }

  Equipment? _findEquipment(List<Equipment> equipment, String value) {
    for (final item in equipment) {
      if (item.id == value || item.code.toLowerCase() == value.toLowerCase()) {
        return item;
      }
    }
    return null;
  }
}

class PageHeader extends StatelessWidget {
  const PageHeader({
    super.key,
    required this.title,
    required this.subtitle,
    this.action,
  });
  final String title;
  final String subtitle;
  final Widget? action;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(20, 16, 20, 14),
    child: Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w900,
                  color: AppTheme.navy,
                ),
              ),
              const SizedBox(height: 3),
              Text(subtitle, style: TextStyle(color: Colors.blueGrey.shade600)),
            ],
          ),
        ),
        action ?? const SizedBox.shrink(),
      ],
    ),
  );
}

class EquipmentCatalog extends StatefulWidget {
  const EquipmentCatalog({
    super.key,
    required this.repository,
    required this.user,
  });
  final AppRepository repository;
  final AppUser user;

  @override
  State<EquipmentCatalog> createState() => _EquipmentCatalogState();
}

class _EquipmentCatalogState extends State<EquipmentCatalog> {
  final _search = TextEditingController();
  String _query = '';
  String _category = 'ทั้งหมด';

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: StreamBuilder<List<Equipment>>(
        stream: widget.repository.watchEquipment(),
        builder: (context, snapshot) {
          final all = snapshot.data ?? [];
          final visible = all
              .where((item) => item.available || item.ownerId == widget.user.id)
              .toList();
          final categories = [
            'ทั้งหมด',
            ...{for (final item in visible) item.category},
          ];
          final filtered = visible.where((item) {
            final text = '${item.name} ${item.code} ${item.ownerName}'
                .toLowerCase();
            return text.contains(_query.toLowerCase()) &&
                (_category == 'ทั้งหมด' || item.category == _category);
          }).toList();
          return CustomScrollView(
            slivers: [
              SliverToBoxAdapter(
                child: PageHeader(
                  title: 'อุปกรณ์กีฬา',
                  subtitle:
                      'สวัสดี ${widget.user.name.split(' ').first} • เลือกหรือสแกนเพื่อยืม',
                  action: IconButton.filledTonal(
                    tooltip: 'เพิ่มอุปกรณ์ของฉัน',
                    onPressed: () =>
                        showAddEquipmentDialog(context, widget.repository),
                    icon: const Icon(Icons.add_rounded),
                  ),
                ),
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: TextField(
                    controller: _search,
                    onChanged: (value) => setState(() => _query = value),
                    decoration: InputDecoration(
                      hintText: 'ค้นหาชื่อ รหัส หรือเจ้าของอุปกรณ์',
                      prefixIcon: const Icon(Icons.search_rounded),
                      suffixIcon: _query.isEmpty
                          ? null
                          : IconButton(
                              onPressed: () {
                                _search.clear();
                                setState(() => _query = '');
                              },
                              icon: const Icon(Icons.close_rounded),
                            ),
                    ),
                  ),
                ),
              ),
              SliverToBoxAdapter(
                child: SizedBox(
                  height: 62,
                  child: ListView.separated(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 12,
                    ),
                    scrollDirection: Axis.horizontal,
                    itemCount: categories.length,
                    separatorBuilder: (_, _) => const SizedBox(width: 8),
                    itemBuilder: (context, index) {
                      final value = categories[index];
                      return ChoiceChip(
                        label: Text(value),
                        selected: _category == value,
                        onSelected: (_) => setState(() => _category = value),
                      );
                    },
                  ),
                ),
              ),
              if (snapshot.connectionState == ConnectionState.waiting &&
                  all.isEmpty)
                const SliverFillRemaining(
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (filtered.isEmpty)
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: EmptyState(
                    icon: Icons.sports_tennis_rounded,
                    title: 'ยังไม่พบอุปกรณ์',
                    message: 'ลองเปลี่ยนคำค้นหา หรือเพิ่มอุปกรณ์ของคุณ',
                  ),
                )
              else
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 110),
                  sliver: SliverLayoutBuilder(
                    builder: (context, constraints) {
                      final count = constraints.crossAxisExtent >= 900
                          ? 4
                          : constraints.crossAxisExtent >= 600
                          ? 3
                          : 2;
                      return SliverGrid(
                        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: count,
                          crossAxisSpacing: 12,
                          mainAxisSpacing: 12,
                          childAspectRatio: count == 2 ? .68 : .76,
                        ),
                        delegate: SliverChildBuilderDelegate((context, index) {
                          final item = filtered[index];
                          return EquipmentCard(
                            equipment: item,
                            isMine: item.ownerId == widget.user.id,
                            onTap: () => _showEquipment(
                              context,
                              widget.repository,
                              widget.user,
                              item,
                            ),
                          );
                        }, childCount: filtered.length),
                      );
                    },
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

class EquipmentCard extends StatelessWidget {
  const EquipmentCard({
    super.key,
    required this.equipment,
    required this.isMine,
    required this.onTap,
  });
  final Equipment equipment;
  final bool isMine;
  final VoidCallback onTap;

  IconData get icon => switch (equipment.category) {
    'ฟุตบอล' => Icons.sports_soccer_rounded,
    'บาสเกตบอล' => Icons.sports_basketball_rounded,
    'วอลเลย์บอล' => Icons.sports_volleyball_rounded,
    'แบดมินตัน' => Icons.sports_tennis_rounded,
    _ => Icons.fitness_center_rounded,
  };

  @override
  Widget build(BuildContext context) => Card(
    clipBehavior: Clip.antiAlias,
    child: InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.all(13),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: EquipmentImage(
                equipment: equipment,
                icon: icon,
                borderRadius: 16,
                iconSize: 62,
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: Text(
                    equipment.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 15,
                      color: AppTheme.navy,
                    ),
                  ),
                ),
                if (isMine)
                  const Icon(
                    Icons.person_pin_circle_rounded,
                    color: AppTheme.orange,
                    size: 18,
                  ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              '${equipment.code} • ${equipment.category}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: Colors.blueGrey.shade600, fontSize: 12),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: equipment.available
                        ? const Color(0xFF18A66A)
                        : const Color(0xFFE45C5C),
                  ),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    equipment.available ? 'พร้อมให้ยืม' : 'ไม่พร้อมให้ยืม',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: equipment.available
                          ? const Color(0xFF137A50)
                          : const Color(0xFFB13C3C),
                      fontWeight: FontWeight.w700,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    ),
  );
}

class EquipmentImage extends StatelessWidget {
  const EquipmentImage({
    super.key,
    required this.equipment,
    required this.icon,
    required this.borderRadius,
    this.iconSize = 40,
  });

  final Equipment equipment;
  final IconData icon;
  final double borderRadius;
  final double iconSize;

  @override
  Widget build(BuildContext context) {
    final fallback = Container(
      width: double.infinity,
      height: double.infinity,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [const Color(0xFFE9F0FF), Colors.blue.shade50],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Icon(icon, size: iconSize, color: AppTheme.blue),
    );

    return ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: equipment.imageUrl.isEmpty
          ? fallback
          : Image.network(
              equipment.imageUrl,
              width: double.infinity,
              height: double.infinity,
              fit: BoxFit.cover,
              loadingBuilder: (context, child, progress) => progress == null
                  ? child
                  : const Center(child: CircularProgressIndicator()),
              errorBuilder: (_, _, _) => fallback,
            ),
    );
  }
}

Future<void> _showEquipment(
  BuildContext context,
  AppRepository repository,
  AppUser user,
  Equipment equipment,
) async {
  final shouldBook = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    builder: (sheetContext) => Padding(
      padding: EdgeInsets.fromLTRB(
        22,
        4,
        22,
        22 + MediaQuery.viewInsetsOf(sheetContext).bottom,
      ),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                SizedBox(
                  width: 74,
                  height: 74,
                  child: EquipmentImage(
                    equipment: equipment,
                    icon: Icons.sports_tennis_rounded,
                    borderRadius: 20,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        equipment.name,
                        style: Theme.of(sheetContext).textTheme.titleLarge
                            ?.copyWith(fontWeight: FontWeight.w900),
                      ),
                      Text(
                        '${equipment.code} • ${equipment.category}',
                        style: const TextStyle(color: Colors.blueGrey),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        equipment.available
                            ? '● พร้อมให้ยืม'
                            : '● ไม่พร้อมให้ยืม',
                        style: TextStyle(
                          color: equipment.available
                              ? const Color(0xFF137A50)
                              : const Color(0xFFB13C3C),
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            _InfoTile(
              icon: Icons.person_outline_rounded,
              label: 'เจ้าของอุปกรณ์',
              value: equipment.ownerName,
            ),
            if (equipment.note.isNotEmpty)
              _InfoTile(
                icon: Icons.notes_rounded,
                label: 'รายละเอียด',
                value: equipment.note,
              ),
            const SizedBox(height: 12),
            if (equipment.ownerId == user.id)
              OutlinedButton.icon(
                onPressed: () => showDialog<void>(
                  context: sheetContext,
                  builder: (qrContext) => AlertDialog(
                    title: const Text('QR อุปกรณ์'),
                    content: SizedBox(
                      width: 230,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          QrImageView(
                            data: EquipmentLinkService.equipmentUri(
                              equipment.id,
                            ).toString(),
                            size: 210,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            equipment.code,
                            style: const TextStyle(fontWeight: FontWeight.w800),
                          ),
                        ],
                      ),
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(qrContext),
                        child: const Text('ปิด'),
                      ),
                    ],
                  ),
                ),
                icon: const Icon(Icons.qr_code_2_rounded),
                label: const Text('แสดง QR สำหรับติดอุปกรณ์'),
              )
            else
              FilledButton.icon(
                onPressed: equipment.available
                    ? () => Navigator.pop(sheetContext, true)
                    : null,
                icon: const Icon(Icons.event_available_rounded),
                label: Text(
                  equipment.available ? 'ขอยืมอุปกรณ์นี้' : 'ยังไม่พร้อมให้ยืม',
                ),
              ),
          ],
        ),
      ),
    ),
  );
  if (shouldBook == true && context.mounted) {
    await showBookingDialog(context, repository, equipment);
  }
}

class _InfoTile extends StatelessWidget {
  const _InfoTile({
    required this.icon,
    required this.label,
    required this.value,
  });
  final IconData icon;
  final String label;
  final String value;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 7),
    child: Row(
      children: [
        Icon(icon, color: Colors.blueGrey, size: 21),
        const SizedBox(width: 10),
        Text('$label: ', style: const TextStyle(color: Colors.blueGrey)),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
        ),
      ],
    ),
  );
}

Future<void> showBookingDialog(
  BuildContext context,
  AppRepository repository,
  Equipment equipment,
) async {
  final booked = await showDialog<bool>(
    context: context,
    builder: (_) =>
        _BookingDialog(repository: repository, equipment: equipment),
  );
  if (booked == true && context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('ส่งคำขอยืมให้เจ้าของแล้ว'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}

class _BookingDialog extends StatefulWidget {
  const _BookingDialog({required this.repository, required this.equipment});

  final AppRepository repository;
  final Equipment equipment;

  @override
  State<_BookingDialog> createState() => _BookingDialogState();
}

class _BookingDialogState extends State<_BookingDialog> {
  final _purpose = TextEditingController();
  late DateTime _start;
  late DateTime _end;
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _start = DateTime.now().add(const Duration(hours: 1));
    _end = DateTime.now().add(const Duration(hours: 3));
  }

  @override
  void dispose() {
    _purpose.dispose();
    super.dispose();
  }

  Future<DateTime?> _pickDateTime(DateTime current) async {
    final now = DateTime.now();
    final date = await showDatePicker(
      context: context,
      firstDate: DateTime(now.year, now.month, now.day),
      lastDate: now.add(const Duration(days: 180)),
      initialDate: current.isBefore(now) ? now : current,
    );
    if (date == null || !mounted) return null;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(current),
    );
    return time == null
        ? null
        : DateTime(date.year, date.month, date.day, time.hour, time.minute);
  }

  Future<void> _submit() async {
    if (!_end.isAfter(_start)) {
      setState(() => _error = 'เวลาคืนต้องอยู่หลังเวลารับของ');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await widget.repository.createBooking(
        equipment: widget.equipment,
        startAt: _start,
        endAt: _end,
        purpose: _purpose.text,
      );
      if (mounted) Navigator.pop(context, true);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = error.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('กรอกข้อมูลการยืม'),
      content: SizedBox(
        width: 420,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                widget.equipment.name,
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  color: AppTheme.blue,
                ),
              ),
              const SizedBox(height: 16),
              _DateButton(
                label: 'วัน–เวลารับของ',
                value: _start,
                onTap: () async {
                  final value = await _pickDateTime(_start);
                  if (value != null && mounted) {
                    setState(() => _start = value);
                  }
                },
              ),
              const SizedBox(height: 10),
              _DateButton(
                label: 'วัน–เวลาคืนของ',
                value: _end,
                onTap: () async {
                  final value = await _pickDateTime(_end);
                  if (value != null && mounted) {
                    setState(() => _end = value);
                  }
                },
              ),
              const SizedBox(height: 14),
              TextField(
                controller: _purpose,
                maxLines: 2,
                enabled: !_busy,
                decoration: const InputDecoration(
                  labelText: 'วัตถุประสงค์ / หมายเหตุ',
                  hintText: 'เช่น ใช้ซ้อมกีฬาหลังเลิกเรียน',
                ),
              ),
              if (_error != null) ...[
                const SizedBox(height: 12),
                Text(
                  _error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _busy ? null : () => Navigator.pop(context, false),
          child: const Text('ยกเลิก'),
        ),
        FilledButton(
          onPressed: _busy ? null : _submit,
          child: Text(_busy ? 'กำลังส่ง...' : 'ยืนยันการจอง'),
        ),
      ],
    );
  }
}

class _DateButton extends StatelessWidget {
  const _DateButton({
    required this.label,
    required this.value,
    required this.onTap,
  });
  final String label;
  final DateTime value;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    borderRadius: BorderRadius.circular(14),
    child: Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF7F9FC),
        border: Border.all(color: const Color(0xFFE1E7EF)),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          const Icon(Icons.event_outlined, color: AppTheme.blue),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(fontSize: 12, color: Colors.blueGrey),
                ),
                Text(
                  DateFormat('d MMM yyyy • HH:mm', 'th').format(value),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}

Future<void> showAddEquipmentDialog(
  BuildContext context,
  AppRepository repository,
) async {
  final added = await showDialog<bool>(
    context: context,
    builder: (_) => _EquipmentFormDialog(repository: repository),
  );
  if (added == true && context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('เพิ่มอุปกรณ์เรียบร้อยแล้ว'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}

Future<void> showEditEquipmentDialog(
  BuildContext context,
  AppRepository repository,
  Equipment equipment,
) async {
  final updated = await showDialog<bool>(
    context: context,
    builder: (_) =>
        _EquipmentFormDialog(repository: repository, equipment: equipment),
  );
  if (updated == true && context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('แก้ไขข้อมูลอุปกรณ์เรียบร้อยแล้ว'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}

class _EquipmentFormDialog extends StatefulWidget {
  const _EquipmentFormDialog({required this.repository, this.equipment});

  final AppRepository repository;
  final Equipment? equipment;

  @override
  State<_EquipmentFormDialog> createState() => _EquipmentFormDialogState();
}

class _EquipmentFormDialogState extends State<_EquipmentFormDialog> {
  static const _categories = [
    'ฟุตบอล',
    'บาสเกตบอล',
    'วอลเลย์บอล',
    'แบดมินตัน',
    'อุปกรณ์ฝึกซ้อม',
    'อื่น ๆ',
  ];

  final _formKey = GlobalKey<FormState>();
  final _imageStorage = const CloudinaryImageStorage();
  late final TextEditingController _name;
  late final TextEditingController _code;
  late final TextEditingController _note;
  late String _category;
  final _picker = ImagePicker();
  XFile? _selectedImage;
  Uint8List? _selectedImageBytes;
  bool _removeExistingImage = false;
  bool _busy = false;
  String? _error;

  bool get _editing => widget.equipment != null;

  @override
  void initState() {
    super.initState();
    final equipment = widget.equipment;
    _name = TextEditingController(text: equipment?.name ?? '');
    _code = TextEditingController(text: equipment?.code ?? '');
    _note = TextEditingController(text: equipment?.note ?? '');
    _category = _categories.contains(equipment?.category)
        ? equipment!.category
        : _categories.first;
  }

  @override
  void dispose() {
    _name.dispose();
    _code.dispose();
    _note.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    try {
      final image = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1600,
        imageQuality: 82,
        requestFullMetadata: false,
      );
      if (image == null) return;
      final bytes = await image.readAsBytes();
      if (bytes.length > 5 * 1024 * 1024) {
        throw Exception('รูปต้องมีขนาดไม่เกิน 5 MB');
      }
      if (!mounted) return;
      setState(() {
        _selectedImage = image;
        _selectedImageBytes = bytes;
        _removeExistingImage = false;
        _error = null;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _error = error.toString().replaceFirst('Exception: ', ''));
    }
  }

  void _clearImage() {
    setState(() {
      _selectedImage = null;
      _selectedImageBytes = null;
      _removeExistingImage = true;
    });
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      var imageUrl = _removeExistingImage
          ? ''
          : widget.equipment?.imageUrl ?? '';
      if (_selectedImage != null) {
        imageUrl = await _imageStorage.upload(_selectedImage!);
      }

      if (_editing) {
        await widget.repository.updateEquipment(
          equipment: widget.equipment!,
          name: _name.text,
          code: _code.text,
          category: _category,
          note: _note.text,
          imageUrl: imageUrl,
        );
      } else {
        await widget.repository.addEquipment(
          name: _name.text,
          code: _code.text,
          category: _category,
          note: _note.text,
          imageUrl: imageUrl,
        );
      }
      if (mounted) Navigator.pop(context, true);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = error.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final existingImageUrl = widget.equipment?.imageUrl ?? '';
    final hasExistingImage =
        existingImageUrl.isNotEmpty && !_removeExistingImage;

    return AlertDialog(
      title: Text(_editing ? 'แก้ไขข้อมูลอุปกรณ์' : 'เพิ่มอุปกรณ์ของฉัน'),
      content: SizedBox(
        width: 420,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: double.infinity,
                  height: 160,
                  clipBehavior: Clip.antiAlias,
                  decoration: BoxDecoration(
                    color: const Color(0xFFE9F0FF),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: _selectedImageBytes != null
                      ? Image.memory(_selectedImageBytes!, fit: BoxFit.cover)
                      : hasExistingImage
                      ? Image.network(
                          existingImageUrl,
                          fit: BoxFit.cover,
                          errorBuilder: (_, _, _) => const Icon(
                            Icons.broken_image_outlined,
                            size: 48,
                            color: AppTheme.blue,
                          ),
                        )
                      : const Icon(
                          Icons.add_photo_alternate_outlined,
                          size: 52,
                          color: AppTheme.blue,
                        ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _busy ? null : _pickImage,
                        icon: const Icon(Icons.photo_library_outlined),
                        label: Text(
                          _selectedImageBytes == null && !hasExistingImage
                              ? 'เลือกรูปอุปกรณ์'
                              : 'เปลี่ยนรูป',
                        ),
                      ),
                    ),
                    if (_selectedImageBytes != null || hasExistingImage) ...[
                      const SizedBox(width: 8),
                      IconButton(
                        tooltip: 'นำรูปออก',
                        onPressed: _busy ? null : _clearImage,
                        icon: const Icon(Icons.delete_outline_rounded),
                      ),
                    ],
                  ],
                ),
                if (!_imageStorage.isConfigured)
                  const Padding(
                    padding: EdgeInsets.only(bottom: 10),
                    child: Text(
                      'หากต้องการอัปโหลดรูป ให้ตั้งค่า Cloudinary ตาม README ก่อน',
                      style: TextStyle(fontSize: 12, color: Colors.blueGrey),
                    ),
                  ),
                TextFormField(
                  controller: _name,
                  enabled: !_busy,
                  decoration: const InputDecoration(labelText: 'ชื่ออุปกรณ์'),
                  validator: (value) => (value?.trim().isEmpty ?? true)
                      ? 'กรุณากรอกชื่ออุปกรณ์'
                      : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _code,
                  enabled: !_busy,
                  textCapitalization: TextCapitalization.characters,
                  decoration: const InputDecoration(
                    labelText: 'รหัสอุปกรณ์',
                    hintText: 'เช่น SP-006',
                  ),
                  validator: (value) =>
                      (value?.trim().isEmpty ?? true) ? 'กรุณากรอกรหัส' : null,
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: _category,
                  decoration: const InputDecoration(labelText: 'หมวดหมู่'),
                  items: _categories
                      .map(
                        (value) =>
                            DropdownMenuItem(value: value, child: Text(value)),
                      )
                      .toList(),
                  onChanged: _busy
                      ? null
                      : (value) {
                          if (value != null) {
                            setState(() => _category = value);
                          }
                        },
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _note,
                  enabled: !_busy,
                  maxLines: 2,
                  decoration: const InputDecoration(
                    labelText: 'รายละเอียดเพิ่มเติม (ถ้ามี)',
                  ),
                ),
                if (_error != null) ...[
                  const SizedBox(height: 12),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      _error!,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _busy ? null : () => Navigator.pop(context, false),
          child: const Text('ยกเลิก'),
        ),
        FilledButton(
          onPressed: _busy ? null : _submit,
          child: Text(
            _busy
                ? _selectedImage != null
                      ? 'กำลังอัปโหลด...'
                      : 'กำลังบันทึก...'
                : _editing
                ? 'บันทึกการแก้ไข'
                : 'เพิ่มอุปกรณ์',
          ),
        ),
      ],
    );
  }
}

class BookingList extends StatelessWidget {
  const BookingList({
    super.key,
    required this.repository,
    required this.user,
    required this.incoming,
  });
  final AppRepository repository;
  final AppUser user;
  final bool incoming;

  @override
  Widget build(BuildContext context) => SafeArea(
    child: StreamBuilder<List<Booking>>(
      stream: repository.watchBookings(),
      builder: (context, snapshot) {
        final items = (snapshot.data ?? [])
            .where(
              (booking) => incoming
                  ? booking.ownerId == user.id
                  : booking.borrowerId == user.id,
            )
            .toList();
        final pending = items
            .where((item) => item.status == BookingStatus.pending)
            .length;
        return CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: PageHeader(
                title: incoming ? 'คำขอถึงฉัน' : 'การยืมของฉัน',
                subtitle: incoming
                    ? (pending > 0
                          ? 'มี $pending คำขอรอการอนุมัติ'
                          : 'จัดการคำขอยืมและยืนยันการคืน')
                    : 'ติดตามสถานะคำขอยืมทั้งหมด',
              ),
            ),
            if (items.isEmpty)
              SliverFillRemaining(
                hasScrollBody: false,
                child: EmptyState(
                  icon: incoming
                      ? Icons.inbox_outlined
                      : Icons.receipt_long_outlined,
                  title: incoming ? 'ยังไม่มีคำขอยืม' : 'ยังไม่มีรายการยืม',
                  message: incoming
                      ? 'เมื่อมีคนขอยืมอุปกรณ์ของคุณ รายการจะปรากฏที่นี่'
                      : 'เลือกอุปกรณ์จากหน้าแรกเพื่อส่งคำขอ',
                ),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 30),
                sliver: SliverList.separated(
                  itemCount: items.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 10),
                  itemBuilder: (context, index) => BookingCard(
                    booking: items[index],
                    incoming: incoming,
                    repository: repository,
                  ),
                ),
              ),
          ],
        );
      },
    ),
  );
}

class BookingCard extends StatelessWidget {
  const BookingCard({
    super.key,
    required this.booking,
    required this.incoming,
    required this.repository,
  });
  final Booking booking;
  final bool incoming;
  final AppRepository repository;

  (String, Color, Color) get statusStyle => switch (booking.status) {
    BookingStatus.pending => (
      'รออนุมัติ',
      const Color(0xFF9A5B14),
      const Color(0xFFFFF2D9),
    ),
    BookingStatus.approved => (
      'อนุมัติแล้ว',
      const Color(0xFF14774D),
      const Color(0xFFDCF7EA),
    ),
    BookingStatus.rejected => (
      'ไม่อนุมัติ',
      const Color(0xFFA23C3C),
      const Color(0xFFFFE5E5),
    ),
    BookingStatus.returned => (
      'คืนแล้ว',
      const Color(0xFF425777),
      const Color(0xFFE8EEF7),
    ),
  };

  Future<void> _update(BuildContext context, BookingStatus status) async {
    try {
      await repository.updateBookingStatus(booking, status);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              status == BookingStatus.returned
                  ? 'ยืนยันการคืนเรียบร้อย'
                  : 'อัปเดตสถานะเรียบร้อย',
            ),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error.toString())));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final (label, foreground, background) = statusStyle;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: const Color(0xFFE9F0FF),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Icon(
                    Icons.sports_basketball_rounded,
                    color: AppTheme.blue,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        booking.equipmentName,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: AppTheme.navy,
                        ),
                      ),
                      Text(
                        '${booking.equipmentCode} • ${incoming ? booking.borrowerName : booking.ownerName}',
                        style: const TextStyle(
                          color: Colors.blueGrey,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: background,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    label,
                    style: TextStyle(
                      color: foreground,
                      fontWeight: FontWeight.w800,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
            const Divider(height: 26),
            Row(
              children: [
                const Icon(
                  Icons.schedule_rounded,
                  size: 18,
                  color: Colors.blueGrey,
                ),
                const SizedBox(width: 7),
                Expanded(
                  child: Text(
                    '${DateFormat('d MMM HH:mm', 'th').format(booking.startAt)}  →  ${DateFormat('d MMM HH:mm', 'th').format(booking.endAt)}',
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
            if (booking.purpose.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                '“${booking.purpose}”',
                style: TextStyle(
                  color: Colors.blueGrey.shade700,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ],
            if (incoming && booking.status == BookingStatus.pending) ...[
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => _update(context, BookingStatus.rejected),
                      child: const Text('ไม่อนุมัติ'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: () => _update(context, BookingStatus.approved),
                      icon: const Icon(Icons.check_rounded),
                      label: const Text('อนุมัติ'),
                    ),
                  ),
                ],
              ),
            ],
            if (incoming && booking.status == BookingStatus.approved) ...[
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                child: FilledButton.tonalIcon(
                  onPressed: () => _update(context, BookingStatus.returned),
                  icon: const Icon(Icons.assignment_turned_in_outlined),
                  label: const Text('ยืนยันว่าได้รับของคืนแล้ว'),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class MyEquipmentPage extends StatefulWidget {
  const MyEquipmentPage({
    super.key,
    required this.repository,
    required this.user,
  });

  final AppRepository repository;
  final AppUser user;

  @override
  State<MyEquipmentPage> createState() => _MyEquipmentPageState();
}

class _MyEquipmentPageState extends State<MyEquipmentPage> {
  late final Stream<List<Equipment>> _equipmentStream;
  late final Stream<List<Booking>> _bookingStream;
  final Set<String> _busyEquipmentIds = {};

  @override
  void initState() {
    super.initState();
    _equipmentStream = widget.repository.watchEquipment();
    _bookingStream = widget.repository.watchBookings();
  }

  Future<void> _changeAvailability(
    Equipment equipment,
    Booking? activeBooking,
  ) async {
    final available = activeBooking != null || !equipment.available;
    setState(() => _busyEquipmentIds.add(equipment.id));
    try {
      await widget.repository.setEquipmentAvailability(
        equipment,
        available: available,
      );
      if (!mounted) return;
      final message = activeBooking != null
          ? 'ยืนยันว่าได้รับอุปกรณ์คืนแล้ว'
          : available
          ? 'เปิดให้อุปกรณ์นี้ยืมได้แล้ว'
          : 'ปิดรับยืมอุปกรณ์นี้แล้ว';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error.toString().replaceFirst('Exception: ', '')),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _busyEquipmentIds.remove(equipment.id));
      }
    }
  }

  void _showQr(Equipment equipment) {
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(equipment.name),
        content: SizedBox(
          width: 230,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              QrImageView(
                data: EquipmentLinkService.equipmentUri(
                  equipment.id,
                ).toString(),
                size: 210,
              ),
              const SizedBox(height: 8),
              Text(
                equipment.code,
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('ปิด'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('อุปกรณ์ของฉัน')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => showAddEquipmentDialog(context, widget.repository),
        icon: const Icon(Icons.add_rounded),
        label: const Text('เพิ่มอุปกรณ์'),
      ),
      body: SafeArea(
        child: StreamBuilder<List<Equipment>>(
          stream: _equipmentStream,
          builder: (context, equipmentSnapshot) {
            if (equipmentSnapshot.hasError) {
              return const EmptyState(
                icon: Icons.cloud_off_rounded,
                title: 'โหลดอุปกรณ์ไม่สำเร็จ',
                message: 'กรุณาตรวจสอบอินเทอร์เน็ตแล้วลองใหม่',
              );
            }
            final equipment = (equipmentSnapshot.data ?? [])
                .where((item) => item.ownerId == widget.user.id)
                .toList();
            if (equipmentSnapshot.connectionState == ConnectionState.waiting &&
                equipment.isEmpty) {
              return const Center(child: CircularProgressIndicator());
            }
            if (equipment.isEmpty) {
              return const EmptyState(
                icon: Icons.inventory_2_outlined,
                title: 'ยังไม่มีอุปกรณ์ของฉัน',
                message: 'กดเพิ่มอุปกรณ์เพื่อเปิดให้ผู้อื่นยืม',
              );
            }

            return StreamBuilder<List<Booking>>(
              stream: _bookingStream,
              builder: (context, bookingSnapshot) {
                final bookings = bookingSnapshot.data ?? [];
                return ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
                  itemCount: equipment.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 10),
                  itemBuilder: (context, index) {
                    final item = equipment[index];
                    Booking? activeBooking;
                    for (final booking in bookings) {
                      if (booking.equipmentId == item.id &&
                          booking.ownerId == widget.user.id &&
                          booking.status == BookingStatus.approved) {
                        activeBooking = booking;
                        break;
                      }
                    }
                    return _MyEquipmentCard(
                      equipment: item,
                      activeBooking: activeBooking,
                      busy: _busyEquipmentIds.contains(item.id),
                      onShowQr: () => _showQr(item),
                      onEdit: () => showEditEquipmentDialog(
                        context,
                        widget.repository,
                        item,
                      ),
                      onChangeAvailability: () =>
                          _changeAvailability(item, activeBooking),
                    );
                  },
                );
              },
            );
          },
        ),
      ),
    );
  }
}

class _MyEquipmentCard extends StatelessWidget {
  const _MyEquipmentCard({
    required this.equipment,
    required this.activeBooking,
    required this.busy,
    required this.onShowQr,
    required this.onEdit,
    required this.onChangeAvailability,
  });

  final Equipment equipment;
  final Booking? activeBooking;
  final bool busy;
  final VoidCallback onShowQr;
  final VoidCallback onEdit;
  final VoidCallback onChangeAvailability;

  @override
  Widget build(BuildContext context) {
    final isBorrowed = activeBooking != null;
    final statusLabel = isBorrowed
        ? 'กำลังถูกยืม'
        : equipment.available
        ? 'เปิดให้ยืม'
        : 'ปิดรับยืม';
    final statusColor = equipment.available && !isBorrowed
        ? const Color(0xFF137A50)
        : const Color(0xFFB13C3C);
    final actionLabel = isBorrowed
        ? 'ได้รับคืนแล้ว'
        : equipment.available
        ? 'ปิดรับยืม'
        : 'เปิดให้ยืม';

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: 52,
                  height: 52,
                  child: EquipmentImage(
                    equipment: equipment,
                    icon: Icons.sports_basketball_rounded,
                    borderRadius: 15,
                    iconSize: 28,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        equipment.name,
                        style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                          color: AppTheme.navy,
                        ),
                      ),
                      Text(
                        '${equipment.code} • ${equipment.category}',
                        style: const TextStyle(color: Colors.blueGrey),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 9,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    statusLabel,
                    style: TextStyle(
                      color: statusColor,
                      fontWeight: FontWeight.w700,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
            if (equipment.note.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(
                equipment.note,
                style: TextStyle(color: Colors.blueGrey.shade700),
              ),
            ],
            if (activeBooking != null) ...[
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF4E8),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  'ผู้ยืม: ${activeBooking!.borrowerName} (${activeBooking!.borrowerSchoolId})',
                  style: const TextStyle(
                    color: Color(0xFF8A4D19),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
            const SizedBox(height: 14),
            Row(
              children: [
                OutlinedButton.icon(
                  onPressed: busy ? null : onShowQr,
                  icon: const Icon(Icons.qr_code_2_rounded),
                  label: const Text('QR'),
                ),
                const SizedBox(width: 8),
                OutlinedButton.icon(
                  onPressed: busy ? null : onEdit,
                  icon: const Icon(Icons.edit_outlined),
                  label: const Text('แก้ไข'),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: FilledButton.tonalIcon(
                    onPressed: busy ? null : onChangeAvailability,
                    icon: busy
                        ? const SizedBox.square(
                            dimension: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Icon(
                            isBorrowed
                                ? Icons.assignment_turned_in_outlined
                                : equipment.available
                                ? Icons.pause_circle_outline_rounded
                                : Icons.play_circle_outline_rounded,
                          ),
                    label: Text(actionLabel),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class ProfilePage extends StatelessWidget {
  const ProfilePage({
    super.key,
    required this.repository,
    required this.user,
    required this.demoMode,
  });
  final AppRepository repository;
  final AppUser user;
  final bool demoMode;

  @override
  Widget build(BuildContext context) => SafeArea(
    child: ListView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 30),
      children: [
        Text(
          'โปรไฟล์',
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.w900,
            color: AppTheme.navy,
          ),
        ),
        const SizedBox(height: 18),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                CircleAvatar(
                  radius: 38,
                  backgroundColor: const Color(0xFFE7EFFF),
                  child: Text(
                    user.name.isEmpty ? '?' : user.name.characters.first,
                    style: const TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w900,
                      color: AppTheme.blue,
                    ),
                  ),
                ),
                const SizedBox(height: 13),
                Text(
                  user.name,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                    color: AppTheme.navy,
                  ),
                ),
                Text(
                  user.role == UserRole.teacher ? 'ครู / บุคลากร' : 'นักเรียน',
                  style: const TextStyle(
                    color: AppTheme.blue,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 20),
                _ProfileRow(
                  icon: Icons.alternate_email_rounded,
                  label: 'อีเมล',
                  value: user.email,
                ),
                _ProfileRow(
                  icon: Icons.badge_outlined,
                  label: 'รหัสผู้ใช้',
                  value: user.schoolId,
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        Card(
          child: Column(
            children: [
              ListTile(
                leading: const Icon(
                  Icons.inventory_2_outlined,
                  color: AppTheme.blue,
                ),
                title: const Text('อุปกรณ์ของฉัน'),
                subtitle: const Text('ดูข้อมูล จัดการสถานะ และยืนยันการคืน'),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) =>
                        MyEquipmentPage(repository: repository, user: user),
                  ),
                ),
              ),
              const Divider(height: 1),
              ListTile(
                leading: const Icon(
                  Icons.logout_rounded,
                  color: Color(0xFFB13C3C),
                ),
                title: const Text('ออกจากระบบ'),
                onTap: () => repository.signOut(),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

class _ProfileRow extends StatelessWidget {
  const _ProfileRow({
    required this.icon,
    required this.label,
    required this.value,
  });
  final IconData icon;
  final String label;
  final String value;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 8),
    child: Row(
      children: [
        Icon(icon, size: 20, color: Colors.blueGrey),
        const SizedBox(width: 10),
        Text(label, style: const TextStyle(color: Colors.blueGrey)),
        const Spacer(),
        Flexible(
          child: Text(
            value,
            textAlign: TextAlign.end,
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
        ),
      ],
    ),
  );
}

class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
  });
  final IconData icon;
  final String title;
  final String message;
  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 64, color: Colors.blueGrey.shade200),
          const SizedBox(height: 14),
          Text(
            title,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 5),
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.blueGrey),
          ),
        ],
      ),
    ),
  );
}

class QrScannerPage extends StatefulWidget {
  const QrScannerPage({super.key});
  @override
  State<QrScannerPage> createState() => _QrScannerPageState();
}

class _QrScannerPageState extends State<QrScannerPage> {
  final _controller = MobileScannerController();
  bool _handled = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: Colors.black,
    appBar: AppBar(
      backgroundColor: Colors.black,
      foregroundColor: Colors.white,
      title: const Text('สแกน QR อุปกรณ์'),
      actions: [
        IconButton(
          onPressed: _controller.toggleTorch,
          icon: const Icon(Icons.flashlight_on_rounded),
        ),
      ],
    ),
    body: Stack(
      fit: StackFit.expand,
      children: [
        MobileScanner(
          controller: _controller,
          onDetect: (capture) {
            if (_handled || capture.barcodes.isEmpty) {
              return;
            }
            final value = capture.barcodes.first.rawValue;
            if (value == null || value.isEmpty) {
              return;
            }
            _handled = true;
            Navigator.pop(context, value);
          },
        ),
        Center(
          child: Container(
            width: 250,
            height: 250,
            decoration: BoxDecoration(
              border: Border.all(color: Colors.white, width: 3),
              borderRadius: BorderRadius.circular(24),
            ),
          ),
        ),
        const Positioned(
          left: 24,
          right: 24,
          bottom: 50,
          child: Text(
            'วาง QR ให้อยู่ในกรอบ\nระบบจะเปิดหน้าอุปกรณ์ให้อัตโนมัติ',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    ),
  );
}
