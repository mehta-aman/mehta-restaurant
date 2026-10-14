# Mehta Restaurant Management System (MRMS)

A multi-platform restaurant management system built with **Flutter** (macOS, iOS, Android), backed by **Supabase** and an **offline-first local database (SQLite via Drift)**.

---

## 🏢 Restaurant Configuration
- **Name:** Mehta Restaurant
- **Tables:** 10 Tables (`T01` to `T10`) with 6-seat capacity
- **Layout:** Ground Floor / Main Hall
- **Roles:**
  - **Owner (Aman):** Full system access & credit account management
  - **Manager (Father):** Restaurant operations & credit account management
  - **Cashier:** Billing, multi-tender payment processing (UPI/Cash)
  - **Waiters (3):** Table-first ordering & KOT dispatch
  - **Kitchen Staff (2):** Live digital KOT queue

---

## 🗄️ Database Architecture
- **Migrations:** Located in [`supabase/migrations/001_initial_schema.sql`](supabase/migrations/001_initial_schema.sql)
- **Seed Data:** Located in [`supabase/seed/002_seed_mehta_restaurant.sql`](supabase/seed/002_seed_mehta_restaurant.sql)
  - Includes 10 tables, ~30 kitchen dishes, packaged items (Bikaji snacks, cold drinks), and transactional ledger data.

---

## 🚀 Getting Started

### 1. Prerequisites
- **Flutter SDK** (installed on macOS Apple Silicon M1)
- **Xcode** (for iOS and macOS desktop builds)
- **Android SDK / Studio** (for Android APK generation)

### 2. Environment Configuration
Copy `.env.example` to `.env` and fill in your Supabase credentials:
```bash
cp .env.example .env
```

```env
SUPABASE_URL=https://your-project.supabase.co
SUPABASE_ANON_KEY=your-anon-key-here
```

### 3. Running the App
- **macOS Desktop:**
  ```bash
  flutter run -d macos
  ```
- **Android Device:**
  ```bash
  flutter run -d <android-device-id>
  ```
- **iOS Device / Simulator:**
  ```bash
  flutter run -d <ios-device-id>
  ```
