import 'package:ereader/providers/reader_settings_provider.dart';
import 'package:ereader/providers/theme_provider.dart';
import 'package:flutter/material.dart';
import 'package:pdfrx/pdfrx.dart';
import 'package:provider/provider.dart';
import 'reader_viewer_controller.dart';

class PdfController extends StatefulWidget {
  final String filePath;
  final void Function(double percentage, String pageNum) onLocationChanged;
  final void Function(ReaderViewerController)? onViewerCreated;
  final int startPage;

  const PdfController({
    super.key,
    required this.filePath,
    required this.onLocationChanged,
    this.startPage = 1,
    this.onViewerCreated,
  });

  @override
  PdfControllerState createState() => PdfControllerState();
}

class PdfControllerState extends State<PdfController>
    implements ReaderViewerController {
  late PdfDocumentRef _document;
  late PdfViewerController _pdfController;
  int _totalPages = 0;
  int _currentPage = 1;
  bool _documentLoaded = false;

  List<Map<String, dynamic>> tocJson = [];

  @override
  void initState() {
    super.initState();
    _initPdf();
    // Expose this controller to the parent after the first frame.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (widget.onViewerCreated != null) {
        widget.onViewerCreated!(this);
      }
    });
  }

  Future<void> _initPdf() async {
    // Use the pdfrx API to open the PDF from file.
    _document = await PdfDocumentRefFile(widget.filePath);
    // Create a new controller for the viewer.
    _pdfController = PdfViewerController();
    setState(() {
      _documentLoaded = true;
    });
  }

  //Function to contruct toc json from a list of PdfOutlineNodes
  //where the json is a list of objects with the following structure:
  // {
  //   "label": "Chapter 1",
  //   "loc": "cfi:1",
  //   "depth": 0,
  // }
  List<Map<String, dynamic>> _constructTocJson(
    List<PdfOutlineNode> nodes, {
    int depth = 0,
  }) {
    List<Map<String, dynamic>> tocList = [];
    for (var node in nodes) {
      Map<String, dynamic> tocItem = {
        'label': node.title,
        'loc': node.dest?.pageNumber ?? 0,
        'depth': depth,
      };
      tocList.add(tocItem);
      if (node.children.isNotEmpty) {
        tocList = tocList + _constructTocJson(node.children, depth: depth + 1);
      }
    }
    return tocList;
  }

  @override
  Widget build(BuildContext context) {
    context.watch<ThemeProvider>();
    context.watch<ReaderSettingsProvider>();

    if (!_documentLoaded) {
      return const Center(child: CircularProgressIndicator());
    }
    return ColorFiltered(
      //check if the theme is dark or light
      //and set the color filter accordingly
      colorFilter: ColorFilter.mode(
        Theme.of(context).scaffoldBackgroundColor,
        Theme.of(context).brightness == Brightness.dark
            ? BlendMode.difference
            : BlendMode.dst,
      ),
      child: PdfViewer(
        // pdfrx’s PdfViewer takes the document reference and controller.
        _document,
        controller: _pdfController,
        initialPageNumber: widget.startPage,
        params: PdfViewerParams(
          backgroundColor: Theme.of(context).scaffoldBackgroundColor,
          margin: 0.0,
          onPageChanged: (pageNumber) {
            setState(() {
              _currentPage = pageNumber!;
            });
            widget.onLocationChanged(
              pageNumber!.toDouble() / _totalPages,
              "$pageNumber",
            );
          },
          onViewerReady: (document, controller) async {
            _totalPages = controller.pageCount;
            tocJson = _constructTocJson(await document.loadOutline());
          },
        ),
      ),
    );
  }

  @override
  Future<void> nextPage() async {
    if (_currentPage < _totalPages) {
      final pageNumber = _pdfController.pageNumber;
      if (pageNumber != null) {
        await _pdfController.goToPage(pageNumber: pageNumber + 1);
        _currentPage++;
      }
    }
  }

  @override
  Future<void> previousPage() async {
    if (_currentPage > 1) {
      final pageNumber = _pdfController.pageNumber;
      if (pageNumber != null) {
        await _pdfController.goToPage(pageNumber: pageNumber - 1);
        _currentPage--;
      }
    }
  }

  @override
  Future<void> navigateToCfi(String cfi) async {
    // Not applicable for PDFs.
    throw UnimplementedError("navigateToCfi is not supported for PDF");
  }

  @override
  Future<void> navigateToPercentage(double percentage) async {
    if (_totalPages == 0) return;
    final targetPage = (percentage * _totalPages).ceil();
    _currentPage = targetPage.clamp(1, _totalPages);
    await _pdfController.goToPage(pageNumber: _currentPage);
  }

  @override
  Future<void> navigateToTocEntry(String loc) async {
    throw UnimplementedError("navigateToHref is not supported for PDF");
  }

  @override
  Future<List<Map<String, dynamic>>> getTocJson() async {
    return tocJson;
  }

  @override
  void dispose() {
    super.dispose();
  }
}
