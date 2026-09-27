// ============================================================================
// Smart Asset - Supabase Configuration
// นำ URL และ Anon Key จากโปรเจกต์ Supabase ของคุณมาใส่ที่นี่
// Settings > API ใน Supabase Dashboard
// ============================================================================

const SUPABASE_URL = "https://etmxtzjouqljlaleizru.supabase.co";
const SUPABASE_ANON_KEY = "sb_publishable_h2fIjK5Dczhluy8MmY3v_g_0P5tSwZ1";

// ชื่อ Storage Bucket ที่ใช้เก็บรูปภาพ (ต้องตรงกับที่สร้างใน schema.sql)
const SUPABASE_STORAGE_BUCKET = "asset-images";

// ที่อยู่เว็บที่ใช้งานจริง (ใช้สร้างลิงก์ใน QR code บนการ์ดครุภัณฑ์ สแกนแล้วเปิดหน้าครุภัณฑ์ในระบบ)
// ถ้าเว้นว่างจะใช้ที่อยู่ของหน้าที่เปิดอยู่ขณะพิมพ์
const APP_BASE_URL = "https://nattaratdev.github.io/smart-asset-webapp/";
