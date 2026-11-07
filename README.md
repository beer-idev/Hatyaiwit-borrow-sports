# Hatyaiwit Borrow Sports

แอป Flutter + Firebase สำหรับจอง ยืม และคืนอุปกรณ์กีฬาในโรงเรียนหาดใหญ่วิทยาลัย รองรับทั้งนักเรียนและครูในฐานะผู้ยืมหรือเจ้าของอุปกรณ์

## Firebase ที่เชื่อมไว้แล้ว

- Project ID: `booking-sport-73f50`
- Firestore: `(default)` ที่ `asia-southeast3`
- Authentication: Email/Password เปิดใช้งานแล้ว
- Platforms: Android, iOS และ Web
- Android package: `th.ac.hatyaiwit.gearshare_school`
- iOS bundle ID: `th.ac.hatyaiwit.gearshareSchool`
- Firestore Rules ถูก deploy แล้ว

ค่าของแต่ละแพลตฟอร์มอยู่ใน `lib/firebase_options.dart` และ Android config อยู่ใน `android/app/google-services.json`

## รันแอป

```powershell
flutter pub get
flutter run
```

แอปเชื่อม Firebase จริงโดยอัตโนมัติ ไม่ต้องส่ง `--dart-define` เพิ่ม

## ตั้งค่าที่เก็บรูปอุปกรณ์ (Cloudinary Free)

รูปอุปกรณ์เก็บบน Cloudinary และบันทึกเฉพาะ URL ของรูปไว้ใน Cloud Firestore วิธีนี้ไม่ใช้ Firebase Storage และเหมาะสำหรับทดสอบด้วยรูปจำนวนไม่มาก

1. สมัครบัญชี Cloudinary แบบ Free ที่ <https://cloudinary.com/users/register_free>
2. คัดลอกค่า **Cloud name** จากหน้า Dashboard
3. ไปที่ **Settings → Upload → Upload presets** แล้วสร้าง preset แบบ **Unsigned**
4. คัดลอก `cloudinary.example.json` เป็น `cloudinary.json` และใส่ค่าจริง เช่น

```json
{
  "CLOUDINARY_CLOUD_NAME": "ชื่อ-cloud-ของคุณ",
  "CLOUDINARY_UPLOAD_PRESET": "ชื่อ-unsigned-preset"
}
```

5. รันแอปด้วยคำสั่ง

```powershell
flutter run --dart-define-from-file=cloudinary.json
```

เมื่อต้องการสร้าง APK ให้ใช้

```powershell
flutter build apk --release --dart-define-from-file=cloudinary.json
```

ไฟล์ `cloudinary.json` ถูกเพิ่มใน `.gitignore` แล้ว และไม่ควรใส่ Cloudinary API Secret ไว้ในแอป การอัปโหลดแบบ Unsigned เหมาะกับการทดลอง หากนำไปใช้งานจริงควรจำกัดชนิดไฟล์ ขนาดไฟล์ และโฟลเดอร์ใน Upload preset หรือเปลี่ยนเป็น Signed upload ผ่าน Backend

## โครงสร้างไฟล์ภายใน `lib`

โฟลเดอร์ `lib` เป็นที่เก็บซอร์สโค้ด Dart หลักของแอป โดยแบ่งหน้าที่ของโค้ดออกเป็นส่วน ๆ เพื่อให้อ่าน แก้ไข และทดสอบได้ง่าย

```text
lib/
├── models/
│   └── app_models.dart
├── screens/
│   ├── auth_screen.dart
│   └── home_screen.dart
├── services/
│   ├── app_repository.dart
│   ├── demo_repository.dart
│   └── image_storage_service.dart
├── theme/
│   └── app_theme.dart
├── firebase_options.dart
└── main.dart
```

### `lib/main.dart`

ไฟล์เริ่มต้นของแอป ทำหน้าที่ดังนี้

- เรียก `runApp()` เพื่อเปิดแอปพลิเคชัน
- เตรียมรูปแบบวันที่ภาษาไทย
- เชื่อมต่อ Firebase ด้วยค่าจาก `firebase_options.dart`
- แสดงหน้าโหลดระหว่างเริ่มระบบ และหน้าแจ้งข้อผิดพลาดเมื่อเชื่อมต่อไม่สำเร็จ
- ตรวจสอบสถานะการเข้าสู่ระบบ ถ้ายังไม่ได้เข้าสู่ระบบจะแสดง `AuthScreen` และถ้าเข้าสู่ระบบแล้วจะแสดง `HomeScreen`

### `lib/firebase_options.dart`

เก็บค่าเชื่อมต่อ Firebase ของแต่ละแพลตฟอร์ม เช่น Android, iOS และ Web ไฟล์นี้ถูกสร้างจาก FlutterFire CLI และถูกเรียกใช้จาก `main.dart`

