# UTS SmartShop: Code Explanation (MVVM version)

This guide explains every folder and file in the app after the change to the **MVVM** (Model-View-ViewModel) architecture, in plain English.

---

## 1. MVVM in one minute

The code is split into three layers. Each layer has one job and only talks to the layer next to it.

```
 View (screens/, widgets/)          what the user sees and taps
        |   reads data, calls actions
        v
 ViewModel (viewmodels/)            the screen's data and logic
        |   asks for data, sends changes
        v
 Model (models/ + services/)        the data and Firebase / GPS / camera
        |
        v
 Firebase (Auth + Cloud Firestore)  online database and logins
```

| Layer | Folder | Job | Rule |
|---|---|---|---|
| **Model** | `lib/models/` | The shape of the data: Product, Order, AppUser, StockMovement, budget plan | Plain data classes, no screens |
| | `lib/services/` | Talks to Firebase, the GPS, ML Kit (camera AI) and phone notifications | The only code that touches Firebase |
| **ViewModel** | `lib/viewmodels/` | One per screen: holds the screen's data, follows live Firestore data, runs the actions (save, place order, accept...) | No UI code (no `BuildContext`, no widgets) |
| **View** | `lib/screens/`, `lib/widgets/` | Draws what the ViewModel holds and passes taps to it | Never calls a service or Firebase directly |

How a screen gets its ViewModel: `lib/core/router.dart` creates each page **together with** its ViewModel (`_mvvm(...)`). When the page closes, the ViewModel and its live data streams close too.

Two tests check these rules every time the tests run: `test/architecture_test.dart` fails if a screen imports a service, or a ViewModel uses UI code.

---

## 2. Folder map

```
MADPROJECT/
├── lib/                      the app's code
│   ├── main.dart             start-up
│   ├── app.dart              builds the app, provides services and app-wide ViewModels
│   ├── firebase_options.dart which Firebase project to use
│   ├── core/                 router, colours, business rules, small helpers
│   ├── models/               MODEL: data classes
│   ├── services/             MODEL: Firebase, GPS, ML Kit, notifications
│   ├── viewmodels/           VIEWMODEL: one per screen + app-wide ones
│   │   ├── student/
│   │   ├── staff/
│   │   └── common/
│   ├── screens/              VIEW: the pages
│   │   ├── auth/
│   │   ├── student/
│   │   ├── staff/
│   │   └── common/
│   ├── widgets/              VIEW: reusable building blocks
│   └── l10n/                 English and Bahasa Melayu text
├── test/                     101 automatic tests
├── android/                  Android packaging (name, icon, permissions)
├── assets/images/            UTS logo
├── docs/                     this guide, screenshots, proposal
├── firestore.rules           database security rules
├── firebase.json             Firebase CLI settings
├── pubspec.yaml              app name, version, packages
└── README.md                 project front page on GitHub
```

---

## 3. Start-up files (`lib/`)

| File | What it does |
|---|---|
| `main.dart` | First code that runs. Connects to Firebase (or the local practice database with `--dart-define=USE_FIREBASE_EMULATOR=true`), turns on the offline cache, loads Malay dates and notifications, then starts the app. Shows a setup page instead of crashing if Firebase fails. |
| `app.dart` | Creates the **services** and the **app-wide ViewModels** (`AuthViewModel`, `CartViewModel`, `SettingsViewModel`) and makes them available to every page. Applies the light/dark theme and the chosen language. Starts the notification watcher after login. |
| `firebase_options.dart` | Made by `flutterfire configure`: the Firebase project ID (`testdb-3da20`). |

---

## 4. Core (`lib/core/`)

