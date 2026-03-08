# 🚪 GateEase – Smart Digital Campus Gate Pass Management System

GateEase is a **smart digital gate pass management system** designed to automate and secure the student exit process in college campuses. It replaces manual paper-based passes with a centralized, real-time, and fully trackable digital workflow.


## 📌 Features

- 🔐 **Role-Based Authentication**
  - Separate login for Admin, Student, Mentor, and Security
  - Password hashing with PBKDF2 (Django's `make_password`)
  - OTP-based forgot password via email

- 🎫 **Exit Pass Management**
  - Students apply for exit passes with reason and exit time
  - Mentor receives instant push notification on pass request
  - Mentor approves or rejects with optional reject reason
  - Pass status tracked in real-time via a timeline view

- 📲 **QR Code System**
  - QR code generated upon mentor approval
  - Available only 15 minutes before the requested exit time
  - Security scans QR at the gate to verify and log exit
  - Duplicate scan prevention built-in

- 👥 **Group Pass**
  - Mentor can create passes for multiple students at once
  - Useful for field trips, lab sessions, or batch activities

- 🔔 **Push Notifications**
  - Firebase Cloud Messaging (FCM) sends real-time alerts to mentors
  - Tapping the notification deep-links to the pending pass list

- 🗂️ **Admin Web Panel**
  - Manage students, mentors, security personnel
  - Manage departments, classes/batches, and mentor assignments
  - View and filter all exit passes by month
  - Export pass reports as PDF
  - Reply to student complaints

- 📊 **Reports & Logs**
  - Filterable exit report by student name, class, and date
  - PDF export from both admin panel and mentor app
  - Full audit trail with timestamps (applied, approved, scanned)

- 📱 **Mobile App (Flutter)**
  - Separate home screens for Student, Mentor, and Security
  - Student: apply pass, view timeline, view QR, raise complaints
  - Mentor: pending passes, group pass, student list, exit report
  - Security: QR scanner, group pass list

---

## 🏗️ System Architecture

- **Frontend (Mobile)**: Flutter (Dart)
- **Backend**: Django 4.2 / Django REST Framework
- **Database**: SQLite (development) / PostgreSQL (production)
- **Push Notifications**: Firebase Cloud Messaging (FCM)
- **QR Generation**: Python `qrcode` library
- **QR Scanning**: `mobile_scanner` Flutter package
- **PDF Export**: `xhtml2pdf` (backend), `pdf` + `printing` (Flutter)
- **Authentication**: Custom session-based (web) + login_id stored in SharedPreferences (mobile)
- **Deployment**: Cloud server with Gunicorn + WhiteNoise
