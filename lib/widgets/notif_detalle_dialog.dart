import 'dart:convert';
import 'package:flutter/material.dart';

// ─── Datos parseados de una notificación ──────────────────────────────────────
class NotifDetalleData {
  final String empresa;
  final String servidor;
  final Map<String, dynamic> data;
  const NotifDetalleData(
      {required this.empresa, required this.servidor, required this.data});
}

/// Parsea el JSON del cuerpo de una notificación.
NotifDetalleData parsearCuerpoNotif(String cuerpo,
    {String empresaFallback = '', String servidorFallback = ''}) {
  Map<String, dynamic> data = {};
  String empresa  = empresaFallback;
  String servidor = servidorFallback;
  try {
    final json = jsonDecode(cuerpo) as Map<String, dynamic>;
    empresa  = (json['empresa']  as String?) ?? empresaFallback;
    servidor = (json['servidor'] as String?) ?? servidorFallback;
    data     = (json['data'] as Map<String, dynamic>?) ?? json;
  } catch (_) {}
  return NotifDetalleData(empresa: empresa, servidor: servidor, data: data);
}

// ─── Diálogo de detalle ────────────────────────────────────────────────────────
class NotifDetalleDialog extends StatelessWidget {
  final String titulo;
  final String empresa;
  final String servidor;
  final Map<String, dynamic> data;
  final String cuerpoRaw;

  const NotifDetalleDialog({
    super.key,
    required this.titulo,
    required this.empresa,
    required this.servidor,
    required this.data,
    required this.cuerpoRaw,
  });

  Widget _campo(String label, String? valor) {
    if (valor == null || valor.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: const TextStyle(
                  fontSize: 11, fontWeight: FontWeight.w600, color: Colors.grey)),
          const SizedBox(height: 3),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xFFF5F5F5),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.grey.shade300),
            ),
            child: Text(valor, style: const TextStyle(fontSize: 13)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool esFactura = data.containsKey('nombre') || data.containsKey('dui');
    final monto = data['monto'];
    final montoStr = monto != null
        ? '\$${double.tryParse(monto.toString())?.toStringAsFixed(2) ?? monto}'
        : null;

    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      titlePadding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
      contentPadding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
      title: Row(children: [
        const Icon(Icons.notifications_active, color: Color(0xFF25D366), size: 20),
        const SizedBox(width: 8),
        Expanded(
          child: Text(titulo,
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
              maxLines: 2,
              overflow: TextOverflow.ellipsis),
        ),
      ]),
      content: SizedBox(
        width: double.maxFinite,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 8),
              Row(children: [
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE8F5E9),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('EMPRESA',
                              style: TextStyle(
                                  fontSize: 10,
                                  color: Color(0xFF388E3C),
                                  fontWeight: FontWeight.bold)),
                          const SizedBox(height: 2),
                          Text(empresa,
                              style: const TextStyle(
                                  fontSize: 12, fontWeight: FontWeight.w600)),
                        ]),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE3F2FD),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('SERVIDOR',
                              style: TextStyle(
                                  fontSize: 10,
                                  color: Color(0xFF1565C0),
                                  fontWeight: FontWeight.bold)),
                          const SizedBox(height: 2),
                          Text(servidor,
                              style: const TextStyle(
                                  fontSize: 12, fontWeight: FontWeight.w600)),
                        ]),
                  ),
                ),
              ]),
              const SizedBox(height: 12),
              if (esFactura) ...[
                _campo('Nombre / Razón social', data['nombre']?.toString()),
                _campo('DUI / NIT',            data['dui']?.toString()),
                _campo('Registro IVA',          data['registro_iva']?.toString()),
                _campo('Giro',                  data['giro']?.toString()),
                _campo('Dirección',             data['direccion']?.toString()),
                _campo('Celular',               data['celular']?.toString()),
                _campo('Email',                 data['email']?.toString()),
                _campo('Concepto',              data['concepto']?.toString()),
                _campo('Monto',                 montoStr),
              ] else
                _campo('Mensaje', cuerpoRaw),
            ],
          ),
        ),
      ),
      actions: [
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF25D366),
            foregroundColor: Colors.white,
          ),
          onPressed: () => Navigator.pop(context),
          child: const Text('Cerrar'),
        ),
      ],
    );
  }
}
