# Mehta Restaurant Management System (MRMS)

A production-grade, multi-platform restaurant management system built with **Flutter** (Web, macOS, iOS, Android), backed 100% by **Supabase Cloud Database** and deployed continuously via **Google Firebase Hosting**.

---

## 🌐 Live Production Deployment

* **Live Web App:** [https://mehta-restaurant.web.app](https://mehta-restaurant.web.app)
* **Secondary Alias:** [https://mehta-restaurant.firebaseapp.com](https://mehta-restaurant.firebaseapp.com)
* **GitHub Repository:** [https://github.com/mehta-aman/mehta-restaurant](https://github.com/mehta-aman/mehta-restaurant)
* **CI/CD Actions:** [Automated GitHub Actions Pipeline](https://github.com/mehta-aman/mehta-restaurant/actions)

---

## 🔄 Automated CI/CD Pipeline

Every commit pushed to the `master` branch triggers the GitHub Actions workflow [`.github/workflows/firebase-hosting-merge.yml`](.github/workflows/firebase-hosting-merge.yml):
1. Checks out repository and sets up Flutter environment
2. Resolves dependencies and compiles optimized Flutter Web release
3. Injects live Supabase configuration via `--dart-define`
4. Deploys directly to Firebase Hosting with zero manual intervention

---

## 🏢 Restaurant Architecture & Features

- **Live Database-Driven:** 100% cloud-synchronized via Supabase. Zero mock or static demo data.
- **Universal Multi-Device Access:** Runs seamlessly on MacBook, iPhone (fullscreen PWA), iPad, and Android phones simultaneously.
- **Table Management:** Dynamic table states, order timers, table merging, and live occupancy tracking.
- **POS & Billing:** Split billing, UPI QR code generation, instant receipt printing (58mm/80mm thermal rolls), and PDF invoice downloads.
- **Customer Khata (Ledger):** Customer credit management, partial settlements, balance history, and WhatsApp statement delivery.
- **Kitchen Display System (KDS):** Real-time order dispatch, state progression (Ordered -> Preparing -> Ready -> Served), and kitchen audio chimes.
- **Dynamic Settings:** Store details, thermal roll sizing, tax configurations, and receipt footers dynamically updated from Supabase.

---

## 🚀 Local Development

### 1. Prerequisites
- **Flutter SDK** (Channel stable)
- **Node.js** (v20+)

### 2. Manual Deployment
To deploy directly from your local terminal at any time:
```bash
./deploy.sh
```

### 3. Run Locally
- **Flutter Web:**
  ```bash
  flutter run -d chrome
  ```
- **macOS Desktop:**
  ```bash
  flutter run -d macos
  ```
