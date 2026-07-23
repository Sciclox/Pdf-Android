import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_pdfview/flutter_pdfview.dart';
import '../services/recent_service.dart';

class PdfViewerScreen extends StatefulWidget {
  final String path;
  final String name;

  const PdfViewerScreen({
    super.key,
    required this.path,
    required this.name,
  });

  @override
  State<PdfViewerScreen> createState() => _PdfViewerScreenState();
}

class _PdfViewerScreenState extends State<PdfViewerScreen> {
  final Completer<PDFViewController> _controllerCompleter =
      Completer<PDFViewController>();

  int _totalPages = 0;
  int _currentPage = 0;
  bool _isReady = false;
  String _errorMessage = '';
  bool _isNightMode = false;
  bool _isSwipeHorizontal = false;

  @override
  void initState() {
    super.initState();
    // Register initial opening
    RecentService.addOrUpdateRecent(
      path: widget.path,
      name: widget.name,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: _isNightMode ? Colors.black87 : theme.colorScheme.surface,
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.name,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              overflow: TextOverflow.ellipsis,
            ),
            if (_isReady)
              Text(
                'Página ${_currentPage + 1} de $_totalPages',
                style: TextStyle(
                  fontSize: 12,
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                ),
              ),
          ],
        ),
        actions: [
          IconButton(
            icon: Icon(
              _isNightMode ? Icons.dark_mode : Icons.light_mode,
            ),
            tooltip: 'Modo nocturno',
            onPressed: () {
              setState(() {
                _isNightMode = !_isNightMode;
              });
            },
          ),
          IconButton(
            icon: Icon(
              _isSwipeHorizontal ? Icons.swap_horiz : Icons.swap_vert,
            ),
            tooltip: _isSwipeHorizontal ? 'Navegación horizontal' : 'Navegación vertical',
            onPressed: () {
              setState(() {
                _isSwipeHorizontal = !_isSwipeHorizontal;
              });
            },
          ),
        ],
      ),
      body: Stack(
        children: [
          PDFView(
            filePath: widget.path,
            enableSwipe: true,
            swipeHorizontal: _isSwipeHorizontal,
            autoSpacing: true,
            pageFling: true,
            pageSnap: true,
            nightMode: _isNightMode,
            onError: (error) {
              setState(() {
                _errorMessage = error.toString();
              });
            },
            onPageError: (page, error) {
              setState(() {
                _errorMessage = 'Página $page: ${error.toString()}';
              });
            },
            onViewCreated: (PDFViewController pdfViewController) {
              if (!_controllerCompleter.isCompleted) {
                _controllerCompleter.complete(pdfViewController);
              }
            },
            onRender: (pages) {
              setState(() {
                _totalPages = pages ?? 0;
                _isReady = true;
              });
              if (pages != null) {
                RecentService.addOrUpdateRecent(
                  path: widget.path,
                  name: widget.name,
                  totalPages: pages,
                  lastPage: _currentPage + 1,
                );
              }
            },
            onPageChanged: (page, total) {
              if (page != null) {
                setState(() {
                  _currentPage = page;
                });
                RecentService.addOrUpdateRecent(
                  path: widget.path,
                  name: widget.name,
                  totalPages: total ?? _totalPages,
                  lastPage: page + 1,
                );
              }
            },
          ),
          if (!_isReady && _errorMessage.isEmpty)
            const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('Cargando PDF...'),
                ],
              ),
            ),
          if (_errorMessage.isNotEmpty)
            Center(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.error_outline, color: Colors.red, size: 48),
                    const SizedBox(height: 12),
                    Text(
                      'Error al abrir el PDF:\n$_errorMessage',
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.red),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
      bottomNavigationBar: _isReady
          ? Container(
              color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.9),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  TextButton.icon(
                    onPressed: () async {
                      if (_currentPage > 0) {
                        final controller = await _controllerCompleter.future;
                        controller.setPage(_currentPage - 1);
                      }
                    },
                    icon: const Icon(Icons.chevron_left),
                    label: const Text('Anterior'),
                  ),
                  InkWell(
                    onTap: () {
                      final textController =
                          TextEditingController(text: '${_currentPage + 1}');
                      showDialog(
                        context: context,
                        builder: (context) {
                          return AlertDialog(
                            title: const Text('Ir a página'),
                            content: TextField(
                              controller: textController,
                              keyboardType: TextInputType.number,
                              autofocus: true,
                              decoration: InputDecoration(
                                labelText: 'Número de página (1 - $_totalPages)',
                                border: const OutlineInputBorder(),
                              ),
                            ),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(context),
                                child: const Text('Cancelar'),
                              ),
                              ElevatedButton(
                                onPressed: () async {
                                  final pageNum =
                                      int.tryParse(textController.text);
                                  if (pageNum != null &&
                                      pageNum >= 1 &&
                                      pageNum <= _totalPages) {
                                    final controller =
                                        await _controllerCompleter.future;
                                    controller.setPage(pageNum - 1);
                                    if (context.mounted) Navigator.pop(context);
                                  }
                                },
                                child: const Text('Ir'),
                              ),
                            ],
                          );
                        },
                      );
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.primaryContainer,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Text(
                        '${_currentPage + 1} / $_totalPages',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: theme.colorScheme.onPrimaryContainer,
                        ),
                      ),
                    ),
                  ),
                  TextButton.icon(
                    onPressed: () async {
                      if (_currentPage < _totalPages - 1) {
                        final controller = await _controllerCompleter.future;
                        controller.setPage(_currentPage + 1);
                      }
                    },
                    icon: const Icon(Icons.chevron_right),
                    label: const Text('Siguiente'),
                  ),
                ],
              ),
            )
          : null,
    );
  }
}
