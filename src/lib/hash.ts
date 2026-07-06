// PIN hashing — SHA-256 + pepper tetap, HARUS identik sama lib/services/db_service.dart
// (Flutter) biar hasil hash-nya bisa dibandingin lintas platform. Ini bukan penyimpanan
// password kelas berat (PIN 4-6 digit tetep gampang di-brute-force offline kalau
// database-nya bocor), tapi jauh lebih aman daripada nyimpen PIN mentahan/plain text.

const PIN_PEPPER = 'tapply-pin-pepper-v1';

export async function hashPin(pin: string): Promise<string> {
  const data = new TextEncoder().encode(pin + PIN_PEPPER);
  const hashBuffer = await crypto.subtle.digest('SHA-256', data);
  return Array.from(new Uint8Array(hashBuffer))
    .map((b) => b.toString(16).padStart(2, '0'))
    .join('');
}
