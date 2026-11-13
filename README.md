# UTS SmartShop

A mobile pre-order and QR code pickup app for UTS Koperasi, built for a Sustainable Smart Campus. It's an Android app built in Flutter with a Firebase backend, and it needs only a phone (no IoT hardware).

Team **Sustainable Smart Campus**. The build guide is `MAD_SmartShop_App_Development.md` (v2.0), and the section and feature numbers below refer to it.

## What's in the app

| # | Feature | Where |
|---|---|---|
| M1 | Register / login / logout, role-based redirect (student → `/home`, staff → `/staff`) | `screens/auth`, `core/router.dart` |
| M2 | Catalogue with categories, search, live price and stock | Student Home, `product_list_screen.dart` |
| M3 | Scan a barcode → price and stock | Student Scan → Product Detail |
| M4 | Cart and pre-order with the "No plastic bag" option; pay at counter | Cart |
| M5 | Pickup QR code and order status (Pending → Ready → Collected) | My Orders → order |
| M6 | Orders queue: Accept & pack (stock deducted) → Ready → scan pickup QR → Collected | Staff → Orders |
| M7 | Product management: add / edit / disable, scan the barcode to fill it in | Staff → More → Products |
| M8 | Stock in / out by scan or search, low-stock alerts, all logged in `stock_movements` | Staff → Stock, Alerts |
| M9 | Digital receipts and purchase history | My Orders, receipt screen |
| S1 | "Order ready" notification (plus Save Food deals for students, stock alerts for staff) | `services/notification_watcher.dart` |
| S2 | Green points: +5 for no plastic bag (+10 per Save Food item) | Cart, Green Points, Profile |
| S3 | Sales chart, top products, sustainability metrics (section 10) | Staff → Reports |
| S4 | ⭐ AI Budget Planner: budget + any categories + "personalise" text (e.g. `chocolate, no spicy` / `tak nak pedas`) → 3 best combos → pre-order in one tap | Student Home → AI Budget Planner |
| S5 | ⭐ AI Expiry-Date Scanner (Google ML Kit, on-device, works offline) and near-expiry alerts | Stock in, Product form, Alerts |
| S6 | Cancel uncollected orders after the pickup window; stock returned | Staff → Orders → Ready |
| S7 | Counter sale: scan items (+ member QR), checkout in a transaction, digital receipt | Staff → Counter sale |
| C1 | Save Food deals on near-expiry items | Staff → Alerts, Student Home carousel |
| C2 | QR labels for items without a barcode (`SK-000123` codes) | Products → ⋮ → QR label |
| C4 | English / Bahasa Melayu, plus light / dark mode | Profile → Preferences |
| Extra | Profile: edit name, ID and phone; change password (with strength line); member QR | Profile |

Not in this version: C3 (CSV import).

**Translations:** English text in the code is the key; the Malay is in `lib/l10n/malay.dart`. Use `context.tr('...')` for new text. `test/translations_test.dart` fails if a text has no Malay entry.

## Architecture: MVVM

The app follows **Model-View-ViewModel** with the `provider` package:

| Layer | Folder | Job |
|---|---|---|
| **Model** | `models/` + `services/` | The data (Product, Order, AppUser...) and everything that talks to Firebase, GPS or ML Kit |
| **ViewModel** | `viewmodels/` | One per screen (e.g. `DashboardViewModel`, `HomeViewModel`): holds the screen's data and actions, follows live Firestore streams, no UI code |
| **View** | `screens/` + `widgets/` | Draws the ViewModel and passes taps to it; never calls a service or Firebase |

- `core/router.dart` creates each screen together with its ViewModel (`_mvvm(...)`), so the ViewModel and its live streams are disposed with the page.
- App-wide ViewModels: `AuthViewModel` (login and role), `CartViewModel`, `SettingsViewModel` (language, light / dark mode).
- `viewmodels/view_model.dart` is the base class: `follow()` keeps data live from Firestore (the View redraws by itself), `run()` shows a spinner while an action runs.
- `test/architecture_test.dart` checks the rules on every test run; `test/view_model_test.dart` tests ViewModels with fake services (no phone, no Firebase).

## Project structure

```
lib/
├── main.dart               Firebase init (+ emulator mode), runApp
├── app.dart                services + app-wide ViewModels, MaterialApp.router, theme
├── firebase_options.dart   from `flutterfire configure`
├── core/                   theme, go_router (+ MVVM wiring, role redirect), business rules, utils
├── models/                 AppUser, Product, Order, StockMovement, budget plan
├── services/               all Firebase / GPS / ML Kit calls, AI Budget Planner, notifications
├── viewmodels/             base ViewModel, Auth / Cart / Settings, and {student,staff,common}/ per screen
├── screens/{auth,student,staff,common}/   Views
└── widgets/                scanner, product cards, 3D picture, receipt, shared UI
test/                       business rules, AI planner, expiry parser, ViewModels, architecture, UI
firestore.rules             security rules (section 7.5)
```

