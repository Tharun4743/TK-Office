# TK Office — Development Documentation

**Application Name:** TK Office  
**Tagline:** "Your Documents. Your Device."  
**Platform:** Android (100% Offline)  
**Package:** `com.tk.tk_office`  
**License:** Personal Offline Suite  

---

## 1. Architectural Principles & Security
- **Strict 100% Offline:** Zero remote APIs, zero cloud SDKs, zero telemetry, zero analytics, zero network permissions.
- **Local Data Only:** All documents are stored on device storage (`/data/user/0/...` and public Documents folder via Android Storage Access Framework).
- **Macro Execution Blocker:** All Office documents (DOCX, XLSX, PPTX) are parsed purely for structure/data/visual elements; macro execution is strictly forbidden and ignored.
- **Safe Overwrite / Confirmations:** Destructive file operations (Delete, Overwrite, Replace) always prompt for explicit user confirmation.

---

## 2. Dependencies & Licenses

| Package | Version | License | Processing Mode |
|---|---|---|---|
| `flutter_quill` | 11.5.1 | MIT | 100% Local / In-memory |
| `excel` | 4.0.6 | MIT | 100% Local / Pure Dart |
| `csv` | 6.0.0 | MIT | 100% Local / Pure Dart |
| `pdfrx` | 2.4.5 | MIT | 100% Local / PDFium native |
| `pdf` | 3.12.0 | Apache 2.0 | 100% Local / Pure Dart |
| `printing` | 5.14.3 | Apache 2.0 | 100% Local / Android PrintManager |
| `sqflite` | 2.4.3 | BSD-2-Clause | 100% Local SQLite |
| `provider` | 6.1.5 | MIT | 100% Local State |
| `path_provider` | 2.1.6 | BSD-3-Clause | 100% Local SAF / File system |
| `file_picker` | 8.3.7 | MIT | Android SAF (Storage Access Framework) |
| `share_plus` | 10.1.4 | BSD-3-Clause | Android Intent (ACTION_SEND) |
| `shared_preferences` | 2.5.5 | BSD-3-Clause | Android SharedPreferences |
| `open_file` | 3.5.11 | BSD-3-Clause | Android File Provider Intent |
| `archive` | 3.6.1 | Apache 2.0 | 100% Local Zip Engine |
| `xml` | 6.6.1 | MIT | 100% Local XML Parser |

---

## 3. Implemented Modules

### 3.1 Core & Dashboard (Phase 1)
- Material 3 theme with dynamic color schemes (Dark, Light, System).
- Custom dashboard with brand identity (`TharunKumar.jpeg`), quick action cards for New Document, New Spreadsheet, New Presentation, Open PDF.
- Categorized Recent Files list (All, Documents, Spreadsheets, Presentations, PDFs) with SQLite persistence.
- Settings management: theme switching, default fonts, autosave frequency, storage management, and cache clearing.
- Local File Manager: explore local folders, search, sort (date, name, size), rename, delete, duplicate, share.

### 3.2 Writer (Phase 2)
- WYSIWYG rich text editor with Quill Delta representation.
- Format styling: Bold, Italic, Underline, Strikethrough, Color, Background Highlight, Font Family, Font Size.
- Paragraph styling: Left, Center, Right, Justify, Bullet list, Numbered list, Indent, Outdent, Headings (H1–H6).
- Document features: Insert Tables, Images, Hyperlinks, Horizontal Rules, Page breaks.
- Local I/O: Native Delta JSON, Plain Text (`.txt`), Rich Text (`.rtf`), and OpenXML DOCX generation/parsing.
- Export to high-quality PDF via vector rendering & Android direct print.
- Undo, Redo, Find & Replace with match counter.

### 3.3 Sheets (Phase 3)
- Offline multi-sheet spreadsheet editor.
- High performance grid with smooth bi-directional scrolling and cell selection.
- Formula bar with live formula evaluation.
- Multi-sheet management: Add, Delete, Rename, Duplicate tabs.
- Custom Formula Engine supporting:
  - `SUM`, `AVERAGE`, `MIN`, `MAX`, `COUNT`, `COUNTA`
  - `IF`, `AND`, `OR`
  - `ROUND`, `ABS`, `INT`
  - `VLOOKUP`, `XLOOKUP`
  - `CONCAT`, `LEFT`, `RIGHT`, `MID`, `LEN`, `UPPER`, `LOWER`, `TRIM`
- Full XLSX import/export via pure Dart `excel` package & CSV import/export.
- Cell formatting: Bold, Italic, Text Color, Background Color, Alignment, Borders, Number Formats (Currency, Percent, Decimal, Date).

### 3.4 Slides (Phase 4)
- Touch-optimized presentation creator and editor.
- Interactive slide canvas with multi-element manipulation: Text Boxes, Images, Shapes (Rectangles, Circles, Arrows, Stars), Tables.
- Slide thumbnail sidebar with drag/touch reordering, add, duplicate, delete.
- Slide layout templates (Title, Title & Content, Two Content, Blank).
- Fullscreen Presentation Mode with touch slide-advance and presenter controls.
- PPTX export and Slide-to-PDF export.

### 3.5 PDF Viewer & Annotator (Phase 5)
- Fast local PDF rendering powered by PDFium (`pdfrx`).
- Page thumbnail strip, page jumping, zoom controls, fit width/page, search.
- Annotation overlay: Freehand ink drawing, Highlight, Underline, Strikethrough, Text annotations, Shapes, Signature drawing pad.
- PDF Page Manager: Rotate pages, Delete pages, Reorder pages, Merge multiple PDFs, Split PDF into separate documents.
- Print PDF via Android Print Framework.

### 3.6 Local Conversions, Autosave & Recovery (Phase 6)
- Local offline converter:
  - DOCX / Text / RTF → PDF
  - XLSX / CSV → PDF
  - PPTX / Slides → PDF
- Debounced autosave engine saving recovery snapshots in SQLite + local storage.
- Crash recovery prompt on application startup ("Recovered Documents").

---

## 4. Current Limitations
- Complex Microsoft Word VBA macros are intentionally ignored for security and sandboxing.
- Embedded 3D charts in XLSX are rendered in table format.
- Complex SmartArt in PPTX is flattened to standard vector shapes.
