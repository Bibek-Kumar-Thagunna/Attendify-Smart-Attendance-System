# Attendify – Smart Location-Bound QR Attendance System

Attendify is a secure and modern attendance solution built using **Flutter** that eliminates proxy attendance using **location-bound dynamic QR codes**, **device locking**, and **real-time monitoring**. Designed for educational institutions to ensure that only physically present students can mark attendance.

---

## 🚀 Key Features

- **📍 Location-Bound QR Attendance**
  - Teachers generate a QR code with a **custom radius limit**
  - Students can scan and mark attendance **only within the defined area**
  - Attempts from outside range are **blocked and notified to the teacher**

- **🔄 Dynamic QR Refresh**
  - QR code **changes every 5 seconds** to prevent screenshot sharing and proxy attempts

- **🖥 QR Display on Web**
  - QR generated on teacher’s mobile is **mirrored to the web dashboard** for projector display

- **📱 Mobile-Based QR Scan & Generate**
  - Teachers generate QR and students scan using the **Flutter mobile app**
  - Ensures accurate real-time location validation

- **🔐 Device Lock System**
  - Each student account can log in on **only one device**
  - Prevents sharing credentials and marking attendance on someone else’s behalf
  - Device reset requires admin approval

---

## 🎯 Objective
To eliminate proxy attendance and build a secure, transparent, and reliable attendance system for educational institutions.

---

## 🛠 Tech Stack

| Technology | Purpose |
|------------|---------|
| Flutter | Mobile App & Web Build |
| Firebase / Backend | Auth, Database, Notifications |
| Google Location APIs | Geo-verification |
| Web Dashboard | Display QR via projector in classroom |

---

## 📲 Workflow Diagram (Architecture)

```mermaid
flowchart TD
    A[Teacher Creates Attendance Session] --> B[QR Generated with Location Radius]
    B --> C[QR Displayed on Mobile + Web Dashboard]
    D[Student Scans QR] --> E[Check Location]
    E -->|Within Range| F[Attendance Marked Successfully]
    E -->|Out of Range| G[ Teacher Notified]
    H[Device Lock] --> D
