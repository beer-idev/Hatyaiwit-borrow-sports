const projectId = 'booking-sport-73f50';
const apiKey = 'AIzaSyDTElqSLize_OzBEt4SglHlOFsqG99ZpFg';
const studentEmail = '1234@hatyaiwit.ac.th';
const teacherEmail = '23456@hatyaiwit.ac.th';
const studentPassword = process.env.SEED_STUDENT_PASSWORD;
const teacherPassword = process.env.SEED_TEACHER_PASSWORD;

if (!studentPassword || !teacherPassword) {
  throw new Error('Set SEED_STUDENT_PASSWORD and SEED_TEACHER_PASSWORD first.');
}

async function jsonRequest(url, options = {}) {
  const response = await fetch(url, options);
  const body = await response.json().catch(() => ({}));
  if (!response.ok) {
    const message = body?.error?.message ?? JSON.stringify(body);
    const error = new Error(message);
    error.status = response.status;
    throw error;
  }
  return body;
}

async function signInOrCreate(email, password) {
  const payload = JSON.stringify({email, password, returnSecureToken: true});
  const headers = {'Content-Type': 'application/json'};
  try {
    return await jsonRequest(
      `https://identitytoolkit.googleapis.com/v1/accounts:signUp?key=${apiKey}`,
      {method: 'POST', headers, body: payload},
    );
  } catch (error) {
    if (!String(error.message).includes('EMAIL_EXISTS')) throw error;
    return jsonRequest(
      `https://identitytoolkit.googleapis.com/v1/accounts:signInWithPassword?key=${apiKey}`,
      {method: 'POST', headers, body: payload},
    );
  }
}

const stringValue = (value) => ({stringValue: value});
const booleanValue = (value) => ({booleanValue: value});
const timestampValue = (value) => ({timestampValue: value.toISOString()});

const firestoreBase =
  `https://firestore.googleapis.com/v1/projects/${projectId}/databases/(default)/documents`;

function authHeaders(token) {
  return {
    Authorization: `Bearer ${token}`,
    'Content-Type': 'application/json',
  };
}

async function getDocument(collection, id, token) {
  const response = await fetch(`${firestoreBase}/${collection}/${id}`, {
    headers: authHeaders(token),
  });
  if (response.status === 404) return null;
  const body = await response.json().catch(() => ({}));
  if (!response.ok) throw new Error(body?.error?.message ?? JSON.stringify(body));
  return body;
}

async function setDocument(collection, id, fields, token) {
  return jsonRequest(`${firestoreBase}/${collection}/${id}`, {
    method: 'PATCH',
    headers: authHeaders(token),
    body: JSON.stringify({fields}),
  });
}

async function updateDocument(collection, id, fields, fieldPaths, token) {
  const query = fieldPaths
    .map((field) => `updateMask.fieldPaths=${encodeURIComponent(field)}`)
    .join('&');
  return jsonRequest(`${firestoreBase}/${collection}/${id}?${query}`, {
    method: 'PATCH',
    headers: authHeaders(token),
    body: JSON.stringify({fields}),
  });
}

async function createBookingIfMissing(id, fields, token) {
  const documentName =
    `projects/${projectId}/databases/(default)/documents/bookings/${id}`;
  try {
    await jsonRequest(
      `https://firestore.googleapis.com/v1/projects/${projectId}/databases/(default)/documents:commit`,
      {
        method: 'POST',
        headers: authHeaders(token),
        body: JSON.stringify({
          writes: [{
            update: {name: documentName, fields},
            currentDocument: {exists: false},
            updateTransforms: [{
              fieldPath: 'createdAt',
              setToServerValue: 'REQUEST_TIME',
            }],
          }],
        }),
      },
    );
    return 'pending';
  } catch (error) {
    if (error.status !== 409 && !String(error.message).includes('ALREADY_EXISTS')) {
      throw error;
    }
    const existing = await getDocument('bookings', id, token);
    return existing.fields.status.stringValue;
  }
}

async function updateBookingStatus({bookingId, equipmentId, status, token}) {
  const root = `projects/${projectId}/databases/(default)/documents`;
  await jsonRequest(
    `https://firestore.googleapis.com/v1/projects/${projectId}/databases/(default)/documents:commit`,
    {
      method: 'POST',
      headers: authHeaders(token),
      body: JSON.stringify({
        writes: [
          {
            update: {
              name: `${root}/bookings/${bookingId}`,
              fields: {status: stringValue(status)},
            },
            updateMask: {fieldPaths: ['status']},
            updateTransforms: [{
              fieldPath: 'updatedAt',
              setToServerValue: 'REQUEST_TIME',
            }],
          },
          {
            update: {
              name: `${root}/equipment/${equipmentId}`,
              fields: {available: booleanValue(status !== 'approved')},
            },
            updateMask: {fieldPaths: ['available']},
          },
        ],
      }),
    },
  );
}

