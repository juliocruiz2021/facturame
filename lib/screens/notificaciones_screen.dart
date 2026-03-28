import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

// ─── Modelo ───────────────────────────────────────────────────────────────────
class NotificacionLocal {
  final String titulo;
  final String cuerpo;
  final DateTime fecha;

  NotificacionLocal({
    required this.titulo,
    required this.cuerpo,
    required this.fecha,
  });

  Map<String, dynamic> toJson() => {
        'titulo': titulo,
        'cuerpo': cuerpo,
        'fecha': fecha.toIso8601String(),
      };

  factory NotificacionLocal.fromJson(Map<String, dynamic> j) =>
      NotificacionLocal(
        titulo: j['titulo'] ?? '',
        cuerpo: j['cuerpo'] ?? '',
        fecha: DateTime.tryParse(j['fecha'] ?? '') ?? DateTime.now(),
      );
}

// ─── Persistencia ─────────────────────────────────────────────────────────────
class NotificacionesDB {
  static const _key = 'notificaciones_v1';

  static Future<List<NotificacionLocal>> cargarTodas() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null) return [];
    final lista = jsonDecode(raw) as List;
    return lista.map((e) => NotificacionLocal.fromJson(e)).toList();
  }

  static Future<void> guardar(NotificacionLocal n) async {
    final lista = await cargarTodas();
    lista.insert(0, n); // más reciente primero
    if (lista.length > 500) lista.removeRange(500, lista.length);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
        _key, jsonEncode(lista.map((e) => e.toJson()).toList()));
  }

  static Future<void> eliminar(int index) async {
    final lista = await cargarTodas();
    if (index < 0 || index >= lista.length) return;
    lista.removeAt(index);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
        _key, jsonEncode(lista.map((e) => e.toJson()).toList()));
  }

  static Future<void> eliminarTodas() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key);
    await prefs.remove('notif_vista_en');
  }

  // ── Control de leídas ───────────────────────────────────────────────────────
  static const _vistaKey = 'notif_vista_en';

  /// Guarda el timestamp actual como "vistas hasta aquí".
  static Future<void> marcarComoVistas() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_vistaKey, DateTime.now().toIso8601String());
  }

  /// Devuelve cuántas notificaciones llegaron después de la última visita.
  static Future<int> contarNoVistas() async {
    final prefs = await SharedPreferences.getInstance();
    final vistaStr = prefs.getString(_vistaKey);
    final vistasHasta = vistaStr != null
        ? DateTime.tryParse(vistaStr) ?? DateTime(2000)
        : DateTime(2000);
    final lista = await cargarTodas();
    return lista.where((n) => n.fecha.isAfter(vistasHasta)).length;
  }
}

// ─── Pantalla ─────────────────────────────────────────────────────────────────
class NotificacionesScreen extends StatefulWidget {
  const NotificacionesScreen({super.key});

  @override
  State<NotificacionesScreen> createState() => _NotificacionesScreenState();
}

class _NotificacionesScreenState extends State<NotificacionesScreen> {
  List<NotificacionLocal> _todas = [];
  List<NotificacionLocal> _filtradas = [];
  final _searchCtrl = TextEditingController();
  bool _cargando = true;

  @override
  void initState() {
    super.initState();
    _cargar();
    _searchCtrl.addListener(_filtrar);
  }

