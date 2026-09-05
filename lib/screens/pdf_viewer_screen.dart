import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_pdfview/flutter_pdfview.dart';
import '../services/recent_service.dart';

class PdfViewerScreen extends StatefulWidget {
  final String path;
  final String name;
  final int initialPage;

  const PdfViewerScreen({
    super.key,
    required this.path,
    required this.name,
    this.initialPage = 0,
  });

  @override
  State<PdfViewerScreen> createState() => _PdfViewerScreenState();
}

class _PdfViewerScreenState extends State<PdfViewerScreen> {
  PDFViewController? _pdfViewController;

  int _totalPages = 0;
  late int _currentPage;
  bool _isReady = false;
  String _errorMessage = '';
  bool _isNightMode = false;
  bool _isSwipeHorizontal = false;
  bool _isImmersive = false;

  @override
  void initState() {
    super.initState();
    _currentPage = widget.initialPage;
    RecentService.addOrUpdateRecent(
      path: widget.path,
      name: widget.name,
      lastPage: _currentPage + 1,
    );
  }

  @override
  void dispose() {
    if (_isImmersive) {
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    }
    super.dispose();
  }

  void _toggleImmersive() {
    setState(() {
      _isImmersive = !_isImmersive;
    });
    if (_isImmersive) {
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    } else {
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: _isNightMode ? Colors.black87 : theme.colorScheme.surface,
      appBar: _isImmersive
          ? null
          : AppBar(
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
                  tooltip: _isNightMode ? 'Modo claro' : 'Modo nocturno',
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
                IconButton(
                  icon: const Icon(Icons.fullscreen),
                  tooltip: 'Pantalla completa',
                  onPressed: _toggleImmersive,
                ),
              ],
            ),
      body: Stack(
        children: [
          PDFView(
            key: ValueKey('$_isNightMode-$_isSwipeHorizontal'),
            filePath: widget.path,
            enableSwipe: true,
            swipeHorizontal: _isSwipeHorizontal,
            autoSpacing: true,
            pageFling: true,
            pageSnap: true,
            nightMode: _isNightMode,
            defaultPage: _currentPage,
            fitPolicy: FitPolicy.WIDTH,
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
              _pdfViewController = pdfViewController;
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
          if (_isImmersive && _isReady)
            Positioned(
              bottom: 24,
              right: 16,
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: BorderRadius.circular(24),
                  onTap: _toggleImmersive,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.7),
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: Colors.white24),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.fullscreen_exit, color: Colors.white, size: 20),
                        const SizedBox(width: 6),
                        Text(
                          '${_currentPage + 1} / $_totalPages',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
      bottomNavigationBar: (_isReady && !_isImmersive)
          ? SafeArea(
              top: false,
              child: Container(
                color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.95),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    TextButton.icon(
                      onPressed: () {
                        if (_currentPage > 0) {
                          _pdfViewController?.setPage(_currentPage - 1);
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
                                  onPressed: () {
                                    final pageNum =
                                        int.tryParse(textController.text);
                                    if (pageNum != null &&
                                        pageNum >= 1 &&
                                        pageNum <= _totalPages) {
                                      _pdfViewController?.setPage(pageNum - 1);
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
                      onPressed: () {
                        if (_currentPage < _totalPages - 1) {
                          _pdfViewController?.setPage(_currentPage + 1);
                        }
                      },
                      icon: const Icon(Icons.chevron_right),
                      label: const Text('Siguiente'),
                    ),
                  ],
                ),
              ),
            )
          : null,
    );
  }
}