## Setup

### 1. Flutter
```bash
flutter pub get
flutter test
```

### 2. Connect Firebase (one-time, done by the team lead)
1. In the [Firebase Console](https://console.firebase.google.com), create a project. Turn on **Authentication → Email/Password** and **Firestore**. The free Spark plan is enough.
2. In this folder, run:
   ```bash
   dart pub global activate flutterfire_cli
   flutterfire configure            # choose the project, platform: android
   firebase deploy --only firestore:rules
   ```
   `flutterfire configure` overwrites `lib/firebase_options.dart` and adds `google-services.json`. The Android package is `com.ssc.smartshop`. Until you run it, the app opens on a "Firebase could not start" screen.

### 3. Create a staff account
Users can't make themselves staff, because the security rules block it.
1. Register in the app like a student, or add a user in the Console under **Authentication**.
2. In **Firestore → users → {uid}**, change `role` from `student` to `staff`.
3. Log in again. You land on the Staff Dashboard.
4. Go to **More → Load sample products** to add 28 demo products. They use GS1 "200" in-store barcodes, so they never clash with real products, and come with a starting `soldCount` so "Popular now" and the AI Budget Planner have data. To use real products, scan their barcodes from **Products → Add product**.

### 4. Run on a phone
Turn on USB debugging, plug the phone in, then run `flutter run`. Use a real phone for scanning, because the emulator camera is limited. For the demo, use one phone logged in as **staff** and one as a **student**.

## Developing without a Firebase project (local emulators)

```bash
firebase emulators:start --only auth,firestore --project testdb-3da20
flutter run --dart-define=USE_FIREBASE_EMULATOR=true
```
This uses the Firebase Local Emulator Suite with the real `firestore.rules`. The emulator UI is at http://localhost:4000, where you can set a user's `role` to `staff`. Debug builds allow plain HTTP to `10.0.2.2`/`localhost` for this (`android/app/src/debug/res/xml/network_security_config.xml`). Release builds don't.

## Design notes
- **Money is stored in sen** (integers), so RM18.50 is stored as `1850`.
- **Product document ID = barcode.** Items without a barcode get `SK-000123` and a printable QR label.
- **Stock only changes through `StockService` / `OrderService`**, and every change writes a `stock_movements` entry. Sales and packed pre-orders also add to `soldCount` (the AI Budget Planner's popularity score); a cancelled packed order takes it back off.
- **Transactions protect the last item.** Counter sale, Accept & pack, stock out and cancel-after-pack all run in Firestore transactions. When offline, they show "No connection, try again". Stock-in uses `FieldValue.increment`, so it's queued offline and synced later.
- **The app total is never trusted.** "Accept & pack" and counter sales re-price items from the current product data. Payment is "Pay at counter".
- **Pickup window.** A READY order can be collected until the koperasi closes (`AppRules.closingHour`, 6 pm) on the day it was packed. After that, **Cancel uncollected** cancels it, restores the stock and sets `cancelReason: 'not_collected'`, so the student sees "Cancelled: not collected".
- **AI Budget Planner** (`services/budget_planner_service.dart`) runs in the app, with no paid AI service. Breakfast uses Food + Drinks, Lunch uses Food + Drinks + Snacks, and Snack uses Drinks + Snacks.
- **No composite indexes needed.** "My orders" filters by `userId` and sorts on the phone.
- **Spark plan:** product images are URLs, and notifications come from Firestore listeners + `flutter_local_notifications`. They work while the app is open or in the background. Push notifications when the app is closed need Blaze (Cloud Functions + FCM).

## Test cases (section 12.2)

| ID | How it is covered |
|---|---|
| TC01–TC02 | Role redirect in `core/router.dart` (manual: log in as student / staff) |
| TC03–TC04 | Product Detail shows price/stock, or "Product not found — ask staff" |
| TC05 | Stock screen → Stock in 24 → stock +24 and a `stock_in` movement |
| TC06 | Cart can't exceed the stock shown (unit test), and the transaction re-checks with "Not enough stock…" |
| TC07–TC08 | Orders queue + `OrderService` transactions; students can only cancel pending orders |
| TC09–TC10 | `needsRestock` / `isNearExpiry` unit tests + Alerts screen |
| TC11 | Points unit test (+5 no plastic bag), added on collection |
| TC12 | `firestore.rules`: a student can't change `role` |
| TC13–TC14 | `test/expiry_parser_test.dart` + "Date not found, please pick it manually" |
| TC15–TC17 | `test/budget_planner_test.dart` + "No combo fits this budget. Try a higher amount." + "Pre-order this combo" fills the cart |
| TC18–TC19 | Pickup-window unit tests + Orders → Ready → "Cancel uncollected"; scanning a cancelled order shows "Order not ready for pickup" |

Run the automated tests with `flutter test`.
