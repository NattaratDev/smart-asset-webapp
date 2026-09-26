-- ============================================================================
-- Smart Asset - ระบบบันทึกข้อมูลสินทรัพย์
-- สคริปต์ SQL สำหรับรันใน Supabase SQL Editor (รันทีเดียวจบ)
-- ประกอบด้วย: ตารางข้อมูล, RLS + Policies (เปิดกว้างเพื่อทดสอบ), Storage Bucket + Policies,
-- และข้อมูลตัวอย่าง (Seed Data)
-- ============================================================================

-- ----------------------------------------------------------------------------
-- 0) EXTENSIONS
-- ----------------------------------------------------------------------------
create extension if not exists pgcrypto;

-- ----------------------------------------------------------------------------
-- 1) DROP (ถ้ามีของเดิม) - ลบตามลำดับ dependency
-- ----------------------------------------------------------------------------
drop table if exists public.app_settings cascade;
drop table if exists public.asset_loans cascade;
drop table if exists public.asset_repairs cascade;
drop table if exists public.material_stock_transactions cascade;
drop table if exists public.material_issue_items cascade;
drop table if exists public.material_issue_requests cascade;
drop table if exists public.requests cascade;
drop table if exists public.fixed_assets cascade;
drop table if exists public.asset_receipts cascade;
drop table if exists public.materials cascade;
drop table if exists public.users cascade;

-- ----------------------------------------------------------------------------
-- 2) TABLE: users  (ระบบผู้ใช้งาน - Custom Login ไม่พึ่งพา Supabase Auth)
-- ----------------------------------------------------------------------------
create table public.users (
  id              uuid primary key default gen_random_uuid(),
  employee_code   text unique,
  full_name       text not null,
  username        text not null unique,
  password_hash   text not null,
  role            text not null default 'employee' check (role in ('admin','staff','employee')),
  department      text,
  position        text,
  phone           text,
  email           text,
  avatar_url      text,
  is_active       boolean not null default true,
  created_at      timestamptz not null default now(),
  updated_at      timestamptz not null default now()
);

comment on table public.users is 'ผู้ใช้งานระบบ: admin=ผู้ดูแลระบบ, staff=เจ้าหน้าที่พัสดุ, employee=พนักงานทั่วไป';

-- ----------------------------------------------------------------------------
-- 3) TABLE: materials (วัสดุ)
-- ----------------------------------------------------------------------------
create table public.materials (
  id              uuid primary key default gen_random_uuid(),
  item_code       text unique,
  name            text not null,
  category        text,
  unit            text default 'ชิ้น',
  quantity        numeric not null default 0,
  min_quantity    numeric not null default 0,
  image_url       text,
  description     text,
  is_active       boolean not null default true,
  created_by      uuid references public.users(id) on delete set null,
  created_at      timestamptz not null default now(),
  updated_at      timestamptz not null default now()
);

comment on column public.materials.category is 'หมวดหมู่ตามระเบียบพัสดุ: วัสดุสำนักงาน, วัสดุไฟฟ้าและวิทยุ, วัสดุงานบ้านงานครัว, วัสดุก่อสร้าง, วัสดุยานพาหนะและขนส่ง, วัสดุเชื้อเพลิงและหล่อลื่น, วัสดุการเกษตร, วัสดุวิทยาศาสตร์หรือการแพทย์, วัสดุโฆษณาและเผยแพร่';

-- ----------------------------------------------------------------------------
-- 4) TABLE: fixed_assets (ครุภัณฑ์)
-- ----------------------------------------------------------------------------
create table public.asset_receipts (
  id            uuid primary key default gen_random_uuid(),
  receipt_code  text unique not null,
  receive_date  date not null default current_date,
  supplier      text,
  doc_ref       text,
  note          text,
  received_by   uuid references public.users(id) on delete set null,
  created_at    timestamptz not null default now()
);

create table public.fixed_assets (
  id                  uuid primary key default gen_random_uuid(),
  asset_code          text unique,
  name                text not null,
  category            text,
  brand_model         text,
  serial_number       text,
  purchase_date       date,
  purchase_price      numeric,
  status              text not null default 'ใช้งานปกติ' check (status in ('ใช้งานปกติ','ชำรุด','ซ่อมบำรุง','จำหน่ายแล้ว')),
  location            text,
  responsible_user_id uuid references public.users(id) on delete set null,
  image_url           text,
  description         text,
  receipt_id          uuid references public.asset_receipts(id) on delete set null,
  created_by          uuid references public.users(id) on delete set null,
  created_at          timestamptz not null default now(),
  updated_at          timestamptz not null default now()
);

