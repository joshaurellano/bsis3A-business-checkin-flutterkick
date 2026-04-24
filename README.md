# TruServe Pharmaceutical Check-In Log App

## Business App Idea
A pharmaceutical inventory management solution for TruServe Pharmacy that tracks product expiry dates and supplier returns. Field agents can log site visits, capture product photos with expiry status, and record which supplier products need to be returned to - all with GPS-verified location proof.

## Collection Name
**`pharma_visits`** - Stores all pharmaceutical site visit records

### Firestore Fields:
- businessName (String)
- note (String)
- createdAt (Timestamp)
- photoUrl (String)
- lat (Number)
- lng (Number)
- createdBy (String)
- proofLabel (String)
- **expiryStatus (String)** - Business-specific: "Good", "Expiring Soon", "Expired"
- **supplierName (String)** - Business-specific: Name of supplier for returns

## Setup Instructions

### 1. Prerequisites
- Flutter SDK (3.0+)
- Firebase account
- Android Studio / VS Code

### 2. Firebase Setup
```bash
# Create new Firebase project
# Enable Firestore and Storage
# Register Android/iOS app
# Download google-services.json (Android) or GoogleService-Info.plist (iOS)