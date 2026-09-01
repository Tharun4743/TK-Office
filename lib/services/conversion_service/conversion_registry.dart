class ConversionOption {
  final String id;
  final String title;
  final String subtitle;
  final String fromFormat;
  final String toFormat;
  final String targetExtension;
  final bool isSupported;
  final String iconName;

  const ConversionOption({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.fromFormat,
    required this.toFormat,
    required this.targetExtension,
    required this.isSupported,
    required this.iconName,
  });
}

class ConversionRegistry {
  static const List<ConversionOption> allOptions = [
    // PDF Conversions
    ConversionOption(
      id: 'pdf_to_docx',
      title: 'PDF → Word',
      subtitle: 'Convert to DOCX Document',
      fromFormat: 'PDF',
      toFormat: 'DOCX',
      targetExtension: '.docx',
      isSupported: true,
      iconName: 'article',
    ),
    ConversionOption(
      id: 'pdf_to_xlsx',
      title: 'PDF → Excel',
      subtitle: 'Extract Tables to XLSX',
      fromFormat: 'PDF',
      toFormat: 'XLSX',
      targetExtension: '.xlsx',
      isSupported: true,
      iconName: 'table_chart',
    ),
    ConversionOption(
      id: 'pdf_to_txt',
      title: 'PDF → Text',
      subtitle: 'Extract Plain Text (.txt)',
      fromFormat: 'PDF',
      toFormat: 'TXT',
      targetExtension: '.txt',
      isSupported: true,
      iconName: 'text_snippet',
    ),
    ConversionOption(
      id: 'pdf_to_images',
      title: 'PDF → Images',
      subtitle: 'Export PNG / JPG Pages',
      fromFormat: 'PDF',
      toFormat: 'PNG',
      targetExtension: '.png',
      isSupported: true,
      iconName: 'image',
    ),

    // Create PDF Conversions
    ConversionOption(
      id: 'docx_to_pdf',
      title: 'Word → PDF',
      subtitle: 'Convert DOCX to Vector PDF',
      fromFormat: 'DOCX',
      toFormat: 'PDF',
      targetExtension: '.pdf',
      isSupported: true,
      iconName: 'description',
    ),
    ConversionOption(
      id: 'xlsx_to_pdf',
      title: 'Excel → PDF',
      subtitle: 'Convert Spreadsheet to PDF',
      fromFormat: 'XLSX',
      toFormat: 'PDF',
      targetExtension: '.pdf',
      isSupported: true,
      iconName: 'table_view',
    ),
    ConversionOption(
      id: 'pptx_to_pdf',
      title: 'PowerPoint → PDF',
      subtitle: 'Convert Slides Deck to PDF',
      fromFormat: 'PPTX',
      toFormat: 'PDF',
      targetExtension: '.pdf',
      isSupported: true,
      iconName: 'slideshow',
    ),
    ConversionOption(
      id: 'images_to_pdf',
      title: 'Images → PDF',
      subtitle: 'Combine Photos into PDF',
      fromFormat: 'Images',
      toFormat: 'PDF',
      targetExtension: '.pdf',
      isSupported: true,
      iconName: 'photo_library',
    ),

    // PDF Utilities
    ConversionOption(
      id: 'pdf_merge',
      title: 'Merge PDFs',
      subtitle: 'Combine Multiple PDFs',
      fromFormat: 'PDF',
      toFormat: 'PDF',
      targetExtension: '.pdf',
      isSupported: true,
      iconName: 'merge_type',
    ),
    ConversionOption(
      id: 'pdf_split',
      title: 'Split PDF',
      subtitle: 'Extract Page Ranges',
      fromFormat: 'PDF',
      toFormat: 'PDF',
      targetExtension: '.pdf',
      isSupported: true,
      iconName: 'call_split',
    ),
    ConversionOption(
      id: 'pdf_compress',
      title: 'Compress PDF',
      subtitle: 'Reduce File Size',
      fromFormat: 'PDF',
      toFormat: 'PDF',
      targetExtension: '.pdf',
      isSupported: true,
      iconName: 'compress',
    ),
    ConversionOption(
      id: 'pdf_protect',
      title: 'Protect PDF',
      subtitle: 'Password Encrypt Document',
      fromFormat: 'PDF',
      toFormat: 'PDF',
      targetExtension: '.pdf',
      isSupported: true,
      iconName: 'lock',
    ),
  ];
}