-- ----------------------------------------------------------------------------
-- 5) TABLE: requests (คำร้อง ยืมครุภัณฑ์/แจ้งซ่อม - เบิกวัสดุแยกไปที่ material_issue_requests แล้ว)
-- ----------------------------------------------------------------------------
comment on column public.fixed_assets.category is 'ประเภทครุภัณฑ์ 14 ประเภท: ครุภัณฑ์สำนักงาน, ยานพาหนะและขนส่ง, ไฟฟ้าและวิทยุ, โฆษณาและเผยแพร่, การเกษตร, โรงงาน, ก่อสร้าง, สำรวจ, วิทยาศาสตร์, คอมพิวเตอร์, การศึกษา, งานบ้านงานครัว, สนาม, อื่น';

create table public.requests (
  id              uuid primary key default gen_random_uuid(),
  request_code    text unique,
  requester_id    uuid not null references public.users(id) on delete cascade,
  request_type    text not null check (request_type in ('ยืมครุภัณฑ์','แจ้งซ่อม','อื่นๆ')),
  fixed_asset_id  uuid references public.fixed_assets(id) on delete set null,
  quantity        numeric default 1,
  reason          text,
  status          text not null default 'รออนุมัติ' check (status in ('รออนุมัติ','อนุมัติ','ไม่อนุมัติ','เสร็จสิ้น')),
  approved_by     uuid references public.users(id) on delete set null,
  approved_at     timestamptz,
  approver_note   text,
  created_at      timestamptz not null default now(),
  updated_at      timestamptz not null default now()
);

-- ----------------------------------------------------------------------------
-- 5b) TABLE: material_issue_requests / material_issue_items (ใบเบิกวัสดุ - เบิกได้หลายรายการต่อ 1 ใบเบิก)
-- ----------------------------------------------------------------------------
create table public.material_issue_requests (
  id              uuid primary key default gen_random_uuid(),
  issue_code      text unique not null,
  requester_id    uuid not null references public.users(id) on delete cascade,
  reason          text,
  status          text not null default 'รออนุมัติ' check (status in ('รออนุมัติ','อนุมัติ','ไม่อนุมัติ','เสร็จสิ้น')),
  approved_by     uuid references public.users(id) on delete set null,
  approved_at     timestamptz,
  approver_note   text,
  created_at      timestamptz not null default now(),
  updated_at      timestamptz not null default now()
);

create table public.material_issue_items (
  id                uuid primary key default gen_random_uuid(),
  issue_request_id  uuid not null references public.material_issue_requests(id) on delete cascade,
  material_id       uuid not null references public.materials(id) on delete restrict,
  quantity          numeric not null check (quantity > 0),
  approved_quantity numeric check (approved_quantity is null or approved_quantity >= 0),
  created_at        timestamptz not null default now()
);

-- ----------------------------------------------------------------------------
-- 5c) TABLE: material_stock_transactions (ประวัติรับเข้า/เบิกออกวัสดุ - ใช้ทำ Stock Card)
-- ----------------------------------------------------------------------------
create table public.material_stock_transactions (
  id                    uuid primary key default gen_random_uuid(),
  material_id           uuid not null references public.materials(id) on delete cascade,
  type                  text not null check (type in ('รับเข้า','เบิกออก','ปรับปรุง')),
  quantity              numeric not null check (quantity > 0),
  note                  text,
  reference_request_id  uuid references public.requests(id) on delete set null,
  reference_issue_id    uuid references public.material_issue_requests(id) on delete set null,
  performed_by          uuid references public.users(id) on delete set null,
  created_at            timestamptz not null default now()
);