| File | What it does |
|---|---|
| `router.dart` | The map of every page and its address (`/home`, `/cart`, `/staff/orders`...). **MVVM wiring:** `_mvvm(create, view)` builds each page with its ViewModel. Also sends people to the right place: not logged in → login, student → student pages, staff → staff pages. |
| `theme.dart` | UTS colours (navy, gold), Poppins font, light and dark themes. |
| `constants.dart` | Business rules in one place: near expiry = 3 days, +5 points for no plastic bag, +10 per Save Food item, 100 points = RM1, opening hours 8 AM–6 PM, the koperasi's map position, car and motorcycle parks, categories, order statuses. |
| `utils/codes.dart` | Pickup codes (6 characters, no 0/O or 1/I) and `SK-` codes for items without a barcode. |
| `utils/format.dart` | Money (stored in sen, shown as "RM 18.50") and dates in the app language. |
| `utils/points.dart` | Green points for an order, voucher value, suggested Save Food price (30% off). |
| `utils/password.dart` | Password rules and strength levels. |
| `utils/geo.dart` | Distance between two points, walking minutes, "350 m" / "1.2 km" text. |
| `utils/errors.dart` | Turns Firebase errors into friendly messages in English or Malay. |
| `utils/firestore_helpers.dart` | Safe number/date reading from Firestore; waits for a write to reach the server. |

---

## 5. MODEL layer

### 5.1 Data classes (`lib/models/`)

| File | Firestore collection | What one record holds |
|---|---|---|
| `product.dart` | `products/{barcode}` | Name, category, price (sen), Save Food price, stock, low-stock level, expiry date, image URL, description, units sold, shown/hidden. |
| `order.dart` | `orders/{id}` | Items (`OrderItem`), total, status (pending, ready, collected, cancelled), pickup code, no-plastic-bag choice, points, times. |
| `app_user.dart` | `users/{uid}` | Name, email, Student ID, phone, role (student/staff), green points, profile photo, member QR text. |
| `stock_movement.dart` | `stock_movements/{id}` | One stock change: product, +/− quantity, reason, who, stock after. |
| `budget_plan.dart` | (not stored) | AI Budget Planner data: `Combo` (a suggested set), `MealType` (Breakfast/Lunch/Snack), `Wishes` (reads "milo, no spicy"). |

### 5.2 Services (`lib/services/`)

| File | What it does |
|---|---|
| `auth_service.dart` | Firebase Auth + user profiles: log in, register, join as staff (first staff = admin), staff invites, edit profile and photo, change/reset password, log out. |
| `product_service.dart` | Live product lists, find by barcode, add/edit/hide, Save Food price, new `SK-` codes, load sample products. |
| `order_service.dart` | Place pre-order; accept & pack (takes stock off in one transaction, rechecks prices); collect (adds points); cancel; cancel uncollected; counter sales; live order lists. |
| `stock_service.dart` | Stock in / stock out, each logged in `stock_movements`; live stock history. |
| `budget_planner_service.dart` | The AI Budget Planner brain: scores products (popularity, your past buys, wishes) and builds 3 combos within budget. Runs on the phone. |
| `expiry_scan_service.dart` | AI Expiry-Date Scanner: photo → Google ML Kit text reading on the phone → finds the date. |
| `location_service.dart` | Phone GPS (geolocator): asks permission, live position, opens settings. Has a `LocationSource` interface so tests can fake the GPS. |
| `notification_service.dart` | Shows phone notifications. |
| `notification_watcher.dart` | Watches the database while the app is open: "Order ready" and Save Food deals for students, low stock and near expiry for staff. |
| `sample_data.dart` | The 46 demo products (with descriptions in English and Malay). |

---

## 6. VIEWMODEL layer (`lib/viewmodels/`)

### 6.1 Base class and app-wide ViewModels

