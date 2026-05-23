# TruServe Intelligent Document Scanner

A Flutter-based mobile application for Truserve Pharmaceutical — built to help pharmacy staff track medicines, manage supplier invoices, monitor expiry dates, and handle product return windows with ease.

---

## Table of Contents

- [Overview](#overview)
- [Features](#features)
- [Tech Stack](#tech-stack)
- [Project Structure](#project-structure)
- [Getting Started](#getting-started)
- [Environment Variables](#environment-variables)
- [Firebase Setup](#firebase-setup)
- [Using the App](#using-the-app)
- [AI-Powered Invoice Scanning](#ai-powered-invoice-scanning)
- [Data Models](#data-models)
- [Contributing](#contributing)

---

## Overview

**TruServe Intelligent Document Scanner** is a mobile-first pharmacy management tool designed to simplify the day-to-day operations of a pharmacy. It provides real-time inventory tracking, AI-assisted invoice check-in via OCR and visual analytics — all backed by Firebase.

---

## Features

- **Authentication** — Secure login and sign-up via Firebase Auth
- **Medicine Inventory** — Add, view, search, edit, and delete medicine records
- **Expiry Tracking** — Automatic status classification: `Good`, `Expiring Soon`, `Expired`
- **Return Window Management** — Tracks the 6-month return deadline before expiry; flags products as `Returnable`, `Return Soon`, `Window Closed`, or `Expired`
- **Return Status Workflow** — Mark products as `Pending`, `Scheduled`, or `Completed` for returns
- **Invoice Scanning using IDP** — Upload a photo of a supplier invoice; the Veryfi OCR API extracts line items automatically
- **Invoice Records** — Browse grouped invoices by invoice number with line-item detail
- **Analytics** — Pie chart for medicine expiry status breakdown; bar chart for spend by supplier
- **Push Notifications** — Background task support via WorkManager for return deadline reminders

---

## Tech Stack

| Layer | Technology |
|---|---|
| Framework | Flutter (Dart) |
| Backend / Auth | Firebase (Firestore + Firebase Auth) |
| OCR / AI | Veryfi Document AI API |
| Charts | fl_chart |
| Notifications | flutter_local_notifications + workmanager |
| HTTP | http package |
| Config | flutter_dotenv |

---

## Project Structure

```
lib/
├── main.dart                   # App entry point, Firebase & notification init
├── firebase_options.dart       # Firebase platform configuration
├── assets/
│   └── icons/
│       └── truserve_app.png    # App icon
├── models/
│   ├── product_model.dart      # Product data model + expiry/return logic
│   └── invoice_record.dart     # Invoice line item model
├── services/
│   ├── firestore_service.dart  # Firestore CRUD operations
│   └── notification_service.dart # Push notifications & background tasks
└── screens/
    ├── landing_screen.dart     # Onboarding / welcome screen
    ├── login_screen.dart       # User login
    ├── signup_screen.dart      # User registration
    ├── dashboard_screen.dart   # Main app hub (inventory, invoices, returns tabs)
    ├── add_checkin_screen.dart # AI invoice scanning & manual check-in
    └── analytics_screen.dart  # Charts and reporting
```

---

## Getting Started

### Prerequisites

- Flutter SDK `>=3.0.0`
- Dart SDK `>=3.0.0`
- A Firebase project (Firestore + Authentication enabled)
- A [Veryfi](https://www.veryfi.com/) account for OCR

### Installation

```bash
# Clone the repository
git clone https://github.com/joshaurellano/bsis3A-business-checkin-flutterkick.git

# Install dependencies
flutter pub get

# Copy the env template and fill in your credentials
cp .env.example .env

# Run the app
flutter run
```

---

## Environment Variables

Create a `.env` file at the root of the project:

```env
VERYFI_CLIENT_ID=your_veryfi_client_id
VERYFI_USERNAME=your_veryfi_username
VERYFI_API_KEY=your_veryfi_api_key
```

These are loaded at runtime via `flutter_dotenv`. Never commit this file to version control — add `.env` to `.gitignore`.

---

## Firebase Setup

1. Create a Firebase project at [console.firebase.google.com](https://console.firebase.google.com).
2. Enable **Firestore Database** and **Authentication** (Email/Password).
3. Download `google-services.json` (Android) and/or `GoogleService-Info.plist` (iOS) and place them in the respective platform folders.
4. The app uses the following Firestore collections:

| Collection | Purpose |
|---|---|
| `medicine_logs` | Stores all medicine/product records |
| `invoice_items` | Stores individual invoice line items |
| `users` | Stores user display names keyed by `uid` |

---

## Using the App

### 1. Landing Screen
The opening screen presents the TruServe branding with options to **Get Started** (sign up) or **Log In**.

### 2. Sign Up / Log In
New users register with name, email, and password. Existing users log in with their credentials via Firebase Auth.

### 3. Dashboard — Three Tabs

#### Medicines Tab
- Browse the full inventory with a search bar (filters by generic name, brand name, or supplier).
- Each medicine card shows expiry status, return window status, and return workflow state.
- Swipe a card to reveal **Edit** and **Delete** actions.
- Tap a card to update return status (`Pending → Scheduled → Completed`).

#### Invoices Tab
- View all supplier invoices grouped by invoice number.
- Each invoice entry shows supplier name, delivery date, and total amount.
- Expand an invoice to see individual line items (item code, description, quantity, batch number, expiry date, amount).
- Search invoices by supplier name or invoice number.

#### Returns Tab
- Filtered view of medicines that need attention: flagged as `Return Soon` or `Window Closed`.
- Sorted by days remaining until the return deadline.
- Quick-action to update return status inline.

### 4. Add Check-In (FAB Button)
Tap the floating action button on the dashboard to open the invoice check-in screen (see AI section below).

### 5. Analytics
Tap the chart icon in the app bar to view:
- **Medicine Expiry Status** — Pie chart showing Good / Expiring Soon / Expired counts.
- **Spend by Supplier** — Bar chart of total purchase amount per supplier.

---

## AI-Powered Invoice Scanning

TruServe uses the **Veryfi Document AI API** to automate data extraction from supplier invoices.

### How It Works

1. On the **Add Check-In** screen, tap **Capture Invoice** or **Choose from Gallery**.
2. Select or photograph a supplier invoice.
3. The image is encoded to Base64 and sent to the Veryfi OCR endpoint.
4. Veryfi's AI reads the document and returns structured data: supplier name, invoice number, delivery date, and a list of line items (item code, description, quantity, batch number, expiry date, amount).
5. The app populates an editable form pre-filled with the extracted data.
6. Review and correct any fields as needed, then tap **Save** to commit all line items to Firestore.

### Manual Entry
If OCR is not needed, all fields on the check-in screen can be filled in manually. You can add or remove line items before saving.

### Veryfi API Reference
- Endpoint: `https://api.veryfi.com/api/v8/partner/documents/`
- Auth headers: `CLIENT-ID` and `AUTHORIZATION: apikey username:api_key`
- Relevant fields returned: `vendor.name`, `invoice_number`, `date`, `line_items[]`

> **Note:** Set `auto_delete: true` in the request body so scanned documents are not stored on Veryfi's servers after processing.

---

## Data Models

### Product (`medicine_logs`)

| Field | Type | Description |
|---|---|---|
| `genericName` | String | INN / generic drug name |
| `brandName` | String | Brand/trade name |
| `supplierName` | String | Supplier or distributor |
| `dosageForm` | String | e.g. Tablet, Capsule, Syrup |
| `sellingPrice` | String | Retail price |
| `expiryDate` | String | ISO date or MM/YYYY |
| `stockStatus` | String | Stock availability note |
| `returnStatus` | int | 0=none, 1=pending, 2=scheduled, 3=completed |
| `returnReason` | String? | Reason for return |
| `lat` / `lng` | double? | Location of check-in |
| `createdBy` | String | UID of the user who added the record |

**Computed properties (client-side):**
- `status` — `good`, `expiringSoon`, `expired` (based on days until expiry)
- `returnWindowStatus` — `returnable`, `returnSoon`, `windowClosed`, `expired` (return deadline = expiry − 6 months)
- `daysUntilReturnDeadline` — integer countdown

### InvoiceRecord (`invoice_items`)

| Field | Type | Description |
|---|---|---|
| `invoiceNumber` | String | Invoice reference number |
| `supplierName` | String | Supplier name |
| `deliveryDate` | String | Date of delivery |
| `invoiceTotal` | String | Total invoice amount |
| `itemCode` | String | Product/SKU code |
| `description` | String | Product description |
| `quantity` | String | Units delivered |
| `batchNo` | String | Batch/lot number |
| `expiryDate` | String | Item expiry date |
| `amount` | String | Line item amount |
| `createdBy` | String | UID of the user who scanned/entered |

---

## Contributing

1. Fork the repository and create a feature branch (`git checkout -b feature/your-feature`).
2. Follow the existing code conventions (Dart/Flutter best practices, meaningful widget decomposition).
3. Test on both Android and iOS simulators before submitting.
4. Open a pull request with a clear description of changes.

For bug reports or feature requests, open a GitHub Issue.

---


CREATED BY:
Team FlutterKick
-Joshua Anthony Aurellano
-Dominnica Narvato
-Aron Delos Santos
-Marvin Nobela