-- ----------------------------------------------------------------------------
-- 5e) TABLE: asset_repairs (ซ่อมบำรุงครุภัณฑ์) / asset_loans (ยืม-คืนครุภัณฑ์)
-- ----------------------------------------------------------------------------
create table public.asset_repairs (
  id            uuid primary key default gen_random_uuid(),
  repair_code   text unique not null,
  asset_id      uuid not null references public.fixed_assets(id) on delete cascade,
  reported_by   uuid not null references public.users(id) on delete cascade,
  problem       text not null,
  status        text not null default 'แจ้งซ่อม' check (status in ('แจ้งซ่อม','กำลังซ่อม','ซ่อมเสร็จ','ซ่อมไม่ได้','ยกเลิก')),
  vendor        text,
  started_at    timestamptz,
  completed_at  timestamptz,
  cost          numeric check (cost is null or cost >= 0),
  result_note   text,
  handled_by    uuid references public.users(id) on delete set null,
  created_at    timestamptz not null default now(),
  updated_at    timestamptz not null default now()
);

create table public.asset_loans (
  id               uuid primary key default gen_random_uuid(),
  loan_code        text unique not null,
  asset_id         uuid not null references public.fixed_assets(id) on delete cascade,
  borrower_id      uuid not null references public.users(id) on delete cascade,
  due_date         date not null,
  purpose          text,
  status           text not null default 'รออนุมัติ' check (status in ('รออนุมัติ','ยืมอยู่','คืนแล้ว','ไม่อนุมัติ','ยกเลิก')),
  approved_by      uuid references public.users(id) on delete set null,
  approved_at      timestamptz,
  returned_at      timestamptz,
  return_condition text,
  return_note      text,
  received_by      uuid references public.users(id) on delete set null,
  created_at       timestamptz not null default now(),
  updated_at       timestamptz not null default now()
);

-- ----------------------------------------------------------------------------
-- 5d) TABLE: app_settings (ตั้งค่าระบบ เช่น ข้อมูลหน่วยงาน - key/value)
-- ----------------------------------------------------------------------------
create table public.app_settings (
  key         text primary key,
  value       text,
  updated_at  timestamptz not null default now()
);

-- ----------------------------------------------------------------------------
-- 6) INDEXES
-- ----------------------------------------------------------------------------
create index idx_materials_category on public.materials(category);
create index idx_fixed_assets_category on public.fixed_assets(category);
create index idx_fixed_assets_status on public.fixed_assets(status);
create index idx_requests_requester on public.requests(requester_id);
create index idx_requests_status on public.requests(status);
create index idx_issue_items_request on public.material_issue_items(issue_request_id);
create index idx_issue_requests_requester on public.material_issue_requests(requester_id);
create index idx_issue_requests_status on public.material_issue_requests(status);
create index idx_asset_repairs_asset on public.asset_repairs(asset_id);
create index idx_asset_loans_asset on public.asset_loans(asset_id);
create index idx_asset_loans_borrower on public.asset_loans(borrower_id);
create index idx_stock_tx_material on public.material_stock_transactions(material_id);

-- ----------------------------------------------------------------------------
-- 7) AUTO-UPDATE updated_at TRIGGER
-- ----------------------------------------------------------------------------
create or replace function public.set_updated_at()
returns trigger language plpgsql
set search_path = public
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

create trigger trg_users_updated_at before update on public.users
  for each row execute function public.set_updated_at();
create trigger trg_materials_updated_at before update on public.materials
  for each row execute function public.set_updated_at();
create trigger trg_fixed_assets_updated_at before update on public.fixed_assets
  for each row execute function public.set_updated_at();
create trigger trg_requests_updated_at before update on public.requests
  for each row execute function public.set_updated_at();
create trigger trg_issue_requests_updated_at before update on public.material_issue_requests
  for each row execute function public.set_updated_at();
create trigger trg_asset_repairs_updated_at before update on public.asset_repairs
  for each row execute function public.set_updated_at();
create trigger trg_asset_loans_updated_at before update on public.asset_loans
  for each row execute function public.set_updated_at();
create trigger trg_app_settings_updated_at before update on public.app_settings
  for each row execute function public.set_updated_at();

-- ----------------------------------------------------------------------------
-- 8) GRANTS - ให้สิทธิ์ anon/authenticated เข้าถึงตาราง (RLS ทำงานร่วมกับ GRANT เสมอ)
-- ----------------------------------------------------------------------------
grant usage on schema public to anon, authenticated;
grant all on public.users, public.materials, public.fixed_assets, public.requests, public.material_stock_transactions, public.material_issue_requests, public.material_issue_items, public.app_settings, public.asset_receipts, public.asset_repairs, public.asset_loans to anon, authenticated;
grant usage, select on all sequences in schema public to anon, authenticated;

