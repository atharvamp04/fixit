# 🛠️ Invexa

Invexa is a **Flutter-based mobile app** that streamlines technician workflows, inventory management, PDF invoicing, multilingual communication, and real-time support via chatbot. It's built for service-based companies managing technicians and stock movement.

<p align="center">
  <a href="https://play.google.com/store/apps/details?id=com.yourcompany.Invexa">
    <img src="https://play.google.com/intl/en/badges/static/images/badges/en_badge_web_generic.png" height="80" alt="Get it on Google Play"/>
  </a>
</p>

---

## 📱 Features

- 🔔 Real-time technician notifications
- ✅ Accept or reject part requests
- 📦 Inventory & product quantity management
- 📄 PDF-based courier slip generation
- 📧 Email integration for sending bills & confirmations
- 📊 Detailed invoice summary with GST, service charges, total
- 📥 Snackbar feedback after successful downloads
- 💬 Voice chatbot powered by **Wit.ai** to check stock in real-time
- 🌐 **Multilingual support** for broader accessibility


---

## 🧑‍💻 Tech Stack

| Layer            | Technology                       |
|------------------|-----------------------------------|
| Frontend         | Flutter (Dart)                   |
| Backend          | Supabase (Auth + Database)       |
| PDF & Printing   | `pdf` + `printing` package       |
| Email Service    | SMTP via `mailer` package        |
| Barcode Scanning | Built-in Flutter scanner widget  |
| Chatbot          | [Wit.ai](https://wit.ai)         |
| State Management | `setState`, `StatefulBuilder`    |
| Localization     | `easy_localization`              |

---
## 🌍 Supported Languages

Invexa supports the following 14 languages using `easy_localization`:

- 🇬🇧 English (`en`)
- 🇮🇳 Hindi (`hi`)
- 🇮🇳 Marathi (`mr`)
- 🇮🇳 Tamil (`ta`)
- 🇮🇳 Bengali (`bn`)
- 🇮🇳 Punjabi (`pa`)
- 🇪🇸 Spanish (`es`)
- 🇫🇷 French (`fr`)
- 🇩🇪 German (`de`)
- 🇮🇹 Italian (`it`)
- 🇸🇦 Arabic (`ar`)
- 🇯🇵 Japanese (`ja`)
- 🇷🇺 Russian (`ru`)
- 🇨🇳 Chinese (`zh`)

> Add new translations easily inside `/assets/translations`.
---

## 📁 Project Structure

```plaintext
lib/
├── models/
│   └── user_model.dart
├── screens/
│   ├── login_page.dart
│   ├── signup_page.dart
│   ├── home_page.dart
│   ├── profile_screen.dart
│   ├── chat_screen.dart
│   ├── bill_screen.dart
│   ├── history_screen.dart
│   ├── manager_notifications_screen.dart
│   ├── user_notifications_screen.dart
│   └── pdf_generator.dart
├── services/
│   ├── auth_service.dart
│   ├── bill_email_service.dart
│   ├── mail_service.dart
│   ├── slip_service.dart
│   └── wit_ai_service.dart
├── widgets/
│   ├── chat_bubble.dart
│   ├── animated_chat_bubble.dart
│   ├── barcode_scanner_screen.dart
│   ├── product_grid.dart
│   └── bill_summary_bottom_sheet.dart
└── main.dart

---

## 🚀 Getting Started

### ✅ Prerequisites

- [Flutter SDK](https://docs.flutter.dev/get-started/install) (3.10 or later)
- [Supabase account](https://supabase.com/) (project + database)
- SMTP credentials (e.g. Brevo, Gmail App Password)
- Wit.ai app for chatbot API key

---

### ⚙️ Installation Steps

```bash
# 1. Clone the repository
git clone https://github.com/your-username/Invexa.git
cd Invexa

# 2. Install Flutter packages
flutter pub get

# 3. Run the app
flutter run

