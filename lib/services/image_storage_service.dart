import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';

/// อัปโหลดรูปด้วย Cloudinary unsigned upload preset
///
/// ค่า cloud name และ preset ส่งเข้ามาตอนรันด้วย --dart-define-from-file
/// จึงไม่ต้องฝัง API Secret ไว้ในแอป
class CloudinaryImageStorage {
  const CloudinaryImageStorage();

  static const cloudName = String.fromEnvironment('CLOUDINARY_CLOUD_NAME');
  static const uploadPreset = String.fromEnvironment(
    'CLOUDINARY_UPLOAD_PRESET',
  );

  bool get isConfigured => cloudName.isNotEmpty && uploadPreset.isNotEmpty;

  Future<String> upload(XFile image) async {
    if (!isConfigured) {
      throw Exception(
        'ยังไม่ได้ตั้งค่า Cloudinary กรุณาดูหัวข้อ “ตั้งค่าที่เก็บรูป” ใน README',
      );
    }

    final bytes = await image.readAsBytes();
    _validateSize(bytes);

    final request =
        http.MultipartRequest(
            'POST',
            Uri.parse(
              'https://api.cloudinary.com/v1_1/$cloudName/image/upload',
            ),
          )
          ..fields['upload_preset'] = uploadPreset
          ..fields['folder'] = 'hatyaiwit-borrow-sports/equipment'
          ..files.add(
            http.MultipartFile.fromBytes(
              'file',
              bytes,
              filename: image.name.isEmpty ? 'equipment.jpg' : image.name,
            ),
          );

    final streamedResponse = await request.send().timeout(
      const Duration(seconds: 45),
    );
    final response = await http.Response.fromStream(streamedResponse);
    final body = jsonDecode(response.body) as Map<String, dynamic>;
    if (response.statusCode < 200 || response.statusCode >= 300) {
      final message = (body['error'] as Map<String, dynamic>?)?['message'];
      throw Exception(message ?? 'อัปโหลดรูปไม่สำเร็จ');
    }

    final url = body['secure_url'] as String?;
    if (url == null || url.isEmpty) {
      throw Exception('Cloudinary ไม่ได้ส่ง URL รูปกลับมา');
    }
    return url;
  }

  void _validateSize(Uint8List bytes) {
    const maximumBytes = 5 * 1024 * 1024;
    if (bytes.length > maximumBytes) {
      throw Exception('รูปต้องมีขนาดไม่เกิน 5 MB');
    }
  }
}