-- ----------------------------------------------------------------------------
-- 9) ROW LEVEL SECURITY - เปิดใช้งานทุกตาราง + Policy แยก 4 ตัว (ทดสอบง่าย เปิดกว้าง USING(true))
-- ----------------------------------------------------------------------------
alter table public.users enable row level security;
alter table public.materials enable row level security;
alter table public.fixed_assets enable row level security;
alter table public.requests enable row level security;
alter table public.material_stock_transactions enable row level security;
alter table public.material_issue_requests enable row level security;
alter table public.material_issue_items enable row level security;
alter table public.app_settings enable row level security;
alter table public.asset_receipts enable row level security;
alter table public.asset_repairs enable row level security;
alter table public.asset_loans enable row level security;

-- users
create policy "users_select_all" on public.users for select using (true);
create policy "users_insert_all" on public.users for insert with check (true);
create policy "users_update_all" on public.users for update using (true) with check (true);
create policy "users_delete_all" on public.users for delete using (true);

-- materials
create policy "materials_select_all" on public.materials for select using (true);
create policy "materials_insert_all" on public.materials for insert with check (true);
create policy "materials_update_all" on public.materials for update using (true) with check (true);
create policy "materials_delete_all" on public.materials for delete using (true);

-- fixed_assets
create policy "fixed_assets_select_all" on public.fixed_assets for select using (true);
create policy "fixed_assets_insert_all" on public.fixed_assets for insert with check (true);
create policy "fixed_assets_update_all" on public.fixed_assets for update using (true) with check (true);
create policy "fixed_assets_delete_all" on public.fixed_assets for delete using (true);

-- requests
create policy "requests_select_all" on public.requests for select using (true);
create policy "requests_insert_all" on public.requests for insert with check (true);
create policy "requests_update_all" on public.requests for update using (true) with check (true);
create policy "requests_delete_all" on public.requests for delete using (true);

-- material_stock_transactions
create policy "stock_tx_select_all" on public.material_stock_transactions for select using (true);
create policy "stock_tx_insert_all" on public.material_stock_transactions for insert with check (true);
create policy "stock_tx_update_all" on public.material_stock_transactions for update using (true) with check (true);
create policy "stock_tx_delete_all" on public.material_stock_transactions for delete using (true);

-- material_issue_requests
create policy "issue_requests_select_all" on public.material_issue_requests for select using (true);
create policy "issue_requests_insert_all" on public.material_issue_requests for insert with check (true);
create policy "issue_requests_update_all" on public.material_issue_requests for update using (true) with check (true);
create policy "issue_requests_delete_all" on public.material_issue_requests for delete using (true);

-- material_issue_items
create policy "issue_items_select_all" on public.material_issue_items for select using (true);
create policy "issue_items_insert_all" on public.material_issue_items for insert with check (true);
create policy "issue_items_update_all" on public.material_issue_items for update using (true) with check (true);
create policy "issue_items_delete_all" on public.material_issue_items for delete using (true);

-- asset_receipts / asset_repairs / asset_loans
create policy "asset_receipts_select_all" on public.asset_receipts for select using (true);
create policy "asset_receipts_insert_all" on public.asset_receipts for insert with check (true);
create policy "asset_receipts_update_all" on public.asset_receipts for update using (true) with check (true);
create policy "asset_receipts_delete_all" on public.asset_receipts for delete using (true);
create policy "asset_repairs_select_all" on public.asset_repairs for select using (true);
create policy "asset_repairs_insert_all" on public.asset_repairs for insert with check (true);
create policy "asset_repairs_update_all" on public.asset_repairs for update using (true) with check (true);
create policy "asset_repairs_delete_all" on public.asset_repairs for delete using (true);
create policy "asset_loans_select_all" on public.asset_loans for select using (true);
create policy "asset_loans_insert_all" on public.asset_loans for insert with check (true);
create policy "asset_loans_update_all" on public.asset_loans for update using (true) with check (true);
create policy "asset_loans_delete_all" on public.asset_loans for delete using (true);