  @override
  void dispose() {
    _searchCtrl.removeListener(_filtrar);
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _cargar() async {
    await NotificacionesDB.marcarComoVistas();
    final lista = await NotificacionesDB.cargarTodas();
    if (mounted) {
      setState(() {
        _todas = lista;
        _filtradas = lista;
        _cargando = false;
      });
    }
  }

  void _filtrar() {
    final q = _searchCtrl.text.toLowerCase();
    setState(() {
      _filtradas = q.isEmpty
          ? _todas
          : _todas
              .where((n) =>
                  n.titulo.toLowerCase().contains(q) ||
                  n.cuerpo.toLowerCase().contains(q))
              .toList();
    });
  }

  Future<void> _eliminar(int idxFiltrado) async {
    final item = _filtradas[idxFiltrado];
    final idxReal = _todas.indexOf(item);
    await NotificacionesDB.eliminar(idxReal);
    setState(() {
      _todas.removeAt(idxReal);
      _filtradas.removeAt(idxFiltrado);
    });
  }

  Future<void> _eliminarTodas() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Limpiar historial'),
        content: const Text('¿Eliminar todas las notificaciones?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancelar')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red, foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Eliminar todo'),
          ),
        ],
      ),
    );
    if (ok == true) {
      await NotificacionesDB.eliminarTodas();
      setState(() {
        _todas.clear();
        _filtradas.clear();
      });
    }
  }

  void _verDetalle(NotificacionLocal n) {
    Clipboard.setData(ClipboardData(text: n.cuerpo));
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        title: Row(children: [
          const Icon(Icons.notifications_active, color: Color(0xFF25D366)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(n.titulo,
                style: const TextStyle(
                    fontSize: 14, fontWeight: FontWeight.bold)),
          ),
        ]),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _formatearFecha(n.fecha),
                style: TextStyle(fontSize: 11, color: Colors.grey[600]),
              ),
              const SizedBox(height: 8),
              SelectableText(
                n.cuerpo,
                style:
                    const TextStyle(fontSize: 12, fontFamily: 'monospace'),
              ),
              const SizedBox(height: 8),
              Row(children: [
                const Icon(Icons.copy, size: 14, color: Colors.grey),
                const SizedBox(width: 4),
                Text('Copiado al portapapeles',
                    style: TextStyle(fontSize: 11, color: Colors.grey[600])),
              ]),
            ],
          ),
        ),
        actions: [
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF25D366),
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(context),
            child: const Text('Aceptar'),
          ),
        ],
      ),
    );
  }

  String _formatearFecha(DateTime fecha) {
    final d = fecha.toLocal();
    return '${d.day.toString().padLeft(2, '0')}/'
        '${d.month.toString().padLeft(2, '0')}/'
        '${d.year}  '
        '${d.hour.toString().padLeft(2, '0')}:'
        '${d.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        backgroundColor: const Color(0xFF25D366),
        foregroundColor: Colors.white,
        title: const Text('Historial de notificaciones',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
          tooltip: 'Regresar',
        ),
        actions: [
          if (_todas.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.delete_sweep),
              onPressed: _eliminarTodas,
              tooltip: 'Limpiar todo',
            ),
        ],
      ),
      body: Column(
        children: [
          // ── Buscador ────────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.all(12),
            child: TextField(
              controller: _searchCtrl,
              decoration: InputDecoration(
                hintText: 'Buscar en notificaciones...',
                hintStyle: const TextStyle(fontSize: 13),
                prefixIcon: const Icon(Icons.search, size: 20),
                suffixIcon: _searchCtrl.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, size: 18),
                        onPressed: () {
                          _searchCtrl.clear();
                          _filtrar();
                        },
                      )
                    : null,
                filled: true,
                fillColor: Colors.white,
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(
                    horizontal: 12, vertical: 10),
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ),

          // ── Contador ────────────────────────────────────────────────────
          if (!_cargando)
            Padding(
              padding: const EdgeInsets.only(left: 14, right: 14, bottom: 6),
              child: Row(
                children: [
                  Text(
                    _searchCtrl.text.isNotEmpty
                        ? '${_filtradas.length} resultado(s)'
                        : '${_todas.length} notificaciones',
                    style: TextStyle(
                        fontSize: 12, color: Colors.grey[600]),
                  ),
                ],
              ),
            ),

          // ── Lista ───────────────────────────────────────────────────────
          Expanded(
            child: _cargando
                ? const Center(child: CircularProgressIndicator())
                : _filtradas.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.notifications_none,
                                size: 48, color: Colors.grey[400]),
                            const SizedBox(height: 8),
                            Text(
                              _searchCtrl.text.isNotEmpty
                                  ? 'Sin resultados'
                                  : 'No hay notificaciones',
                              style: TextStyle(
                                  color: Colors.grey[500], fontSize: 14),
                            ),
                          ],
                        ),
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        itemCount: _filtradas.length,
                        separatorBuilder: (_, __) =>
                            const SizedBox(height: 6),
                        itemBuilder: (_, i) {
                          final n = _filtradas[i];
                          return Dismissible(
                            key: Key('${n.fecha.toIso8601String()}_$i'),
                            direction: DismissDirection.endToStart,
                            background: Container(
                              alignment: Alignment.centerRight,
                              padding: const EdgeInsets.only(right: 16),
                              decoration: BoxDecoration(
                                color: Colors.red,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: const Icon(Icons.delete,
                                  color: Colors.white),
                            ),
                            onDismissed: (_) => _eliminar(i),
                            child: Card(
                              elevation: 1,
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10)),
                              child: ListTile(
                                leading: const CircleAvatar(
                                  backgroundColor: Color(0xFFE8F5E9),
                                  child: Icon(Icons.notifications,
                                      color: Color(0xFF25D366), size: 20),
                                ),
                                title: Text(
                                  n.titulo,
                                  style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 13),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                subtitle: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      n.cuerpo,
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(fontSize: 11),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      _formatearFecha(n.fecha),
                                      style: TextStyle(
                                          fontSize: 10,
                                          color: Colors.grey[500]),
                                    ),
                                  ],
                                ),
                                isThreeLine: true,
                                onTap: () => _verDetalle(n),
                                trailing: const Icon(
                                    Icons.chevron_right,
                                    color: Colors.grey),
                              ),
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }
}