| File | What it does |
|---|---|
| `view_model.dart` | **Base class for all screen ViewModels.** `follow()` keeps data live from a Firestore stream so the screen redraws by itself; `run()` shows a spinner (`busy`) while an action runs; `notify()` is safe after the page closes. |
| `auth_view_model.dart` | Who is logged in, their profile and role. The router listens to it to redirect on login/logout. Login, register, join as staff, edit profile/photo, change password (turns a wrong current password into a friendly message). |
| `cart_view_model.dart` | The student's cart: lines, quantities (never more than stock), total, points preview, no-plastic-bag choice. |
| `settings_view_model.dart` | Language (EN/BM), light/dark/auto mode, notifications on/off, saved on the phone. |
| `shop_map_view_model.dart` | "Find the koperasi": GPS permission state, your position, distance and walking time, nearest car/motorcycle parks. |

### 6.2 Student ViewModels (`viewmodels/student/`)

| File | Screen it serves | What it holds / does |
|---|---|---|
| `home_view_model.dart` | Home | Live products, Save Food deals, popular items, Hot Deal list, ready orders, "hide koperasi card" |
| `product_list_view_model.dart` | Product list | Live products + search, category, Save Food, in-stock filters |
| `product_detail_view_model.dart` | Product page | Live product, quantity, add to cart |
| `checkout_view_model.dart` | Cart | Turns the cart into a pre-order (pay at counter) |
| `my_orders_view_model.dart` | My Orders | Live orders grouped by status |
| `green_points_view_model.dart` | Green points | Points history, plastic bags / food / paper receipts saved |
| `budget_planner_view_model.dart` | AI Budget Planner | Categories, wishes, 3 combos, add a combo to the cart |

### 6.3 Staff ViewModels (`viewmodels/staff/`)

| File | Screen it serves | What it holds / does |
|---|---|---|
| `dashboard_view_model.dart` | Dashboard | Follows products, order queue and today's orders live → sales, pending/ready, low stock, near expiry; load sample products |
| `orders_queue_view_model.dart` | Orders queue | Pending/ready orders, accept & pack, collect, reject/cancel, cancel uncollected, spinner per order |
| `products_view_model.dart` | Products | All products, search, filters, hide/show |
| `product_form_view_model.dart` | Add / edit product | Category, expiry date (AI or picked), shown to students, generate `SK-` code, save |
| `stock_view_model.dart` | Stock in / out | Selected product (live), mode, reason, AI expiry date, save, recent history |
| `counter_sale_view_model.dart` | Counter sale | Its own cart, scanned items or member QR, checkout |
| `alerts_view_model.dart` | Alerts | Low stock and near expiry lists, start/end Save Food, write off expired |
| `reports_view_model.dart` | Reports | 7 / 30-day period, live orders and stock movements → `Report` (daily sales, top products, sustainability goals) |
| `staff_accounts_view_model.dart` | Staff accounts | Current staff, invited emails waiting to join, invite / remove |
| `more_view_model.dart` | More tab | Load sample products (and fill in missing descriptions) |
| `qr_label_view_model.dart` | QR label | One product (live) for its printable label |

### 6.4 Shared ViewModel (`viewmodels/common/`)

| File | Screens it serves | What it holds / does |
|---|---|---|
| `order_view_model.dart` | Order page, Digital receipt | One order (live), cancel while pending |

---

## 7. VIEW layer

### 7.1 Screens (`lib/screens/`) and their ViewModels

**Login and sign-up (`screens/auth/`)**, all using `AuthViewModel`:

| File | Page |
|---|---|
| `splash_screen.dart` | Opening animation (logo + loading ring, about 3.4 s) |
| `login_screen.dart` | Email + password login |
| `register_screen.dart` | Sign up as Student or Koperasi staff, password strength line |
| `forgot_password_screen.dart` | Reset link by email, animated tick, resend after 30 s |
| `profile_missing_screen.dart` | Finish profile / "Join as staff" |

**Student (`screens/student/`)**:

| File | Page | ViewModel |
|---|---|---|
| `student_shell.dart` | Bottom bar: Home, Scan, Orders, Profile | – |
| `home_screen.dart` | Home | `HomeViewModel` |
| `product_list_screen.dart` | Search / category list | `ProductListViewModel` |
| `product_detail_screen.dart` | Product page (3D picture, About, Add to cart) | `ProductDetailViewModel` + `CartViewModel` |
| `scan_screen.dart` | Scan a barcode | – (opens the product page) |
| `cart_screen.dart` | Cart and checkout | `CartViewModel` + `CheckoutViewModel` |
| `my_orders_screen.dart` | My Orders tabs | `MyOrdersViewModel` |
| `order_detail_screen.dart` | Order page with pickup QR | `OrderViewModel` |
| `green_points_screen.dart` | Green points | `GreenPointsViewModel` |
| `budget_planner_screen.dart` | AI Budget Planner | `BudgetPlannerViewModel` |

**Staff (`screens/staff/`)**:

| File | Page | ViewModel |
|---|---|---|
| `staff_shell.dart` | Bottom bar: Dashboard, Stock, Orders, Reports, More | – |
| `dashboard_screen.dart` | Dashboard | `DashboardViewModel` |
| `orders_queue_screen.dart` | Orders queue | `OrdersQueueViewModel` |
| `stock_screen.dart` | Stock in / out | `StockViewModel` |
| `products_screen.dart` | Products | `ProductsViewModel` |
| `product_form_screen.dart` | Add / edit product | `ProductFormViewModel` |
| `counter_sale_screen.dart` | Counter sale | `CounterSaleViewModel` |
| `alerts_screen.dart` | Alerts | `AlertsViewModel` |
| `reports_screen.dart` | Reports | `ReportsViewModel` |
| `staff_accounts_screen.dart` | Staff accounts | `StaffAccountsViewModel` |
| `more_screen.dart` | More tab | `MoreViewModel` + `AuthViewModel` |
| `qr_label_screen.dart` | QR label | `QrLabelViewModel` |

**Shared (`screens/common/`)**:

| File | Page | ViewModel |
|---|---|---|
| `profile_screen.dart` | Profile (photo, member QR, preferences) | `AuthViewModel` |
| `edit_profile_screen.dart` | Edit photo, name, ID, phone | `AuthViewModel` |
| `change_password_screen.dart` | Change password | `AuthViewModel` |
| `receipt_screen.dart` | Digital receipt | `OrderViewModel` |
| `shop_map_screen.dart` | Find the koperasi (map, GPS, nearest parking) | `ShopMapViewModel` |
| `settings_screen.dart` | About SmartShop | – |
| `scanner_page.dart` | Full-screen scanner that returns a code | – |

### 7.2 Widgets (`lib/widgets/`)

Reusable View pieces. They get their data from the screen (or the app-wide ViewModels), never from a service.

