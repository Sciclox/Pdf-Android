import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path/path.dart' as p;
import 'package:app_links/app_links.dart';
import '../models/recent_pdf.dart';
import '../services/recent_service.dart';
import 'pdf_viewer_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  List<RecentPdf> _recents = [];
  List<RecentPdf> _filteredRecents = [];
  bool _isLoading = true;
  final TextEditingController _searchController = TextEditingController();
  final _appLinks = AppLinks();
  StreamSubscription<Uri>? _linkSubscription;
  static const _channel = MethodChannel('com.example.pdfreader/content_resolver');

  @override
  void initState() {
    super.initState();
    _loadRecents();
    _initAppLinks();
  }

  @override
  void dispose() {
    _linkSubscription?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _initAppLinks() async {
    // Escuchar enlaces entrantes mientras la app está abierta
    _linkSubscription = _appLinks.uriLinkStream.listen((uri) {
      _handleIncomingUri(uri);
    });

    // Procesar el enlace inicial al abrir la app desde WhatsApp o archivos
    try {
      final initialUri = await _appLinks.getInitialLink();
      if (initialUri != null) {
        _handleIncomingUri(initialUri);
      }
    } catch (e) {
      debugPrint('Error obteniendo enlace inicial: $e');
    }
  }

  Future<void> _handleIncomingUri(Uri uri) async {
    String? filePath;
    String fileName = 'Documento PDF';

    if (uri.scheme == 'file') {
      filePath = uri.toFilePath();
      fileName = p.basename(filePath);
    } else if (uri.scheme == 'content') {
      try {
        final String? cachedPath = await _channel
            .invokeMethod('copyContentUriToCache', {'uri': uri.toString()});
        if (cachedPath != null && cachedPath.isNotEmpty) {
          filePath = cachedPath;
          fileName = 'Documento WhatsApp.pdf';
        }
      } catch (e) {
        debugPrint('Error resolviendo URI content://: $e');
      }
    }

    if (filePath != null && mounted) {
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => PdfViewerScreen(
            path: filePath!,
            name: fileName,
          ),
        ),
      );
      _loadRecents();
    }
  }

  Future<void> _loadRecents() async {
    setState(() => _isLoading = true);
    final recents = await RecentService.getRecents();
    setState(() {
      _recents = recents;
      _filterRecents(_searchController.text);
      _isLoading = false;
    });
  }

  void _filterRecents(String query) {
    if (query.trim().isEmpty) {
      _filteredRecents = List.from(_recents);
    } else {
      _filteredRecents = _recents
          .where((pdf) => pdf.name.toLowerCase().contains(query.toLowerCase()))
          .toList();
    }
  }

  Future<void> _pickAndOpenPdf() async {
    try {
      final result = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf'],
      );

      if (result != null && result.files.single.path != null) {
        final filePath = result.files.single.path!;
        final fileName = p.basename(filePath);

        if (!mounted) return;
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => PdfViewerScreen(
              path: filePath,
              name: fileName,
            ),
          ),
        );
        _loadRecents();
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al seleccionar el PDF: $e')),
      );
    }
  }

  Future<void> _openRecent(RecentPdf pdf) async {
    final file = File(pdf.path);
    if (!await file.exists()) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('El archivo ya no existe en esa ubicación.'),
          action: SnackBarAction(
            label: 'Quitar',
            onPressed: () async {
              await RecentService.removeRecent(pdf.path);
              _loadRecents();
            },
          ),
        ),
      );
      return;
    }

    if (!mounted) return;
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => PdfViewerScreen(
          path: pdf.path,
          name: pdf.name,
        ),
      ),
    );
    _loadRecents();
  }

  String _formatDate(int timestamp) {
    if (timestamp == 0) return '';
    final dt = DateTime.fromMillisecondsSinceEpoch(timestamp);
    final now = DateTime.now();

    if (dt.day == now.day && dt.month == now.month && dt.year == now.year) {
      final minute = dt.minute.toString().padLeft(2, '0');
      return 'Hoy ${dt.hour}:$minute';
    }
    return '${dt.day}/${dt.month}/${dt.year}';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: theme.colorScheme.primaryContainer,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.picture_as_pdf,
                color: theme.colorScheme.onPrimaryContainer,
                size: 24,
              ),
            ),
            const SizedBox(width: 12),
            const Text(
              'Lector PDF',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ],
        ),
        actions: [
          if (_recents.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.delete_sweep),
              tooltip: 'Borrar historial',
              onPressed: () async {
                final confirm = await showDialog<bool>(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: const Text('Borrar historial'),
                    content: const Text(
                        '¿Deseas quitar todos los PDFs recientes del historial?'),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context, false),
                        child: const Text('Cancelar'),
                      ),
                      ElevatedButton(
                        onPressed: () => Navigator.pop(context, true),
                        child: const Text('Borrar'),
                      ),
                    ],
                  ),
                );
                if (confirm == true) {
                  await RecentService.clearAll();
                  _loadRecents();
                }
              },
            ),
        ],
      ),
      body: Column(
        children: [
          // Banner de bienvenida / Abrir archivo
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Card(
              elevation: 0,
              color: theme.colorScheme.primaryContainer.withValues(alpha: 0.4),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
                side: BorderSide(
                  color: theme.colorScheme.primary.withValues(alpha: 0.2),
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Lectura rápida y simple',
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: theme.colorScheme.primary,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Abre cualquier documento PDF guardado en tu celular.',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                          const SizedBox(height: 16),
                          ElevatedButton.icon(
                            onPressed: _pickAndOpenPdf,
                            icon: const Icon(Icons.folder_open),
                            label: const Text('Abrir PDF'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: theme.colorScheme.primary,
                              foregroundColor: theme.colorScheme.onPrimary,
                              elevation: 2,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 20,
                                vertical: 12,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Icon(
                      Icons.picture_as_pdf_outlined,
                      size: 64,
                      color: theme.colorScheme.primary.withValues(alpha: 0.6),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Buscador de recientes
          if (_recents.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: TextField(
                controller: _searchController,
                onChanged: (val) {
                  setState(() {
                    _filterRecents(val);
                  });
                },
                decoration: InputDecoration(
                  hintText: 'Buscar en recientes...',
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: _searchController.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear),
                          onPressed: () {
                            _searchController.clear();
                            setState(() {
                              _filterRecents('');
                            });
                          },
                        )
                      : null,
                  filled: true,
                  fillColor: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.symmetric(vertical: 0),
                ),
              ),
            ),

          const SizedBox(height: 12),

          // Encabezado de la lista
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Archivos Recientes',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                if (_filteredRecents.isNotEmpty)
                  Text(
                    '${_filteredRecents.length} archivo(s)',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
              ],
            ),
          ),

          // Lista de recientes
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _filteredRecents.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.history_toggle_off,
                              size: 64,
                              color: theme.colorScheme.outline.withValues(alpha: 0.5),
                            ),
                            const SizedBox(height: 12),
                            Text(
                              _searchController.text.isNotEmpty
                                  ? 'No se encontraron archivos'
                                  : 'No hay archivos recientes',
                              style: theme.textTheme.titleMedium?.copyWith(
                                color: theme.colorScheme.outline,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              _searchController.text.isNotEmpty
                                  ? 'Prueba con otro nombre'
                                  : 'Haz clic en "Abrir PDF" para comenzar',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.outline,
                              ),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        itemCount: _filteredRecents.length,
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        itemBuilder: (context, index) {
                          final item = _filteredRecents[index];
                          return Card(
                            margin: const EdgeInsets.only(bottom: 8),
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                              side: BorderSide(
                                color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5),
                              ),
                            ),
                            child: ListTile(
                              leading: CircleAvatar(
                                backgroundColor: Colors.red.withValues(alpha: 0.1),
                                child: const Icon(
                                  Icons.picture_as_pdf,
                                  color: Colors.red,
                                ),
                              ),
                              title: Text(
                                item.name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(fontWeight: FontWeight.w600),
                              ),
                              subtitle: Row(
                                children: [
                                  if (item.totalPages > 0)
                                    Text(
                                      'Pág. ${item.lastPage}/${item.totalPages}',
                                      style: TextStyle(
                                        color: theme.colorScheme.primary,
                                        fontSize: 12,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  if (item.totalPages > 0)
                                    const Text(' • ', style: TextStyle(fontSize: 12)),
                                  Text(
                                    _formatDate(item.lastOpenedTimestamp),
                                    style: const TextStyle(fontSize: 12),
                                  ),
                                ],
                              ),
                              trailing: IconButton(
                                icon: const Icon(Icons.close, size: 20),
                                tooltip: 'Quitar de recientes',
                                onPressed: () async {
                                  await RecentService.removeRecent(item.path);
                                  _loadRecents();
                                },
                              ),
                              onTap: () => _openRecent(item),
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _pickAndOpenPdf,
        icon: const Icon(Icons.add),
        label: const Text('Abrir PDF'),
      ),
    );
  }
}
