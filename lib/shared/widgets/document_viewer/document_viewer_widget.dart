import 'dart:io';

import 'package:flutter/material.dart';
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../../../core/utils/app_loader.dart';
import '../../../core/utils/utils.dart';
import '../app_text.dart';
import '../appbars/title_appbar.dart';

class DocumentViewerPage extends StatefulWidget {
  final String fileUrl;
  final String? fileName;
  final bool isAllowInAppDownload;

  const DocumentViewerPage({
    super.key,
    required this.fileUrl,
    this.fileName,
    this.isAllowInAppDownload = false,
  });

  @override
  State<DocumentViewerPage> createState() => _DocumentViewerPageState();
}

class _DocumentViewerPageState extends State<DocumentViewerPage> {
  late final String extension;
  WebViewController? _webViewController;

  bool get isNetworkFile =>
      widget.fileUrl.startsWith('http://') ||
      widget.fileUrl.startsWith('https://');

  @override
  void initState() {
    super.initState();

    extension = widget.fileUrl.split('.').last.toLowerCase();

    /// Setup WebView only for DOC/DOCX network files
    if ((extension == 'doc' || extension == 'docx') && isNetworkFile) {
      final googleDocsUrl =
          "https://docs.google.com/gview?embedded=true&url=${Uri.encodeComponent(widget.fileUrl)}";

      _webViewController = WebViewController()
        ..setJavaScriptMode(JavaScriptMode.unrestricted)
        ..loadRequest(Uri.parse(googleDocsUrl));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: titleAppBar(
        height: kToolbarHeight + 20,
        context: context,
        title: widget.fileName ?? "Documents Viewer",
        actionIcon: widget.isAllowInAppDownload ? Icons.download : null,
        onPressedAction: widget.isAllowInAppDownload
            ? () async {
                await openUrl(isExternal: true, url: widget.fileUrl);
              }
            : null,
      ),
      body: _buildViewer(),
    );
  }

  Widget _buildViewer() {
    /// ===============================
    /// ✅ PDF SUPPORT
    /// ===============================
    if (extension == 'pdf') {
      return isNetworkFile
          ? SfPdfViewer.network(widget.fileUrl)
          : SfPdfViewer.file(File(widget.fileUrl));
    }

    /// ===============================
    /// ✅ IMAGE SUPPORT
    /// ===============================
    if (extension == 'jpg' || extension == 'jpeg' || extension == 'png') {
      return InteractiveViewer(
        child: Center(
          child: isNetworkFile
              ? Image.network(
                  widget.fileUrl,
                  fit: BoxFit.contain,
                  loadingBuilder: (context, child, progress) {
                    if (progress == null) return child;
                    return const Center(child: LoaderWidget());
                  },
                  errorBuilder: (context, error, stackTrace) {
                    return const Center(child: Text("Failed to load image"));
                  },
                )
              : Image.file(
                  File(widget.fileUrl),
                  fit: BoxFit.contain,
                  errorBuilder: (context, error, stackTrace) {
                    return const Center(child: Text("Failed to load image"));
                  },
                ),
        ),
      );
    }

    /// ===============================
    /// ✅ DOC / DOCX SUPPORT
    /// ===============================
    if (extension == 'doc' || extension == 'docx') {
      if (isNetworkFile && _webViewController != null) {
        return WebViewWidget(controller: _webViewController!);
      }

      return const Center(
        child: Text(
          "DOC/DOCX preview is only supported for online files.\nPlease upload the file to server first.",
          textAlign: TextAlign.center,
        ),
      );
    }

    /// ===============================
    /// ❌ UNSUPPORTED
    /// ===============================
    return const Center(
      child: AppText(
        text: "Unsupported file format!",
        fontSize: 16,
        fontWeight: FontWeight.w500,
      ),
    );
  }
}