-- app_settings
create policy "app_settings_select_all" on public.app_settings for select using (true);
create policy "app_settings_insert_all" on public.app_settings for insert with check (true);
create policy "app_settings_update_all" on public.app_settings for update using (true) with check (true);
create policy "app_settings_delete_all" on public.app_settings for delete using (true);

-- ----------------------------------------------------------------------------
-- 10) STORAGE: Bucket สำหรับรูปภาพ (ครุภัณฑ์ / วัสดุ / รูปโปรไฟล์)
-- ----------------------------------------------------------------------------
insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values ('asset-images', 'asset-images', true, 5242880, array['image/png','image/jpeg','image/jpg','image/webp','image/gif'])
on conflict (id) do update set public = true;

-- ลบ policy เดิมของ bucket นี้ (ถ้ามี) กันชนกันตอนรันซ้ำ
drop policy if exists "asset_images_public_select" on storage.objects;
drop policy if exists "asset_images_public_insert" on storage.objects;
drop policy if exists "asset_images_public_update" on storage.objects;
drop policy if exists "asset_images_public_delete" on storage.objects;

create policy "asset_images_public_select" on storage.objects
  for select using (bucket_id = 'asset-images');

create policy "asset_images_public_insert" on storage.objects
  for insert with check (bucket_id = 'asset-images');

create policy "asset_images_public_update" on storage.objects
  for update using (bucket_id = 'asset-images') with check (bucket_id = 'asset-images');

create policy "asset_images_public_delete" on storage.objects
  for delete using (bucket_id = 'asset-images');

-- ----------------------------------------------------------------------------
-- 11) SEED DATA - ข้อมูลตัวอย่าง
--     รหัสผ่านทั้งหมดถูกเก็บเป็น SHA-256 hash (ฝั่ง frontend จะ hash ก่อนส่งมาเทียบ)
--     admin / admin123      -> เจ้าหน้าที่ดูแลระบบ
--     staff / staff123      -> เจ้าหน้าที่พัสดุ
--     employee / employee123 -> พนักงานทั่วไป
-- ----------------------------------------------------------------------------
insert into public.users (employee_code, full_name, username, password_hash, role, department, position, phone, email)
values
  ('EMP-001','ผู้ดูแลระบบ',        'admin',    encode(digest('admin123','sha256'),'hex'),    'admin',   'ฝ่ายเทคโนโลยีสารสนเทศ', 'ผู้ดูแลระบบ',        '080-000-0001','admin@smartasset.local'),
  ('EMP-002','สมชาย พัสดุดี',      'staff',    encode(digest('staff123','sha256'),'hex'),    'staff',   'ฝ่ายพัสดุ',              'เจ้าหน้าที่พัสดุ',    '080-000-0002','staff@smartasset.local'),
  ('EMP-003','สมหญิง ใจดี',        'employee', encode(digest('employee123','sha256'),'hex'), 'employee','ฝ่ายบุคคล',              'เจ้าหน้าที่ธุรการ',   '080-000-0003','employee@smartasset.local'),
  ('EMP-004','วิชัย ตั้งใจทำงาน',   'wichai',   encode(digest('wichai123','sha256'),'hex'),   'employee','ฝ่ายบัญชี',              'เจ้าหน้าที่บัญชี',    '080-000-0004','wichai@smartasset.local');

insert into public.materials (item_code, name, category, unit, quantity, min_quantity, description, created_by)
select 'MAT-001','กระดาษ A4 80 แกรม','วัสดุสำนักงาน','รีม',120,20,'กระดาษถ่ายเอกสาร A4 สีขาว', id from public.users where username='staff'
union all
select 'MAT-002','ปากกาลูกลื่นสีน้ำเงิน','วัสดุสำนักงาน','ด้าม',300,50,'ปากกาลูกลื่น 0.5mm', id from public.users where username='staff'
union all
select 'MAT-003','หมึกพิมพ์ HP 680','วัสดุสำนักงาน','ตลับ',15,5,'ตลับหมึกพิมพ์อิงค์เจ็ท', id from public.users where username='staff'
union all
select 'MAT-004','แฟ้มเอกสารสันกว้าง','วัสดุสำนักงาน','เล่ม',80,15,'แฟ้มเก็บเอกสาร 3 นิ้ว', id from public.users where username='staff'
union all
select 'MAT-005','น้ำยาทำความสะอาดโต๊ะ','วัสดุงานบ้านงานครัว','ขวด',10,10,'สเปรย์ทำความสะอาดพื้นผิว', id from public.users where username='staff';