> ไม่ควรแก้ไขค่าภายในไฟล์นี้เองโดยไม่จำเป็น หากเปลี่ยน Firebase Project ควรรัน FlutterFire CLI เพื่อสร้างค่าใหม่

### `lib/models/`

เก็บโครงสร้างข้อมูลที่ใช้ร่วมกันทั้งแอป

- `app_models.dart` กำหนดโมเดล `AppUser`, `Equipment` และ `Booking`
- กำหนดประเภทผู้ใช้ `student` และ `teacher`
- กำหนดสถานะการยืม `pending`, `approved`, `rejected` และ `returned`
- แปลงข้อมูลระหว่าง Dart Object กับข้อมูลแบบ Map ที่ใช้ใน Cloud Firestore
- ตรวจสอบลำดับการเปลี่ยนสถานะของรายการยืม

### `lib/screens/`

เก็บหน้าจอและ Widget ที่ผู้ใช้มองเห็นและโต้ตอบด้วย

- `auth_screen.dart` เป็นหน้าสมัครสมาชิกและเข้าสู่ระบบ ตรวจสอบข้อมูลผู้ใช้และจำกัดอีเมลไว้ที่ `@hatyaiwit.ac.th`
- `home_screen.dart` เป็นหน้าหลักของแอป รวมรายการอุปกรณ์ การค้นหาและกรอง การสแกน QR Code การส่งคำขอยืม การอนุมัติ/ปฏิเสธ การยืนยันคืน หน้าอุปกรณ์ของฉัน และหน้าโปรไฟล์

ปัจจุบัน `home_screen.dart` รวม Widget ย่อยหลายส่วนไว้ในไฟล์เดียว เช่น `EquipmentCatalog`, `EquipmentCard`, `BookingList`, `BookingCard`, `MyEquipmentPage` และ `QrScannerPage`

### `lib/services/`

เป็นชั้นกลางระหว่างหน้าจอกับแหล่งข้อมูล หน้าจอจึงไม่ต้องเรียก Firebase โดยตรง

- `app_repository.dart` ประกาศ `AppRepository` ซึ่งเป็นชุดคำสั่งที่แอปต้องใช้ เช่น เข้าสู่ระบบ สมัครสมาชิก ดูอุปกรณ์ เพิ่มอุปกรณ์ สร้างคำขอยืม และเปลี่ยนสถานะรายการ พร้อมมี `FirebaseAppRepository` สำหรับเชื่อม Firebase Authentication และ Cloud Firestore จริง
- `demo_repository.dart` เป็นแหล่งข้อมูลจำลองในหน่วยความจำ ใช้สำหรับทดสอบการทำงานของแอปโดยไม่แก้ไขข้อมูลบน Firebase จริง เมื่อปิดหรือเริ่มแอปใหม่ข้อมูลจำลองจะไม่ถูกเก็บถาวร
- `image_storage_service.dart` อัปโหลดรูปอุปกรณ์ไปยัง Cloudinary ด้วย Unsigned upload preset และส่ง URL กลับมาเก็บกับข้อมูลอุปกรณ์

### `lib/theme/`

เก็บรูปแบบหน้าตาของแอปไว้ส่วนกลาง

- `app_theme.dart` กำหนดสีหลัก พื้นหลัง รูปแบบช่องกรอกข้อมูล การ์ด ปุ่ม และแถบนำทางของแอป
- หากต้องการเปลี่ยนโทนสีหรือรูปแบบส่วนประกอบทั้งแอป ควรแก้จากไฟล์นี้

### ลำดับการทำงานของโค้ด

```text
main.dart
   │
   ├── เริ่ม Firebase และตรวจสอบผู้ใช้
   │
   ├── screens/ รับข้อมูลหรือเหตุการณ์จากผู้ใช้
   │
   ├── services/ ตรวจสอบและอ่าน–เขียนข้อมูล
   │
   └── models/ ใช้กำหนดรูปแบบข้อมูลที่ส่งระหว่างหน้าจอกับ Firebase
```

`theme/` ถูกใช้ร่วมกับทุกหน้าจอ ส่วน `firebase_options.dart` ถูกใช้เฉพาะตอนเริ่มเชื่อมต่อ Firebase

## Deploy Firestore Rules อีกครั้ง

```powershell
firebase.cmd deploy --only firestore:rules
```

## สร้างข้อมูลตัวอย่างซ้ำ

สคริปต์จะสร้างบัญชีนักเรียน/ครู อุปกรณ์ 5 รายการ รายการกำลังยืม 1 รายการ และรายการคืนแล้ว 1 รายการ โดยไม่เก็บรหัสผ่านไว้ในไฟล์:

```powershell
$env:SEED_STUDENT_PASSWORD='รหัสผ่านนักเรียน'
$env:SEED_TEACHER_PASSWORD='รหัสผ่านครู'
node tool\seed_firebase.mjs
```

## Build

```powershell
flutter build apk --release
flutter build web --release
```

การ build Android ให้ใช้ JDK 17 หรือ 21; JDK 25 ยังไม่รองรับกับ Gradle/Kotlin ชุดนี้

## เว็บ, QR และ Android App Link

เว็บและแอปใช้ source code, Firebase Authentication, Cloud Firestore และข้อมูลอุปกรณ์ชุดเดียวกัน จึงไม่ต้องสร้างฐานข้อมูลแยก การสแกน QR ทำงานข้ามกันได้ทั้งแอปไปเว็บ เว็บไปแอป เว็บไปเว็บ และแอปไปแอป

QR อุปกรณ์ใหม่จะเก็บลิงก์รูปแบบนี้:

```text
https://hatyaiwit-borrow.vercel.app/equipment/<equipmentId>
```

- Android ที่ติดตั้งแอปและยืนยัน App Link สำเร็จจะเปิดรายละเอียดในแอป
- Android ที่ไม่มีแอป และ iPhone จะเปิดเว็บ
- QR แบบเก่าที่เก็บเฉพาะรหัสอุปกรณ์ยังสแกนในระบบได้
- กล้องบนเว็บต้องเปิดผ่าน HTTPS หรือ `localhost` และผู้ใช้ต้องอนุญาตสิทธิ์กล้อง

เว็บ production deploy ผ่าน Vercel ที่ `https://hatyaiwit-borrow.vercel.app` โดยใช้ `vercel.json` rewrite route `/equipment/:id` กลับเข้า Flutter Web:

```powershell
flutter build web --release `
  --dart-define=APP_WEB_ORIGIN=https://hatyaiwit-borrow.vercel.app `
  --dart-define-from-file=cloudinary.json
```

ไฟล์ `web/.well-known/assetlinks.json` ผูกโดเมน Vercel กับ package `th.ac.hatyaiwit.gearshare_school` และคีย์ที่ใช้เซ็น APK ปัจจุบัน หากเปลี่ยน signing key หรือใช้ Google Play App Signing ต้องเพิ่ม SHA-256 fingerprint ของคีย์ใหม่ในไฟล์นี้แล้ว deploy เว็บอีกครั้ง

หากเปลี่ยนไปใช้ custom domain ให้แก้ host ใน `AndroidManifest.xml` และ build ด้วย:

```powershell
flutter build web --release --dart-define=APP_WEB_ORIGIN=https://โดเมนใหม่
flutter build apk --release --dart-define=APP_WEB_ORIGIN=https://โดเมนใหม่
```

## ฟีเจอร์

- สมัครสมาชิกและเข้าสู่ระบบด้วยอีเมล `@hatyaiwit.ac.th` เท่านั้น
- นักเรียนและครูสามารถเพิ่มอุปกรณ์ให้ผู้อื่นยืมได้
- เจ้าของสามารถเพิ่มรูปและแก้ไขชื่อ รหัส หมวดหมู่ รายละเอียด หรือรูปของอุปกรณ์ได้
- ค้นหาและกรองอุปกรณ์กีฬา
- สร้าง QR URL ประจำอุปกรณ์ และสแกนจากเว็บหรือแอปเพื่อเปิดหน้าจอง
- ระบุวัน–เวลารับของ วัน–เวลาคืน และวัตถุประสงค์
- เจ้าของอนุมัติหรือปฏิเสธคำขอ
- เจ้าของยืนยันเมื่อได้รับอุปกรณ์คืนแล้ว

## โครงสร้างข้อมูล Firestore

- `users/{uid}` — โปรไฟล์และประเภทผู้ใช้
- `equipment/{equipmentId}` — อุปกรณ์ เจ้าของ และสถานะพร้อมยืม
- `bookings/{bookingId}` — ผู้ยืม เจ้าของ เวลา และสถานะ `pending / approved / rejected / returned`

Security Rules บังคับให้ผู้ใช้งานเป็นบัญชีโรงเรียน จำกัดการอนุมัติและยืนยันคืนไว้ที่เจ้าของ และให้ผู้ยืมสร้างคำขอในชื่อของตัวเองเท่านั้น

> การตรวจโดเมนในแอปและ Firestore Rules ป้องกันบัญชีนอกโรงเรียนไม่ให้เข้าถึงข้อมูล แต่ Email/Password ของ Firebase Auth ไม่มีตัวเลือกจำกัดโดเมนในตัว หากต้องการป้องกันการสร้างบัญชี Auth ผ่าน REST API ภายนอกด้วย ต้องใช้ Authentication blocking function หรือ Google Sign-In ของโดเมนโรงเรียน