const student = await signInOrCreate(studentEmail, studentPassword);
const teacher = await signInOrCreate(teacherEmail, teacherPassword);

await setDocument('users', student.localId, {
  email: stringValue(studentEmail),
  name: stringValue('นักเรียน 1234'),
  schoolId: stringValue('1234'),
  role: stringValue('student'),
}, student.idToken);

await setDocument('users', teacher.localId, {
  email: stringValue(teacherEmail),
  name: stringValue('ครู 23456'),
  schoolId: stringValue('23456'),
  role: stringValue('teacher'),
}, teacher.idToken);

const equipment = [
  ['seed-basketball', 'SP-001', 'ลูกบาสเกตบอล', 'บาสเกตบอล', true, 'ลูกบาส เบอร์ 7 พร้อมใช้งานในโรงยิม'],
  ['seed-football', 'SP-002', 'ลูกฟุตบอล', 'ฟุตบอล', true, 'ฟุตบอลเบอร์ 5 สำหรับสนามหญ้า'],
  ['seed-volleyball', 'SP-003', 'ลูกวอลเลย์บอล', 'วอลเลย์บอล', true, 'ลูกวอลเลย์บอลมาตรฐาน'],
  ['seed-badminton', 'SP-004', 'ชุดไม้แบดมินตัน', 'แบดมินตัน', true, 'ไม้แบด 2 อัน พร้อมลูกขนไก่'],
  ['seed-cones', 'SP-005', 'กรวยซ้อมกีฬา 10 ชิ้น', 'อุปกรณ์ฝึกซ้อม', true, 'กรวยสีส้มสำหรับจัดฐานฝึกซ้อม'],
];

for (const [id, code, name, category, available, note] of equipment) {
  await setDocument('equipment', id, {
    code: stringValue(code),
    name: stringValue(name),
    category: stringValue(category),
    ownerId: stringValue(teacher.localId),
    ownerName: stringValue('ครู 23456'),
    available: booleanValue(available),
    note: stringValue(note),
    updatedAt: timestampValue(new Date()),
  }, teacher.idToken);
}

const now = Date.now();
const commonBooking = {
  ownerId: stringValue(teacher.localId),
  ownerName: stringValue('ครู 23456'),
  borrowerId: stringValue(student.localId),
  borrowerName: stringValue('นักเรียน 1234'),
  borrowerSchoolId: stringValue('1234'),
};

let activeStatus = await createBookingIfMissing('seed-active-loan', {
  ...commonBooking,
  equipmentId: stringValue('seed-basketball'),
  equipmentName: stringValue('ลูกบาสเกตบอล'),
  equipmentCode: stringValue('SP-001'),
  startAt: timestampValue(new Date(now - 60 * 60 * 1000)),
  endAt: timestampValue(new Date(now + 24 * 60 * 60 * 1000)),
  status: stringValue('pending'),
  purpose: stringValue('ใช้ฝึกซ้อมบาสเกตบอลหลังเลิกเรียน'),
}, student.idToken);

if (activeStatus === 'pending') {
  await updateBookingStatus({
    bookingId: 'seed-active-loan',
    equipmentId: 'seed-basketball',
    status: 'approved',
    token: teacher.idToken,
  });
  activeStatus = 'approved';
}

let returnedStatus = await createBookingIfMissing('seed-returned-loan', {
  ...commonBooking,
  equipmentId: stringValue('seed-football'),
  equipmentName: stringValue('ลูกฟุตบอล'),
  equipmentCode: stringValue('SP-002'),
  startAt: timestampValue(new Date(now - 4 * 24 * 60 * 60 * 1000)),
  endAt: timestampValue(new Date(now - 3 * 24 * 60 * 60 * 1000)),
  status: stringValue('pending'),
  purpose: stringValue('ใช้แข่งขันฟุตบอลภายในโรงเรียน'),
}, student.idToken);

if (returnedStatus === 'pending') {
  await updateBookingStatus({
    bookingId: 'seed-returned-loan',
    equipmentId: 'seed-football',
    status: 'approved',
    token: teacher.idToken,
  });
  returnedStatus = 'approved';
}
if (returnedStatus === 'approved') {
  await updateBookingStatus({
    bookingId: 'seed-returned-loan',
    equipmentId: 'seed-football',
    status: 'returned',
    token: teacher.idToken,
  });
  returnedStatus = 'returned';
}

// Keep seeded equipment consistent when this script is run more than once.
await updateDocument(
  'equipment',
  'seed-basketball',
  {available: booleanValue(activeStatus !== 'approved')},
  ['available'],
  teacher.idToken,
);
await updateDocument(
  'equipment',
  'seed-football',
  {available: booleanValue(true)},
  ['available'],
  teacher.idToken,
);

console.log(JSON.stringify({
  users: [studentEmail, teacherEmail],
  equipment: equipment.length,
  bookings: {
    active: activeStatus,
    returned: returnedStatus,
  },
}, null, 2));