insert into public.fixed_assets (asset_code, name, category, brand_model, serial_number, purchase_date, purchase_price, status, location, responsible_user_id, description, created_by)
select 'AST-001','คอมพิวเตอร์ตั้งโต๊ะ','ครุภัณฑ์คอมพิวเตอร์','Dell OptiPlex 3090','SN-DL30910001','2024-03-15'::date,24500::numeric,'ใช้งานปกติ','ห้องธุรการ ชั้น 2', u2.id,'เครื่องคอมพิวเตอร์สำหรับงานเอกสาร', u1.id
from public.users u1, public.users u2 where u1.username='staff' and u2.username='employee'
union all
select 'AST-002','เครื่องพิมพ์เลเซอร์','ครุภัณฑ์คอมพิวเตอร์','HP LaserJet Pro M404','SN-HP4040002','2023-11-02'::date,8900::numeric,'ใช้งานปกติ','ห้องพัสดุ', u2.id,'เครื่องพิมพ์ขาวดำความเร็วสูง', u1.id
from public.users u1, public.users u2 where u1.username='staff' and u2.username='staff'
union all
select 'AST-003','โน้ตบุ๊ก','ครุภัณฑ์คอมพิวเตอร์','Lenovo ThinkPad E14','SN-LNE140003','2024-06-20'::date,28900::numeric,'ซ่อมบำรุง','ฝ่ายบัญชี', u2.id,'โน้ตบุ๊กสำหรับงานนอกสถานที่', u1.id
from public.users u1, public.users u2 where u1.username='staff' and u2.username='wichai'
union all
select 'AST-004','โปรเจคเตอร์','ครุภัณฑ์โฆษณาและเผยแพร่','Epson EB-X06','SN-EPX060004','2022-08-10'::date,15900::numeric,'ใช้งานปกติ','ห้องประชุมใหญ่', null,'โปรเจคเตอร์สำหรับห้องประชุม', u1.id
from public.users u1 where u1.username='staff'
union all
select 'AST-005','เก้าอี้สำนักงาน','ครุภัณฑ์สำนักงาน','Ergotrend ERGO-01','SN-ERG010005','2021-05-05'::date,3200::numeric,'ชำรุด','ห้องธุรการ ชั้น 2', null,'เก้าอี้สำนักงานพนักพิงสูง', u1.id
from public.users u1 where u1.username='staff';

-- ข้อมูลหน่วยงานเริ่มต้น (แก้ไขได้ที่เมนู ตั้งค่าระบบ)
insert into public.app_settings (key, value) values
  ('org_name', 'ชื่อหน่วยงาน'),
  ('org_address', ''),
  ('org_phone', ''),
  ('org_logo_url', '');

-- ใบเบิกวัสดุตัวอย่าง (เบิกได้หลายรายการต่อ 1 ใบเบิก)
with seed_issue as (
  insert into public.material_issue_requests (issue_code, requester_id, reason, status)
  select 'WD-2569-0001', u.id, 'ใช้สำหรับพิมพ์เอกสารประจำเดือน', 'รออนุมัติ'
  from public.users u where u.username='employee'
  returning id
)
insert into public.material_issue_items (issue_request_id, material_id, quantity)
select seed_issue.id, m.id, 5 from seed_issue, public.materials m where m.item_code='MAT-001'
union all
select seed_issue.id, m.id, 10 from seed_issue, public.materials m where m.item_code='MAT-002';

-- งานซ่อมตัวอย่าง (โน้ตบุ๊ก AST-003 กำลังซ่อม)
insert into public.asset_repairs (repair_code, asset_id, reported_by, problem, status, vendor, handled_by, started_at)
select 'RP-2569-0001', a.id, u.id, 'เครื่องเปิดไม่ติด แบตเตอรี่เสื่อม', 'กำลังซ่อม', 'ศูนย์บริการ Lenovo', s.id, now()
from public.users u, public.fixed_assets a, public.users s
where u.username='wichai' and a.asset_code='AST-003' and s.username='staff';

-- ============================================================================
-- เสร็จสิ้น: รันสคริปต์นี้ใน Supabase SQL Editor ได้ทีเดียวจบ
-- ============================================================================
