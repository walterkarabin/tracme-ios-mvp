# MVP TracMe

**mvp-tracme** is an iOS app (Xcode project **ClientServerBasic**) for capturing and tracking items—especially invoices—with optional OCR and backend sync.

## What it does

- **Authentication**: Login (including Google Sign-In) and token-based auth; deep-link handling for OAuth callbacks.
- **Dashboard**: Main navigation after login (e.g. link to Image OCR).
- **Images**: Capture or pick photos, run OCR (Vision), overlay text regions, upload image + extracted text to the API, then create an invoice from the processed data via `ProcessDataService`.
- **Invoices**: List and update invoices via `InvoiceService`; newly created invoices from the image flow are added to the in-memory list in `InvoiceStore`.

## Structure

- **ClientServerBasic/** – App entry (`ClientServerBasicApp.swift`), `ContentView`, assets, `Info.plist`.
- **Core/Networking/** – `APIClient` (shared URLSession/auth wrapper).
- **Domain/Models/** – `Invoice`, `User`, `Project` (and related types like `Item`, `Tax`).
- **Features/** – Feature modules:
  - **Authentication/** – `AuthManagerModel`, Google sign-in, `LoginView`, registration, Safari view.
  - **Dashboard/** – `DashboardView` (navigation hub).
  - **Images/** – `ImageStore` (state + dispatch: select → OCR → upload → create invoice), `ImageService`, `OCRService`, `ProcessDataService`, `ImageView`, camera/live scanner views.
  - **Invoices/** – `InvoiceStore` (list + add/update), `InvoiceService` (API).

## Key flow

1. User selects or captures an image in **ImageView**.
2. **ImageStore** runs OCR, uploads image and text, then calls `ProcessDataService` to create an **Invoice**.
3. On success, **ImageStore** dispatches `.invoiceCreated(invoice)` and forwards the invoice to **InvoiceStore**, which appends it to its list so the rest of the app sees the new invoice.
