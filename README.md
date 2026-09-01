# 🏆 TK Office — Advanced Offline PDF & Office Suite

> **"Your Documents. Your Device."**

A complete, private, **100% offline Office & PDF Suite** built specifically for Android with **Flutter 3**, **Dart**, and **Material Design 3**.

---

## 👨‍💻 Developer & Contact

| Developer | Portfolio Website | Direct Email |
|---|---|---|
| **Tharun Kumar** | [tharunkumark4743.netlify.app](https://tharunkumark4743.netlify.app/) | [tharunkumark42007@gmail.com](mailto:tharunkumark42007@gmail.com) |

---

## 📱 Final Release Deliverable

| File | Location | Size | SHA-256 Checksum |
|---|---|---|---|
| **`TKOffice.apk`** | [`TKOffice.apk`](file:///c:/Users/tharu/Downloads/TK%20Suite/TKOffice.apk) | **69.67 MB** (73,057,811 bytes) | `3F848F48B3A2A3668F4A406FBEA077E799314D7EFBCCDE9BDAEC7A51B9B3A2FD` |

---

## 🏛️ System Architecture

TK Office follows a **Clean, Modular Architecture** with strict layer separation:

```
┌──────────────────────────────────────────────────────────────────────────┐
│                         PRESENTATION LAYER (UI)                          │
├──────────────┬──────────────┬──────────────┬──────────────┬──────────────┤
│  Home &      │  PDF Overlay │  Writer,     │  Conversion  │  Private     │
│  File Mgr    │  Editor &    │  Sheets &    │  Center &    │  Vault &     │
│  (Grid/List) │  Page Mgr    │  Slides      │  History     │  Settings    │
└──────────────┴──────────────┴──────────────┴──────────────┴──────────────┘
                                      │
                                      ▼
┌──────────────────────────────────────────────────────────────────────────┐
│                           CONTROLLERS & STATE                            │
├─────────────────────────────┬────────────────────────────────────────────┤
│  HomeController             │  SettingsController                        │
│  IndexedFilesDao            │  ConversionHistoryDao                      │
└─────────────────────────────┴────────────────────────────────────────────┘
                                      │
                                      ▼
┌──────────────────────────────────────────────────────────────────────────┐
│                        CORE DOMAIN & CONVERTERS                          │
├─────────────────┬─────────────────┬─────────────────┬────────────────────┤
│ Conversion      │ PDF Tools &     │ Docx, Xlsx &    │ Document Router    │
│ Service         │ Overlay Editor  │ Presentation    │ & Storage Scanner  │
│ (12 Converters) │ Service         │ Engines         │ Service            │
└─────────────────┴─────────────────┴─────────────────┴────────────────────┘
                                      │
                                      ▼
┌──────────────────────────────────────────────────────────────────────────┐
│                       OFFLINE ENGINES & PACKAGES                         │
├─────────────────┬─────────────────┬─────────────────┬────────────────────┤
│ syncfusion_pdf  │ pdfx (Render)   │ excel (XLSX)    │ archive (OpenXML)  │
│ pdf (Vector)    │ image (PNG/JPG) │ sqflite (Local) │ crypto (MD5 Cache) │
└─────────────────┴─────────────────┴─────────────────┴────────────────────┘
                                      │
                                      ▼
┌──────────────────────────────────────────────────────────────────────────┐
│                       ANDROID PLATFORM INTEGRATION                       │
├─────────────────────────────┬────────────────────────────────────────────┤
│ FlutterFragmentActivity     │ AndroidX BiometricPrompt (Fingerprint/PIN) │
│ MANAGE_EXTERNAL_STORAGE     │ ACTION_VIEW Intent Filters (17+ Formats)   │
└─────────────────────────────┴────────────────────────────────────────────┘
```

---

## 🔒 100% Offline & Privacy-First Principles

1. **Zero Internet Requirement:** No `android.permission.INTERNET` in release build; fully operational in Airplane Mode.
2. **Zero Cloud Services:** No Firebase, no Supabase, no Cloudinary, no Google Drive, no OneDrive, no remote databases.
3. **Zero Telemetry or Analytics:** No trackers, no ad networks, no data transmission.
4. **Hardware-Backed Biometrics:** Fingerprint / Face authentication verified locally on-device.
5. **Real All-Files Storage Access (`MANAGE_EXTERNAL_STORAGE`):** Discovers documents in `Download`, `Documents`, `WhatsApp Documents`, and external storage without cloud indexing.

---

## 💾 Universal Save-As & Live Dynamic Save Location Workflow

Every creation, export, and conversion operation passes through the Universal Save-As system:

```
SELECT INPUT FILE
       │
       ▼
EXECUTE LOCAL OFFLINE CONVERSION
       │
       ▼
WRITE TO APP TEMPORARY CACHE (cacheDir/conversions/<id>/)
       │
       ▼
STRICT OUTPUT VALIDATION (OutputValidator: size > 0, valid header/structure)
       │
       ▼
LIVE SAVE-AS DIALOG
├── Edit Filename (Sanitizer: no illegal chars, auto-extension: report.pdf never report.pdf.pdf)
└── Choose Save Destination:
    ├── 📥 Download (/storage/emulated/0/Download)
    ├── 📁 Documents (/storage/emulated/0/Documents)
    ├── 🖼️ Pictures (/storage/emulated/0/Pictures)
    ├── 💼 TK Office (/storage/emulated/0/Documents/TK Office)
    └── 📂 Browse Any Folder... (Interactive Folder Browser)
       │
       ▼
OVERWRITE COLLISION DETECTION (Replace / Save as New Name / Cancel)
       │
       ▼
MOVE FROM CACHE TO USER-CHOSEN DESTINATION & VERIFY FINAL FILE
       │
       ▼
RECORD IN RECENT FILES & SQLITE INDEX (WITH ACTUAL SAVED PATH)
       │
       ▼
CLEAN UP TEMPORARY CACHE FILES
       │
       ▼
SHOW SUCCESS DIALOG [Open in App / Share via Android / Done]
```

### Multi-File Batch Output Saving (`PDF → Images` & `PDF Split`):
- When converting a multi-page PDF into discrete image files (`file_page_001.png`, `file_page_002.png`, etc.) or splitting into multiple PDFs:
  - Displays a single batch save dialog showing total generated files.
  - User specifies a **Base Filename** (e.g. `SIH2026_page`).
  - User chooses the **Destination Folder** (`Download`, `Pictures`, `Documents`, `TK Office`, or custom).
  - All files are saved into that chosen destination in one tap.

---

## 📊 Complete Feature & Production Reality Matrix

| Feature | Category | Implementation Status | Offline Engine | Validated With Real File | Save Location |
|---|---|---|---|---|---|
| **Image → PDF** | Conversion | **PASS** | `pdf/widgets.dart` & `image` | YES | User Selected (`Download`, `Documents`, etc.) |
| **PDF → Images** | Conversion | **PASS** | Native `PdfRenderer` via `pdfx` | YES | User Selected Folder (`Download`, `Pictures`, etc.) |
| **PDF Merge** | PDF Tool | **PASS** | `syncfusion_flutter_pdf` | YES | User Selected (`Download`, `Documents`, etc.) |
| **PDF Split** | PDF Tool | **PASS** | `syncfusion_flutter_pdf` | YES | User Selected Folder (`Download`, `Documents`, etc.) |
| **PDF Delete Pages** | Page Manager | **PASS** | `syncfusion_flutter_pdf` | YES | User Selected (`Download`, `Documents`, etc.) |
| **PDF Rotate Pages** | Page Manager | **PASS** | `syncfusion_flutter_pdf` | YES | User Selected (`Download`, `Documents`, etc.) |
| **PDF Extract Pages** | Page Manager | **PASS** | `syncfusion_flutter_pdf` | YES | User Selected (`Download`, `Documents`, etc.) |
| **PDF Watermark** | PDF Tool | **PASS** | `syncfusion_flutter_pdf` | YES | User Selected (`Download`, `Documents`, etc.) |
| **PDF Protect / Encrypt** | Security | **PASS** | `syncfusion_flutter_pdf` | YES | User Selected (`Download`, `Documents`, etc.) |
| **PDF → Plain Text** | Conversion | **PASS** | `PdfTextExtractor` | YES | User Selected (`Download`, `Documents`, etc.) |
| **DOCX → PDF** | Conversion | **PASS** | OpenXML XML Parser + `pdf/widgets` | YES | User Selected (`Download`, `Documents`, etc.) |
| **XLSX → PDF** | Conversion | **PASS** | `excel` package + `pdf/widgets` | YES | User Selected (`Download`, `Documents`, etc.) |
| **PPTX → PDF** | Conversion | **PASS** | OpenXML XML Parser + `pdf/widgets` | YES | User Selected (`Download`, `Documents`, etc.) |
| **PDF → DOCX** | Conversion | **PASS** | `PdfTextExtractor` + `DocxService` | YES | User Selected (`Download`, `Documents`, etc.) |
| **PDF → XLSX** | Conversion | **PASS** | Tabular structure detector + `excel` | YES | User Selected (`Download`, `Documents`, etc.) |
| **PDF Overlay Editor** | Editor | **PASS (Overlay)** | `PdfBitmap` + Canvas bake | YES | User Selected (`Download`, `Documents`, etc.) |
| **TK Writer** | Editor | **PASS** | OpenXML DOCX / TXT / RTF | YES | User Selected / Default |
| **TK Sheets** | Editor | **PASS** | `excel` + Formula Engine | YES | User Selected / Default |
| **TK Slides** | Editor | **PASS** | OpenXML PPTX + Canvas | YES | User Selected / Default |
| **File Manager** | Storage | **PASS** | SQLite Index (`IndexedFilesDao`) | YES | Filter, Search, Tag, Multi-Select |

---

## ✍️ PDF Overlay Editor Details

The PDF Editor is an **Overlay-Based Editor**:
- **Tools Available:**
  - `+ Add Text`: Custom font size (8–48pt), bold, italic, text color, optional whiteout backing.
  - `+ Add Image`: Insert photos or stamps with drag/resize handles.
  - `✍ Draw Signature`: Finger-drawn electronic signature pad.
  - `Eraser / Whiteout Box`: Opaque white masking box to redact underlying text/graphics.
  - `Watermark`: Semi-transparent diagonal document stamps.
  - `Search`: Real-time text search with bounding box highlights.
  - `Undo / Redo`: Full undo and redo history for all placed elements.
- **How it Works:** Renders the PDF page raster, tracks editable overlay elements, and bakes them onto a clean vector PDF output upon saving.

---

## 📂 Supported Formats in Android "Open With"

Associated with **17+ document formats** in Android's `ACTION_VIEW` intent menu:

| Category | Extensions | Operations Supported |
|---|---|---|
| **PDF** | `.pdf` | View, Overlay Edit, Page Manage, Merge, Split, Compress, Protect, Convert |
| **Documents** | `.docx`, `.doc`, `.txt`, `.rtf`, `.odt` | View, Edit, Format, Print, Convert to PDF |
| **Spreadsheets** | `.xlsx`, `.xls`, `.csv`, `.ods` | View, Edit, Formulas, Multi-Sheet, Convert to PDF |
| **Presentations** | `.pptx`, `.ppt`, `.odp` | View, Edit, Slide Deck, Slideshow, Convert to PDF |
| **Images** | `.png`, `.jpg`, `.jpeg`, `.webp` | View, Convert to PDF, Embed in Documents |

---

## 🧪 Verification & Automated Testing

All test suites verify 100% offline correctness:

```powershell
flutter test --no-pub
```

```
00:02 +33: All tests passed!
```

### Test Suites Included:
- `production_audit_test.dart`: 10-page PDF page deletion, rotation, extraction, merge, split, DOCX/XLSX/PPTX vector conversion, OutputValidator checks, and dynamic location validation.
- `conversion_engine_test.dart`: Validates all 12 converters, SaveFileDialog sanitization, and output integrity.
- `productivity_security_test.dart`: Validates document tags, favorite queries, and thumbnail MD5 hashing.
- `storage_scanner_test.dart`: Validates storage discovery and extension classification.
- `document_router_test.dart`: Validates routing for all 17+ document formats.
- `formula_engine_test.dart`: Validates formula calculations (`SUM`, `AVERAGE`, `IF`, `CONCAT`, arithmetic).
- `docx_service_test.dart`: Validates DOCX OpenXML delta serialization and roundtrip export.
- `pdf_edit_test.dart`: Validates PDF whiteout and element serialization.
- `pdf_tools_test.dart`: Validates merge, split, delete, rotate, watermark, and password protection.
- `widget_test.dart`: Validates brand constants, developer email, and portfolio hyperlinks.

---

## 📲 Installation Instructions

1. Transfer **[`TKOffice.apk`](file:///c:/Users/tharu/Downloads/TK%20Suite/TKOffice.apk)** to your Android phone.
2. In your device's **Files** app, open **`TKOffice.apk`** and tap **Install / Update**.
3. Turn on **Airplane Mode** (disable Wi-Fi and Mobile Data).
4. Launch **TK Office** and enjoy a powerful, private, 100% offline document suite!

---

**Developed for Tharun Kumar**  
*TK Office — Your Documents. Your Device.*