| File | What it provides |
|---|---|
| `product_widgets.dart` | Product card and tile, picture/emoji, 3D turning picture (`Product360`), stock badge, order status pill |
| `deal_widgets.dart` | Home's 3 category boxes and the Hot Deal advert |
| `brand.dart` | SmartShop logo, UTS crest, navy gradient button |
| `auth_layout.dart` | Layout of the login pages |
| `common.dart` | Loading, empty and error views, pills, stat cards, messages (`showSnack`), "Are you sure?" dialog |
| `motion.dart` | Small animations (fade in, press, count up, float) |
| `animated_tick.dart` | "Done" tick animation |
| `password_strength.dart` | Password strength line and checklist |
| `user_avatar.dart` | Profile photo / initials and the change-photo sheet |
| `preferences_card.dart` | Language, appearance, notifications card |
| `cart_button.dart` | Cart icon with count, green points chip |
| `receipt_view.dart` | Receipt layout |
| `scanner_view.dart` | Camera barcode/QR scanner |
| `product_picker.dart` | Search sheet to pick a product (list comes from the screen's ViewModel) |

### 7.3 Translations (`lib/l10n/`)

| File | What it does |
|---|---|
| `strings.dart` | `context.tr('English text')` → Malay when BM is chosen |
| `malay.dart` | 643 English → Bahasa Melayu entries |

---

## 8. Example: what happens when a student places an order

| Step | Layer | File | What happens |
|---|---|---|---|
| 1 | View | `cart_screen.dart` | Student taps **Place order** |
| 2 | ViewModel | `checkout_view_model.dart` | `placeOrder()` turns on the spinner (`run`), reads the cart and user |
| 3 | Model | `order_service.dart` | `placePreorder()` writes the order to Firestore (pending + pickup code) |
| 4 | ViewModel | `checkout_view_model.dart` | Empties the cart, returns the order ID |
| 5 | View | `cart_screen.dart` | Shows "Order placed!" and opens the order page |
| 6 | ViewModel | `orders_queue_view_model.dart` | On the staff phone, `follow()` receives the new order from Firestore live |
| 7 | View | `orders_queue_screen.dart` | The order appears in "To pack" by itself; the Dashboard's pending count goes up |

---

## 9. Tests (`test/`), 101 in total

| File | Tests | What it checks |
|---|---|---|
| `business_rules_test.dart` | 27 | Money, stock status, expiry, Save Food, points, cart limits, codes, pickup window |
| `expiry_parser_test.dart` | 15 | Reading expiry dates from scanned text |
| `budget_planner_test.dart` | 12 | AI Budget Planner combos, categories, wishes |
| `screens_test.dart` | 12 | **MVVM:** every student and staff screen opens with its ViewModel (fake services), no errors |
| `ui_test.dart` | 8 | Home categories and Hot Deal, Budget Planner (EN/BM), 3D picture, avatar, password line |
| `location_test.dart` | 6 | Distances, walking time, `ShopMapViewModel` with a fake GPS, map screen |
| `password_test.dart` | 6 | Password rules and strength |
| `translations_test.dart` | 5 | Every text has a Malay version |
| `view_model_test.dart` | 4 | **MVVM:** Dashboard numbers update live, orders-queue spinner, product filters, using fake services |
| `architecture_test.dart` | 3 | **MVVM rules:** Views never use services/Firebase; ViewModels have no UI code |
| `widget_test.dart` | 3 | Stock badge, Save Food tile, quantity buttons |

Run them all with `flutter test`.

---

## 10. Other folders

| Folder / file | What it is |
|---|---|
| `android/` | Android app settings: app ID `com.ssc.smartshop`, name, icon, permissions (internet, camera, notifications, location), Firebase file `google-services.json`, release build rules |
| `assets/images/uts_logo.png` | UTS crest on the login pages |
| `web/`, `windows/`, `linux/`, `macos/` | Made by Flutter for other platforms; not used (the app targets Android) |
| `firestore.rules` | Who may read/write what (students only see their own orders, only staff change products and stock) |
| `firestore.indexes.json` | Extra database indexes (none needed) |
| `firebase.json` | Firebase CLI settings and local emulator ports |
| `pubspec.yaml` / `pubspec.lock` | App name, version and packages (exact versions in the lock file) |
| `docs/` | This guide, report screenshots, UI sketches, proposal |

---

## 11. How to add a new screen the MVVM way

1. **Model:** if new data is needed, add a method to a service in `lib/services/` (only services talk to Firebase).
2. **ViewModel:** create `lib/viewmodels/<area>/my_view_model.dart` that `extends ViewModel`; use `follow()` for live data and `run()` for actions.
3. **View:** create `lib/screens/<area>/my_screen.dart`; read the data with `context.watch<MyViewModel>()` and call actions with `context.read<MyViewModel>()`.
4. **Wire it:** in `lib/core/router.dart` add a route with `_mvvm((c) => MyViewModel(c.read<SomeService>()), const MyScreen())`.
5. **Test:** add a ViewModel test with a fake service, and run `flutter test` (the architecture test will warn if a rule is broken).
