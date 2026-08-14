part of '../main.dart';

typedef LegalDocumentLoader = Future<LegalDocument> Function();

class LegalDocumentPage extends StatefulWidget {
  const LegalDocumentPage({
    super.key,
    required this.documentId,
    required this.fallbackTitle,
    this.loader,
  });

  final String documentId;
  final String fallbackTitle;
  final LegalDocumentLoader? loader;

  @override
  State<LegalDocumentPage> createState() => _LegalDocumentPageState();
}

class _LegalDocumentPageState extends State<LegalDocumentPage> {
  late Future<LegalDocument> _documentFuture;

  @override
  void initState() {
    super.initState();
    _loadDocument();
  }

  void _loadDocument() {
    _documentFuture =
        widget.loader?.call() ??
        LegalDocumentService().getDocument(widget.documentId);
  }

  void _retry() {
    setState(_loadDocument);
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<LegalDocument>(
      future: _documentFuture,
      builder: (context, snapshot) {
        final document = snapshot.data;
        return Scaffold(
          backgroundColor: AppColors.pageBackground,
          appBar: AppBar(
            title: Text(
              document?.title.isNotEmpty == true
                  ? document!.title
                  : widget.fallbackTitle,
              style: const TextStyle(fontWeight: FontWeight.w900),
            ),
            backgroundColor: AppColors.pageBackground,
            surfaceTintColor: Colors.transparent,
          ),
          body: SafeArea(top: false, child: _buildBody(snapshot)),
        );
      },
    );
  }

  Widget _buildBody(AsyncSnapshot<LegalDocument> snapshot) {
    if (snapshot.connectionState != ConnectionState.done) {
      return const Center(child: CircularProgressIndicator());
    }
    if (snapshot.hasError || snapshot.data == null) {
      return _LegalDocumentError(
        message: _errorMessage(snapshot.error),
        onRetry: _retry,
      );
    }

    final document = snapshot.data!;
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(22, 18, 22, 40),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 820),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(22, 24, 22, 26),
            decoration: _clayDecoration(
              color: Colors.white,
              radius: 24,
              shadowColor: const Color(0xFFC7CBDD),
            ),
            child: SelectionArea(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SelectableText(
                    document.content,
                    style: const TextStyle(
                      color: Color(0xFF292D38),
                      fontSize: 15,
                      height: 1.65,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  if (document.version.isNotEmpty ||
                      document.effectiveDate.isNotEmpty) ...[
                    const SizedBox(height: 28),
                    const Divider(height: 1),
                    const SizedBox(height: 16),
                    Text(
                      [
                        if (document.version.isNotEmpty)
                          '버전 ${document.version}',
                        if (document.effectiveDate.isNotEmpty)
                          '시행일 ${document.effectiveDate}',
                      ].join('  ·  '),
                      style: const TextStyle(
                        color: _muted,
                        fontSize: 13,
                        height: 1.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  String _errorMessage(Object? error) {
    if (error is LegalDocumentUnavailableException &&
        error.reason == LegalDocumentUnavailableReason.inactive) {
      return '현재 문서를 확인할 수 없습니다.';
    }
    return '문서를 불러오지 못했어요.\n인터넷 연결을 확인하고 다시 시도해 주세요.';
  }
}

class _LegalDocumentError extends StatelessWidget {
  const _LegalDocumentError({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 440),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.all(24),
            decoration: _clayDecoration(
              color: Colors.white,
              radius: 24,
              shadowColor: const Color(0xFFC7CBDD),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.description_outlined, color: _muted, size: 34),
                const SizedBox(height: 14),
                Text(
                  message,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Color(0xFF343841),
                    fontSize: 15,
                    height: 1.55,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 20),
                FilledButton(
                  onPressed: onRetry,
                  style: FilledButton.styleFrom(
                    backgroundColor: _blue,
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('다시 시도'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
