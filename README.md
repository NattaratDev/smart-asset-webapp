# Smart Asset – ระบบบันทึกข้อมูลสินทรัพย์

เว็บแอปบันทึก/จัดการข้อมูลครุภัณฑ์และวัสดุของหน่วยงาน (SPA หน้าเดียว) ใช้ **Supabase** เป็นฐานข้อมูลและ Storage ทำ Custom Login ของตัวเอง (ไม่พึ่งพา Supabase Auth) เหมาะสำหรับสอนหลักการ CRUD + Role-based Access Control

## โครงสร้างไฟล์

```
index.html   หน้าเว็บทั้งหมด (HTML + CSS + JS รวมไฟล์เดียว)
config.js    เก็บค่า SUPABASE_URL / SUPABASE_ANON_KEY (แก้ตรงนี้ที่เดียว)
schema.sql   สคริปต์สร้างตาราง + RLS + Storage + ข้อมูลตัวอย่าง (รันทีเดียวจบใน Supabase SQL Editor)
```

## ขั้นตอนติดตั้ง

1. สร้างโปรเจกต์ใหม่ที่ [supabase.com](https://supabase.com)
2. เปิด **SQL Editor** → วางเนื้อหาทั้งหมดในไฟล์ [`schema.sql`](schema.sql) แล้วกด Run (รันครั้งเดียวจบ สร้างตาราง, เปิด RLS, สร้าง Storage bucket และใส่ข้อมูลตัวอย่างให้ทันที)
3. ไปที่ **Settings → API** คัดลอกค่า `Project URL` และ `anon public key`
4. แก้ไฟล์ [`config.js`](config.js) ใส่ค่าทั้งสองแทนที่ `YOUR-PROJECT-REF` และ `YOUR-ANON-PUBLIC-KEY`
5. เปิด `index.html` ผ่านเว็บเซิร์ฟเวอร์ (ห้ามเปิดแบบ `file://` ตรง ๆ เพราะฟังก์ชันเข้ารหัสรหัสผ่าน (Web Crypto API) ต้องการ secure context) เช่น
   - ใช้ VS Code extension **Live Server**
   - หรือรัน `npx http-server -p 8080` แล้วเปิด `http://localhost:8080`
   - หรือ deploy ขึ้น **GitHub Pages** (ดูด้านล่าง)

## Deploy ด้วย GitHub Pages

```bash
git init
git add index.html config.js schema.sql README.md .gitignore
git commit -m "init: smart asset webapp"
git branch -M main
git remote add origin <URL ของ repo ที่สร้างบน GitHub>
git push -u origin main
```

จากนั้นไปที่ Settings → Pages ของ repo แล้วเลือก branch `main` / root — เว็บจะพร้อมใช้งานที่ `https://<username>.github.io/<repo>/`

## บัญชีทดสอบ (สร้างไว้ให้แล้วใน seed data)

| Username | Password    | สิทธิ์                |
|----------|-------------|------------------------|
| admin    | admin123    | ผู้ดูแลระบบ (Admin)    |
| staff    | staff123    | เจ้าหน้าที่พัสดุ       |
| employee | employee123 | พนักงานทั่วไป          |
| wichai   | wichai123   | พนักงานทั่วไป          |

## สิทธิ์การใช้งาน (Role)

- **Admin** – จัดการผู้ใช้งานทั้งหมด, CRUD ทุกตาราง, ดาวน์โหลดรายงาน (CSV)
- **เจ้าหน้าที่พัสดุ (staff)** – จัดการวัสดุ/ครุภัณฑ์, อนุมัติ/ไม่อนุมัติคำร้อง
- **Employee** – ดู/แก้ไขข้อมูลของตัวเอง, สร้างคำร้องเบิกวัสดุ/ยืมครุภัณฑ์/แจ้งซ่อม

## หมายเหตุด้านความปลอดภัย

RLS ของทุกตารางเปิดแบบ `USING (true)` เพื่อให้ทดสอบง่ายตามที่ระบุ (เหมาะกับการเรียนรู้/เดโม) **ไม่ควรใช้ค่านี้กับระบบที่มีข้อมูลจริงในโปรดักชัน** หากต้องนำไปใช้งานจริงควรปรับ Policy ให้ตรวจสอบสิทธิ์ผู้ใช้อย่างเข้มงวดกว่านี้
