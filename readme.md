# Attendify – Smart Location-Bound QR Attendance System

Attendify is a secure and modern attendance solution built using **Flutter** that eliminates proxy attendance using **location-bound dynamic QR codes**, **device locking**, and **real-time monitoring**. Designed for educational institutions to ensure that only physically present students can mark attendance.

---

## 🚀 Key Features

- **📍 Location-Bound QR Attendance**
  - Teachers generate a QR code with a **custom radius limit**
  - Students can scan and mark attendance **only within the defined area**
  - Attempts from outside range are **blocked** and **instantly notified** to the teacher

- **🔄 Dynamic QR Refresh**
  - QR code **changes every 5 seconds** to prevent screenshot sharing and proxy attempts

- **🖥 QR Display on Web**
  - QR generated from the teacher’s mobile automatically **mirrors to the web dashboard**
  - Useful for displaying on **projector / smartboard / big screens**

- **📱 Mobile-Based QR Scan & Generate**
  - Teachers generate QR and students scan it from the **Flutter mobile app**
  - Real-time location verification ensures secure attendance

- **🔐 Device Lock System**
  - Each student account can log in to **only one device**
  - Prevents login sharing and remote attendance marking
  - Device reset requires **admin approval**

---

## 🎯 Objective
To eliminate proxy attendance and build a secure, transparent, and reliable attendance system for educational institutions.

---

## 🌐 Live Web Dashboard
Use this link to **display the live dynamic QR** during class:

🔗 **https://attendify.pages.dev**

---

## 📱 Download APK (Teacher & Student App)
➡️ Install the Android APK to **generate QR** or **scan QR** on mobile  
📦 *app-release.apk included in the repository root*

---

## 🛠 Tech Stack

| Technology | Purpose |
|------------|---------|
| Flutter | Mobile App & Web Build |
| Firebase | Auth, Database, Notifications |
| Google Location APIs | Geo-verification |
| Web Dashboard | Display QR via projector |

---

## 📲 Workflow Diagram (Architecture)

```mermaid
flowchart TD
    A[Teacher Creates Attendance Session] --> B[QR Generated with Location Radius]
    B --> C[QR Displayed on Mobile + Web Dashboard]
    D[Student Scans QR] --> E[Check Location Within Defined Radius]
    E -->|Within Range| F[Attendance Marked Successfully]
    E -->|Out of Range| G[Blocked & Teacher Notified Instantly]
    H[Device Lock Protection] --> D
