import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'services/api_service.dart';
import 'services/firebase_service.dart';
import 'helpers/device_uuid.dart';
import 'screens/notificaciones_screen.dart';

// ─── Constantes de configuración ──────────────────────────────────────────────
const String _kDefaultBackendUrl    = 'http://192.168.1.10:8000';
const String _kDefaultNombreEmpresa = 'EMPRESA DE PRUEBA';
const String _kDefaultNumRegistro   = '12345-6';
const String _kDefaultNombreServidor= 'SIGA1';
const String _kDefaultCelularDest   = '63092051';
const String _kDefaultMiCelular     = '';       // número propio de este teléfono
const String _kDefaultNombreUsuario = 'OPERADOR';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await Firebase.initializeApp();
  } catch (_) {
    // Firebase no disponible (falta google-services.json real).
    // La app funciona sin push; las notificaciones se activarán
    // cuando se coloque el archivo correcto y se recompile.
  }
  runApp(const AppClientes());
}

// ─── Modelo ───────────────────────────────────────────────────────────────────
class Contacto {
  final String nombre;
  final String dui;
  final String registroIva;
  final String giro;
  final String direccion;
  final String celular;
  final String email;

  Contacto({
    required this.nombre,
    required this.dui,
    required this.registroIva,
    required this.giro,
    required this.direccion,
    required this.celular,
    required this.email,
  });

  factory Contacto.fromJson(Map<String, dynamic> j) => Contacto(
        nombre:      j['nombre']       ?? '',
        dui:         j['dui']          ?? '',
        registroIva: j['registro_iva'] ?? '',
        giro:        j['giro']         ?? '',
        direccion:   j['direccion']    ?? '',
        celular:     j['celular']      ?? '',
        email:       j['email']        ?? '',
      );

  Map<String, dynamic> toJson() => {
        'nombre':       nombre,
        'dui':          dui,
        'registro_iva': registroIva,
        'giro':         giro,
        'direccion':    direccion,
        'celular':      celular,
        'email':        email,
      };
}

// ─── Almacenamiento local ─────────────────────────────────────────────────────
class ContactosDB {
  static const _key = 'contactos_v2';

  static Future<List<Contacto>> cargarTodos() async {
    final prefs = await SharedPreferences.getInstance();
    final raw   = prefs.getString(_key);
    if (raw == null) return [];
    final lista = jsonDecode(raw) as List;
    return lista.map((e) => Contacto.fromJson(e)).toList();
  }

  static Future<void> guardar(Contacto c) async {
    final lista = await cargarTodos();
    final idx = lista.indexWhere((x) =>
        x.nombre.toLowerCase()      == c.nombre.toLowerCase() &&
        x.dui                       == c.dui &&
        x.registroIva.toLowerCase() == c.registroIva.toLowerCase() &&
        x.celular                   == c.celular);
    if (idx >= 0) {
      lista[idx] = c;
    } else {
      lista.add(c);
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, jsonEncode(lista.map((e) => e.toJson()).toList()));
  }

  static Future<void> actualizar(Contacto original, Contacto nuevo) async {
    final lista = await cargarTodos();
    final idx = lista.indexWhere((x) =>
        x.nombre.toLowerCase()      == original.nombre.toLowerCase() &&
        x.dui                       == original.dui &&
        x.registroIva.toLowerCase() == original.registroIva.toLowerCase() &&
        x.celular                   == original.celular);
    if (idx >= 0) {
      lista[idx] = nuevo;
    } else {
      lista.add(nuevo);
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, jsonEncode(lista.map((e) => e.toJson()).toList()));
  }
}

// ─── App ──────────────────────────────────────────────────────────────────────
class AppClientes extends StatelessWidget {
  const AppClientes({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Facturame',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF25D366)),
        useMaterial3: true,
      ),
      home: const FormularioScreen(),
    );
  }
}

// ─── Formulario ───────────────────────────────────────────────────────────────
class FormularioScreen extends StatefulWidget {
  const FormularioScreen({super.key});

  @override
  State<FormularioScreen> createState() => _FormularioScreenState();
}

class _FormularioScreenState extends State<FormularioScreen> {
  final _formKey = GlobalKey<FormState>();

  final _nombresCtrl    = TextEditingController();
  final _duiCtrl        = TextEditingController();
  final _ivaCtrl        = TextEditingController();
  final _giroCtrl       = TextEditingController();
  final _direccionCtrl  = TextEditingController();
  final _celularCtrl    = TextEditingController();
  final _emailCtrl      = TextEditingController();
  final _conceptoCtrl   = TextEditingController(text: 'SERVICIOS MEDICOS');
  final _montoCtrl      = TextEditingController(text: '30.00');

  final _nombresFocus   = FocusNode();
  final _duiFocus       = FocusNode();
  final _ivaFocus       = FocusNode();
  final _giroFocus      = FocusNode();
  final _direccionFocus = FocusNode();
  final _celularFocus   = FocusNode();
  final _emailFocus     = FocusNode();
  final _conceptoFocus  = FocusNode();
  final _montoFocus     = FocusNode();

  List<Contacto> _todosContactos = [];
  List<Contacto> _sugerencias    = [];
  Contacto? _contactoOriginal;
  bool _esContactoExistente      = false;
  bool _isSending                = false;
  StreamSubscription<RemoteMessage>? _foregroundSub;
  StreamSubscription<RemoteMessage>? _tapSub;
  StreamSubscription<String>? _localTapSub;
  int _unreadCount = 0;

  String _backendUrl     = _kDefaultBackendUrl;
  String _nombreEmpresa  = _kDefaultNombreEmpresa;
  String _numRegistro    = _kDefaultNumRegistro;
  String _nombreServidor = _kDefaultNombreServidor;
  String _celularDest    = _kDefaultCelularDest;
  String _miCelular      = _kDefaultMiCelular;   // número propio de este teléfono
  String _nombreUsuario  = _kDefaultNombreUsuario;

  @override
  void initState() {
    super.initState();
    _cargarContactos();
    _cargarConfiguracion();
    _nombresCtrl.addListener(_filtrarSugerencias);
    _inicializarPush();
    _actualizarBadge();
  }

  Future<void> _actualizarBadge() async {
    final count = await NotificacionesDB.contarNoVistas();
    if (mounted) setState(() => _unreadCount = count);
  }

  @override
  void dispose() {
    _foregroundSub?.cancel();
    _tapSub?.cancel();
    _localTapSub?.cancel();
    _nombresCtrl.removeListener(_filtrarSugerencias);
    for (final c in [_nombresCtrl, _duiCtrl, _ivaCtrl, _giroCtrl,
        _direccionCtrl, _celularCtrl, _emailCtrl, _conceptoCtrl, _montoCtrl]) {
      c.dispose();
    }
    for (final f in [_nombresFocus, _duiFocus, _ivaFocus, _giroFocus,
        _direccionFocus, _celularFocus, _emailFocus, _conceptoFocus, _montoFocus]) {
      f.dispose();
    }
    super.dispose();
  }

  Future<void> _cargarContactos() async {
    final lista = await ContactosDB.cargarTodos();
    if (mounted) setState(() => _todosContactos = lista);
  }

  Future<void> _cargarConfiguracion() async {
    final prefs = await SharedPreferences.getInstance();
    if (mounted) {
      String _pref(String key, String def) {
        final v = prefs.getString(key) ?? '';
        return v.isNotEmpty ? v : def;
      }
      setState(() {
        _backendUrl    = _pref('backend_url',     _kDefaultBackendUrl);
        _nombreEmpresa = _pref('nombre_empresa',  _kDefaultNombreEmpresa);
        _numRegistro   = _pref('num_registro',    _kDefaultNumRegistro);
        _nombreServidor= _pref('nombre_servidor', _kDefaultNombreServidor);
        _celularDest   = _pref('celularserver',   _kDefaultCelularDest);
        _miCelular     = _pref('celular_propio',  _kDefaultMiCelular);
        _nombreUsuario = _pref('nombre_usuario',  _kDefaultNombreUsuario);
      });
    }
  }

  Future<void> _inicializarPush() async {
    try {
      await FirebaseService.initialize();

      // ── Subscripción a mensajes en foreground ──────────────────────────────
      _foregroundSub = FirebaseService.onForegroundMessage.listen((msg) {
        if (!mounted) return;
        final titulo = msg.notification?.title ?? 'Notificación';
        final cuerpo = msg.notification?.body  ?? '';
        // Guardar en historial y actualizar badge
        NotificacionesDB.guardar(NotificacionLocal(
          titulo: titulo, cuerpo: cuerpo, fecha: DateTime.now()));
        _actualizarBadge();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(titulo,
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 13)),
                if (cuerpo.isNotEmpty)
                  Text(cuerpo, style: const TextStyle(fontSize: 12)),
              ],
            ),
            backgroundColor: const Color(0xFF1A73E8),
            duration: const Duration(seconds: 5),
            behavior: SnackBarBehavior.floating,
          ),
        );
      });

      // ── Toque en notificación (background/terminado) ───────────────────────
      _tapSub = FirebaseService.onNotificationTap.listen((msg) {
        if (!mounted) return;
        _mostrarDetalleNotificacion(
          msg.notification?.title ?? 'Notificación',
          msg.notification?.body  ?? '',
        );
      });

      // ── Toque en notificación local (foreground) ───────────────────────────
      _localTapSub = FirebaseService.onLocalNotificationTap.listen((payload) {
        if (!mounted) return;
        _mostrarDetalleNotificacion('Solicitud recibida', payload);

      });

      // ── Obtener y registrar token ──────────────────────────────────────────
      final token = await FirebaseService.getToken();
      if (token == null) return;

      final uuid    = await DeviceUuid.getOrCreate();
      final prefs   = await SharedPreferences.getInstance();
      String _p(String k, String d) { final v = prefs.getString(k) ?? ''; return v.isNotEmpty ? v : d; }
      final regIva   = _p('num_registro',   _kDefaultNumRegistro);
      final celDest  = _p('celularserver',  _kDefaultCelularDest);
      // miCelular: número propio de este teléfono.
      // Si no está configurado, usa celularDest como antes (compatibilidad).
      final miCel    = _p('celular_propio', '');
      final numPropio = miCel.isNotEmpty ? miCel : celDest;
      final usuario  = _p('nombre_usuario', _kDefaultNombreUsuario);
      final url      = _p('backend_url',    _kDefaultBackendUrl);

      // Solo registrar si el registro IVA está configurado.
      if (regIva.isEmpty) return;

      final api = ApiService(url);
      await api.registrarDispositivo(
        registroIva:    regIva,
        numeroCelular:  numPropio,
        nombreUsuario:  usuario,
        nombreServidor: _p('nombre_servidor', _kDefaultNombreServidor),
        deviceUuid:     uuid,
        fcmToken:       token,
      );

      // ── Refrescar token automáticamente cuando Firebase lo rote ───────────
      FirebaseService.onTokenRefresh((newToken) async {
        final p2  = await SharedPreferences.getInstance();
        final api2 = ApiService(p2.getString('backend_url') ?? _kDefaultBackendUrl);
        final miCel2 = p2.getString('celular_propio') ?? '';
        final numPropio2 = miCel2.isNotEmpty
            ? miCel2
            : (p2.getString('celularserver') ?? _kDefaultCelularDest);
        await api2.registrarDispositivo(
          registroIva:    p2.getString('num_registro')    ?? '',
          numeroCelular:  numPropio2,
          nombreUsuario:  p2.getString('nombre_usuario')  ?? _kDefaultNombreUsuario,
          nombreServidor: p2.getString('nombre_servidor') ?? _kDefaultNombreServidor,
          deviceUuid:     await DeviceUuid.getOrCreate(),
          fcmToken:       newToken,
        );
      });
    } catch (_) {
      // Silencioso: no bloquear la app si falla la inicialización push.
    }
  }

  void _mostrarDetalleNotificacion(String titulo, String cuerpo) {
    // Guardar en historial y actualizar badge
    NotificacionesDB.guardar(NotificacionLocal(
      titulo: titulo, cuerpo: cuerpo, fecha: DateTime.now()));
    _actualizarBadge();

    // Parsear JSON del cuerpo
    Map<String, dynamic> data = {};
    String empresa  = _nombreEmpresa;
    String servidor = _nombreServidor;
    try {
      final json = jsonDecode(cuerpo) as Map<String, dynamic>;
      // Empresa y servidor vienen en el JSON enviado por el operador
      empresa  = (json['empresa']  as String?) ?? _nombreEmpresa;
      servidor = (json['servidor'] as String?) ?? _nombreServidor;
      data = (json['data'] as Map<String, dynamic>?) ?? json;
    } catch (_) {}

    // Mostrar diálogo con los datos
    showDialog(
      context: context,
      builder: (_) => _NotifDetalleDialog(
        titulo:    titulo,
        empresa:   empresa,
        servidor:  servidor,
        data:      data,
        cuerpoRaw: cuerpo,
      ),
    );
  }

  Future<void> _abrirConfiguracion() async {
    final result = await showDialog<Map<String, String>>(
      context: context,
      builder: (_) => _ConfigDialog(
        backendUrl:    _backendUrl,
        nombreEmpresa: _nombreEmpresa,
        numRegistro:   _numRegistro,
        nombreServidor: _nombreServidor,
        celularDest:   _celularDest,
        miCelular:     _miCelular,
        nombreUsuario: _nombreUsuario,
      ),
    );

    if (result == null || !mounted) return;

    final prefs = await SharedPreferences.getInstance();
    final backendNuevo  = result['backend_url']      ?? '';
    final empresaNueva  = result['nombre_empresa']   ?? '';
    final registroNuevo = result['num_registro']     ?? '';
    final servidorNuevo = result['nombre_servidor']  ?? '';
    final celularNuevo  = result['celularserver']    ?? '';
    final miCelNuevo    = result['celular_propio']   ?? '';
    final usuarioNuevo  = result['nombre_usuario']   ?? '';

    if (backendNuevo.isNotEmpty) {
      await prefs.setString('backend_url', backendNuevo);
      setState(() => _backendUrl = backendNuevo);
    }
    if (empresaNueva.isNotEmpty) {
      await prefs.setString('nombre_empresa', empresaNueva);
      setState(() => _nombreEmpresa = empresaNueva);
    }
    if (registroNuevo.isNotEmpty) {
      await prefs.setString('num_registro', registroNuevo);
      setState(() => _numRegistro = registroNuevo);
    }
    if (servidorNuevo.isNotEmpty) {
      await prefs.setString('nombre_servidor', servidorNuevo);
      setState(() => _nombreServidor = servidorNuevo);
    }
    if (celularNuevo.isNotEmpty) {
      await prefs.setString('celularserver', celularNuevo);
      setState(() => _celularDest = celularNuevo);
    }
    await prefs.setString('celular_propio', miCelNuevo);
    setState(() => _miCelular = miCelNuevo);
    if (usuarioNuevo.isNotEmpty) {
      await prefs.setString('nombre_usuario', usuarioNuevo);
      setState(() => _nombreUsuario = usuarioNuevo);
    }

    // Re-registrar dispositivo con la nueva configuración
    unawaited(_inicializarPush());
  }

  void _filtrarSugerencias() {
    final q = _nombresCtrl.text.trim().toLowerCase();
    if (q.isEmpty) {
      if (_sugerencias.isNotEmpty) setState(() => _sugerencias = []);
      return;
    }
    final filtro = _todosContactos
        .where((c) => c.nombre.toLowerCase().contains(q))
        .take(6)
        .toList();
    setState(() => _sugerencias = filtro);
  }

  void _seleccionarContacto(Contacto c) {
    _nombresCtrl.text   = c.nombre;
    _duiCtrl.text       = c.dui;
    _ivaCtrl.text       = c.registroIva;
    _giroCtrl.text      = c.giro;
    _direccionCtrl.text = c.direccion;
    _celularCtrl.text   = c.celular;
    _emailCtrl.text     = c.email;
    _contactoOriginal    = c;
    _esContactoExistente = true;
    setState(() => _sugerencias = []);
    Future.delayed(const Duration(milliseconds: 80), () => _montoFocus.requestFocus());
  }

  void _limpiar() {
    _formKey.currentState?.reset();
    _nombresCtrl.clear();
    _duiCtrl.clear();
    _ivaCtrl.clear();
    _giroCtrl.clear();
    _direccionCtrl.clear();
    _celularCtrl.clear();
    _emailCtrl.clear();
    _conceptoCtrl.text   = 'SERVICIOS MEDICOS';
    _montoCtrl.text      = '30.00';
    _contactoOriginal    = null;
    _esContactoExistente = false;
    setState(() => _sugerencias = []);
    Future.delayed(const Duration(milliseconds: 100), () => _nombresFocus.requestFocus());
  }

  Future<void> _preguntarLimpiar() async {
    if (!mounted) return;
    final limpiar = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        title: const Row(children: [
          Icon(Icons.check_circle, color: Color(0xFF25D366)),
          SizedBox(width: 8),
          Text('¡Enviado!', style: TextStyle(fontSize: 15)),
        ]),
        content: const Text('¿Registrar un nuevo cliente?',
            style: TextStyle(fontSize: 13)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('No', style: TextStyle(fontSize: 13)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF25D366),
              foregroundColor: Colors.white,
            ),
            child: const Text('Sí, limpiar', style: TextStyle(fontSize: 13)),
          ),
        ],
      ),
    );
    if (limpiar == true) {
      _limpiar();
    } else {
      SystemNavigator.pop();
    }
  }

  Future<void> _confirmarYEnviar() async {
    if (_isSending) return;
    if (!_formKey.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    setState(() => _sugerencias = []);

    final celularEnvio = _celularCtrl.text.trim().isEmpty
        ? '7000-0000'
        : _celularCtrl.text.trim();
    final emailEnvio = _emailCtrl.text.trim().isEmpty
        ? 'noenviar@gmail.com'
        : _emailCtrl.text.trim();

    final confirmar = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        title: Row(children: [
          Icon(Icons.send, color: const Color(0xFF25D366), size: 20),
          const SizedBox(width: 8),
          const Text('Confirmar envío', style: TextStyle(fontSize: 15)),
        ]),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('¿Los datos son correctos?',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
            const SizedBox(height: 10),
            _fila(Icons.person_outline,           'Nombre',    _nombresCtrl.text.trim()),
            _fila(Icons.badge_outlined,            'DUI',       _duiCtrl.text.trim()),
            _fila(Icons.receipt_long_outlined,     'Reg. IVA',  _ivaCtrl.text.trim()),
            _fila(Icons.store_outlined,            'Giro',      _giroCtrl.text.trim()),
            _fila(Icons.location_on_outlined,      'Dirección', _direccionCtrl.text.trim()),
            _fila(Icons.phone_outlined,            'Celular',   celularEnvio),
            _fila(Icons.email_outlined,            'Email',     emailEnvio),
            _fila(Icons.medical_services_outlined, 'Concepto',  _conceptoCtrl.text.trim()),
            _fila(Icons.attach_money,              'Monto',
                '\$${double.tryParse(_montoCtrl.text.trim())?.toStringAsFixed(2)}'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Corregir', style: TextStyle(fontSize: 13)),
          ),
          ElevatedButton.icon(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF25D366),
              foregroundColor: Colors.white,
            ),
            icon: const Icon(Icons.send, size: 15),
            label: const Text('Sí, enviar', style: TextStyle(fontSize: 13)),
          ),
        ],
      ),
    );
    if (confirmar != true || !mounted) return;

    // Normalizar a mayúsculas
    final nombre    = _nombresCtrl.text.trim().toUpperCase();
    final giro      = _giroCtrl.text.trim().toUpperCase();
    final direccion = _direccionCtrl.text.trim().toUpperCase();
    final concepto  = _conceptoCtrl.text.trim().toUpperCase();

    final contactoNuevo = Contacto(
      nombre:      nombre,
      dui:         _duiCtrl.text.trim(),
      registroIva: _ivaCtrl.text.trim().toUpperCase(),
      giro:        giro,
      direccion:   direccion,
      celular:     _celularCtrl.text.trim(),
      email:       _emailCtrl.text.trim(),
    );

    if (_esContactoExistente && _contactoOriginal != null) {
      await ContactosDB.actualizar(_contactoOriginal!, contactoNuevo);
    } else {
      await ContactosDB.guardar(contactoNuevo);
    }
    await _cargarContactos();

    await _enviarAlBackend(nombre, giro, direccion, concepto, celularEnvio, emailEnvio);
  }

  Future<void> _enviarAlBackend(String nombre, String giro, String direccion,
      String concepto, String celular, String email) async {
    if (!mounted) return;
    setState(() => _isSending = true);

    try {
      final cuerpo = const JsonEncoder.withIndent('  ').convert({
        'empresa':  _nombreEmpresa,
        'servidor': _nombreServidor,
        'data': {
          'nombre':       nombre,
          'dui':          _duiCtrl.text.trim(),
          'registro_iva': _ivaCtrl.text.trim().toUpperCase(),
          'giro':         giro,
          'direccion':    direccion,
          'celular':      celular,
          'email':        email,
          'concepto':     concepto,
          'monto':        double.tryParse(_montoCtrl.text.trim()) ?? 0.0,
        }
      });

      final api    = ApiService(_backendUrl);
      final result = await api.enviarDatos(
        registroIva:    _numRegistro,
        numeroDestino:  _celularDest,
        titulo:         _nombreEmpresa,
        cuerpo:         cuerpo,
      );

      if (!mounted) return;
      setState(() => _isSending = false);

      if (result.success) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result.message.isNotEmpty ? result.message : 'Datos enviados correctamente'),
            backgroundColor: const Color(0xFF25D366),
            duration: const Duration(seconds: 2),
          ),
        );
        await Future.delayed(const Duration(milliseconds: 600));
        await _preguntarLimpiar();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${result.message}'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSending = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error inesperado: $e'),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 4),
        ),
      );
    }
  }

  Widget _fila(IconData ico, String label, String valor) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(ico, size: 14, color: Colors.grey),
        const SizedBox(width: 5),
        Expanded(
          child: RichText(
            text: TextSpan(
              style: const TextStyle(color: Colors.black87, fontSize: 12),
              children: [
                TextSpan(text: '$label: ',
                    style: const TextStyle(fontWeight: FontWeight.bold)),
                TextSpan(text: valor),
              ],
            ),
          ),
        ),
      ]),
    );
  }

  Widget _campo({
    required TextEditingController controller,
    required FocusNode focusNode,
    required FocusNode nextFocus,
    required String label,
    required IconData icon,
    String? hint,
    TextInputType keyboardType = TextInputType.text,
    TextCapitalization capitalization = TextCapitalization.none,
    List<TextInputFormatter>? formatters,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      focusNode: focusNode,
      keyboardType: keyboardType,
      textCapitalization: capitalization,
      textInputAction: TextInputAction.next,
      onFieldSubmitted: (_) => nextFocus.requestFocus(),
      inputFormatters: formatters,
      style: const TextStyle(fontSize: 13),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(fontSize: 13),
        hintText: hint,
        hintStyle: const TextStyle(fontSize: 12),
        prefixIcon: Icon(icon, size: 20),
        border: const OutlineInputBorder(),
        filled: true,
        fillColor: Colors.white,
        isDense: true,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      ),
      validator: validator,
    );
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => setState(() => _sugerencias = []),
      child: Scaffold(
        backgroundColor: const Color(0xFFF5F5F5),
        appBar: AppBar(
          backgroundColor: const Color(0xFF25D366),
          foregroundColor: Colors.white,
          title: const Text('Facturame',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          centerTitle: true,
          leading: IconButton(
            icon: const Icon(Icons.settings, color: Colors.white),
            onPressed: _abrirConfiguracion,
            tooltip: 'Configuración',
          ),
          actions: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                IconButton(
                  icon: const Icon(Icons.notifications_outlined, color: Colors.white),
                  tooltip: 'Historial de notificaciones',
                  onPressed: () async {
                    await Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => const NotificacionesScreen()),
                    );
                    _actualizarBadge();
                  },
                ),
                if (_unreadCount > 0)
                  Positioned(
                    right: 6,
                    top: 6,
                    child: Container(
                      padding: const EdgeInsets.all(2),
                      constraints: const BoxConstraints(minWidth: 18, minHeight: 18),
                      decoration: const BoxDecoration(
                        color: Colors.red,
                        shape: BoxShape.circle,
                      ),
                      child: Text(
                        _unreadCount > 99 ? '99+' : '$_unreadCount',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
              ],
            ),
            TextButton.icon(
                icon: _isSending
                    ? const SizedBox(
                        width: 16, height: 16,
                        child: CircularProgressIndicator(
                            color: Colors.white, strokeWidth: 2))
                    : const Icon(Icons.send, color: Colors.white, size: 18),
                label: Text(
                  _isSending ? 'Enviando...' : 'Enviar',
                  style: const TextStyle(color: Colors.white, fontSize: 14),
                ),
                onPressed: _isSending ? null : _confirmarYEnviar,
              ),
            IconButton(
              icon: const Icon(Icons.logout, color: Colors.white),
              tooltip: 'Cerrar app',
              onPressed: () => SystemNavigator.pop(),
            ),
          ],
        ),
        body: Form(
          key: _formKey,
          child: Column(
            children: [

              // ── Nombre fijo ────────────────────────────────────────────
              Container(
                color: const Color(0xFFF5F5F5),
                padding: const EdgeInsets.fromLTRB(14, 10, 14, 0),
                child: Column(
                  children: [
                    TextFormField(
                      controller: _nombresCtrl,
                      focusNode: _nombresFocus,
                      textCapitalization: TextCapitalization.characters,
                      textInputAction: TextInputAction.next,
                      onFieldSubmitted: (_) => _duiFocus.requestFocus(),
                      inputFormatters: [_UpperCaseFormatter()],
                      style: const TextStyle(fontSize: 13),
                      decoration: const InputDecoration(
                        labelText: 'Nombres del cliente',
                        labelStyle: TextStyle(fontSize: 13),
                        prefixIcon: Icon(Icons.person_outline, size: 20),
                        border: OutlineInputBorder(),
                        filled: true,
                        fillColor: Colors.white,
                        isDense: true,
                        contentPadding:
                            EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                      ),
                      validator: (v) =>
                          v == null || v.trim().isEmpty ? 'Campo requerido' : null,
                    ),
                    if (_sugerencias.isNotEmpty)
                      Material(
                        elevation: 4,
                        borderRadius: BorderRadius.circular(8),
                        child: Container(
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.grey.shade300),
                          ),
                          child: ListView.separated(
                            shrinkWrap: true,
                            padding: EdgeInsets.zero,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: _sugerencias.length,
                            separatorBuilder: (context, index) =>
                                const Divider(height: 1, indent: 12, endIndent: 12),
                            itemBuilder: (ctx, i) {
                              final c = _sugerencias[i];
                              return InkWell(
                                onTap: () => _seleccionarContacto(c),
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 12, vertical: 8),
                                  child: Row(children: [
                                    const Icon(Icons.history,
                                        size: 16, color: Colors.grey),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(c.nombre,
                                              style: const TextStyle(
                                                  fontSize: 13,
                                                  fontWeight: FontWeight.w600)),
                                          Text(
                                              'DUI: ${c.dui}  •  IVA: ${c.registroIva.isEmpty ? "—" : c.registroIva}',
                                              style: const TextStyle(
                                                  fontSize: 11, color: Colors.grey)),
                                        ],
                                      ),
                                    ),
                                  ]),
                                ),
                              );
                            },
                          ),
                        ),
                      ),
                  ],
                ),
              ),

              // ── Campos scrolleables ────────────────────────────────────
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(14, 8, 14, 10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _campo(
                        controller: _duiCtrl,
                        focusNode: _duiFocus,
                        nextFocus: _ivaFocus,
                        label: 'DUI',
                        hint: '00000000-0',
                        icon: Icons.badge_outlined,
                        keyboardType: TextInputType.number,
                        formatters: [_DuiFormatter()],
                        validator: (v) {
                          if (v == null || v.trim().isEmpty) return null;
                          if (!RegExp(r'^\d{8}-\d$').hasMatch(v)) {
                            return 'Formato: 00000000-0';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 8),
                      _campo(
                        controller: _ivaCtrl,
                        focusNode: _ivaFocus,
                        nextFocus: _giroFocus,
                        label: 'Registro IVA',
                        hint: 'Opcional',
                        icon: Icons.receipt_long_outlined,
                        capitalization: TextCapitalization.characters,
                        formatters: [_UpperCaseFormatter()],
                      ),
                      const SizedBox(height: 8),
                      _campo(
                        controller: _giroCtrl,
                        focusNode: _giroFocus,
                        nextFocus: _direccionFocus,
                        label: 'Giro',
                        hint: 'Opcional',
                        icon: Icons.store_outlined,
                        capitalization: TextCapitalization.characters,
                        formatters: [_UpperCaseFormatter()],
                      ),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: _direccionCtrl,
                        focusNode: _direccionFocus,
                        textCapitalization: TextCapitalization.characters,
                        textInputAction: TextInputAction.next,
                        onFieldSubmitted: (_) => _celularFocus.requestFocus(),
                        inputFormatters: [_UpperCaseFormatter()],
                        maxLines: 2,
                        style: const TextStyle(fontSize: 13),
                        decoration: const InputDecoration(
                          labelText: 'Dirección',
                          labelStyle: TextStyle(fontSize: 13),
                          prefixIcon: Icon(Icons.location_on_outlined, size: 20),
                          border: OutlineInputBorder(),
                          filled: true,
                          fillColor: Colors.white,
                          isDense: true,
                          contentPadding:
                              EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                        ),
                        validator: (v) =>
                            v == null || v.trim().isEmpty ? 'Campo requerido' : null,
                      ),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: _celularCtrl,
                        focusNode: _celularFocus,
                        keyboardType: TextInputType.phone,
                        textInputAction: TextInputAction.next,
                        onFieldSubmitted: (_) => _emailFocus.requestFocus(),
                        inputFormatters: [_CelularFormatter()],
                        style: const TextStyle(fontSize: 13),
                        decoration: const InputDecoration(
                          labelText: 'Celular',
                          hintText: 'Opcional (0000-0000)',
                          labelStyle: TextStyle(fontSize: 13),
                          hintStyle: TextStyle(fontSize: 12),
                          prefixIcon: Icon(Icons.phone_outlined, size: 20),
                          border: OutlineInputBorder(),
                          filled: true,
                          fillColor: Colors.white,
                          isDense: true,
                          contentPadding:
                              EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                        ),
                        validator: (v) {
                          if (v == null || v.trim().isEmpty) return null;
                          if (!RegExp(r'^\d{4}-\d{4}$').hasMatch(v)) {
                            return 'Formato: 0000-0000';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 8),
                      _campo(
                        controller: _emailCtrl,
                        focusNode: _emailFocus,
                        nextFocus: _conceptoFocus,
                        label: 'Email',
                        hint: 'Opcional',
                        icon: Icons.email_outlined,
                        keyboardType: TextInputType.emailAddress,
                        validator: (v) {
                          if (v == null || v.trim().isEmpty) return null;
                          if (!v.contains('@') || !v.contains('.')) {
                            return 'Email inválido';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 8),
                      _campo(
                        controller: _conceptoCtrl,
                        focusNode: _conceptoFocus,
                        nextFocus: _montoFocus,
                        label: 'Concepto',
                        icon: Icons.medical_services_outlined,
                        capitalization: TextCapitalization.characters,
                        formatters: [_UpperCaseFormatter()],
                        validator: (v) =>
                            v == null || v.trim().isEmpty ? 'Campo requerido' : null,
                      ),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: _montoCtrl,
                        focusNode: _montoFocus,
                        keyboardType:
                            const TextInputType.numberWithOptions(decimal: true),
                        textInputAction: TextInputAction.done,
                        onFieldSubmitted: (_) => _confirmarYEnviar(),
                        style: const TextStyle(fontSize: 13),
                        inputFormatters: [
                          FilteringTextInputFormatter.allow(
                              RegExp(r'^\d*\.?\d{0,2}')),
                        ],
                        decoration: const InputDecoration(
                          labelText: 'Monto',
                          labelStyle: TextStyle(fontSize: 13),
                          prefixIcon: Icon(Icons.attach_money, size: 20),
                          border: OutlineInputBorder(),
                          filled: true,
                          fillColor: Colors.white,
                          isDense: true,
                          contentPadding:
                              EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                        ),
                        validator: (v) {
                          if (v == null || v.trim().isEmpty) return 'Campo requerido';
                          final n = double.tryParse(v);
                          if (n == null || n <= 0) return 'Monto inválido';
                          return null;
                        },
                      ),
                      const SizedBox(height: 10),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Formateadores ────────────────────────────────────────────────────────────
class _DuiFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(TextEditingValue o, TextEditingValue v) {
    var d = v.text.replaceAll(RegExp(r'[^0-9]'), '');
    if (d.length > 9) d = d.substring(0, 9);
    final r = d.length <= 8 ? d : '${d.substring(0, 8)}-${d.substring(8)}';
    return v.copyWith(
        text: r, selection: TextSelection.collapsed(offset: r.length));
  }
}

class _CelularFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(TextEditingValue o, TextEditingValue v) {
    var d = v.text.replaceAll(RegExp(r'[^0-9]'), '');
    if (d.length > 8) d = d.substring(0, 8);
    final r = d.length <= 4 ? d : '${d.substring(0, 4)}-${d.substring(4)}';
    return v.copyWith(
        text: r, selection: TextSelection.collapsed(offset: r.length));
  }
}

class _UpperCaseFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(TextEditingValue o, TextEditingValue v) {
    final upper = v.text.toUpperCase();
    return v.copyWith(
        text: upper,
        selection: TextSelection.collapsed(offset: upper.length));
  }
}

// ─── Diálogo de configuración ─────────────────────────────────────────────────
class _ConfigDialog extends StatefulWidget {
  final String backendUrl, nombreEmpresa, numRegistro,
               nombreServidor, celularDest, miCelular, nombreUsuario;

  const _ConfigDialog({
    required this.backendUrl,
    required this.nombreEmpresa,
    required this.numRegistro,
    required this.nombreServidor,
    required this.celularDest,
    required this.miCelular,
    required this.nombreUsuario,
  });

  @override
  State<_ConfigDialog> createState() => _ConfigDialogState();
}

class _ConfigDialogState extends State<_ConfigDialog> {
  static const _channel = MethodChannel('facturame/device_info');

  late final TextEditingController _ctrlBackend;
  late final TextEditingController _ctrlEmpresa;
  late final TextEditingController _ctrlRegistro;
  late final TextEditingController _ctrlServidor;
  late final TextEditingController _ctrlCelular;
  late final TextEditingController _ctrlMiCelular;
  late final TextEditingController _ctrlUsuario;
  bool _numeroCelularLeido = false; // true = se leyó del SIM, campo bloqueado

  @override
  void initState() {
    super.initState();
    _ctrlBackend   = TextEditingController(text: widget.backendUrl);
    _ctrlEmpresa   = TextEditingController(text: widget.nombreEmpresa);
    _ctrlRegistro  = TextEditingController(text: widget.numRegistro);
    _ctrlServidor  = TextEditingController(text: widget.nombreServidor);
    _ctrlCelular   = TextEditingController(text: widget.celularDest);
    _ctrlMiCelular = TextEditingController(text: widget.miCelular);
    _ctrlUsuario   = TextEditingController(text: widget.nombreUsuario);
    // Solo intentar leer si no hay número configurado aún
    if (widget.miCelular.isEmpty) _leerNumeroCelular();
  }

  Future<void> _leerNumeroCelular() async {
    try {
      // Solicitar permiso si no está otorgado
      await _channel.invokeMethod('requestPhonePermission');
      // Intentar leer el número
      final numero = await _channel.invokeMethod<String>('getPhoneNumber');
      if (numero != null && numero.isNotEmpty && mounted) {
        // Limpiar prefijo internacional si viene con +503 etc.
        final limpio = numero.replaceAll(RegExp(r'^\+\d{1,3}'), '').replaceAll(RegExp(r'\D'), '');
        setState(() {
          _ctrlMiCelular.text  = limpio;
          _numeroCelularLeido  = true;
        });
      }
    } catch (_) {
      // El operador no expone el número — el campo queda editable
    }
  }

  @override
  void dispose() {
    _ctrlBackend.dispose();
    _ctrlEmpresa.dispose();
    _ctrlRegistro.dispose();
    _ctrlServidor.dispose();
    _ctrlCelular.dispose();
    _ctrlMiCelular.dispose();
    _ctrlUsuario.dispose();
    super.dispose();
  }

  void _guardar() {
    Navigator.pop(context, {
      'backend_url':     _ctrlBackend.text.trim(),
      'nombre_empresa':  _ctrlEmpresa.text.trim().toUpperCase(),
      'num_registro':    _ctrlRegistro.text.trim().toUpperCase(),
      'nombre_servidor': _ctrlServidor.text.trim().toUpperCase(),
      'celularserver':   _ctrlCelular.text.trim(),
      'celular_propio':  _ctrlMiCelular.text.trim(),
      'nombre_usuario':  _ctrlUsuario.text.trim().toUpperCase(),
    });
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      titlePadding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
      contentPadding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
      title: const Row(children: [
        Icon(Icons.settings, color: Color(0xFF25D366)),
        SizedBox(width: 8),
        Text('Configuración',
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
      ]),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 8),
            const Text('URL del backend:', style: TextStyle(fontSize: 13)),
            const SizedBox(height: 6),
            TextField(
              controller: _ctrlBackend,
              keyboardType: TextInputType.url,
              style: const TextStyle(fontSize: 13),
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                hintText: 'http://192.168.1.x:8000',
                isDense: true,
                contentPadding:
                    EdgeInsets.symmetric(horizontal: 10, vertical: 10),
              ),
            ),
            const SizedBox(height: 14),
            const Text('Nombre de empresa:', style: TextStyle(fontSize: 13)),
            const SizedBox(height: 6),
            TextField(
              controller: _ctrlEmpresa,
              textCapitalization: TextCapitalization.characters,
              style: const TextStyle(fontSize: 14),
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                hintText: 'EMPRESA DE PRUEBA',
                isDense: true,
                contentPadding:
                    EdgeInsets.symmetric(horizontal: 10, vertical: 10),
              ),
            ),
            const SizedBox(height: 14),
            const Text('Nombre de servidor:', style: TextStyle(fontSize: 13)),
            const SizedBox(height: 6),
            TextField(
              controller: _ctrlServidor,
              textCapitalization: TextCapitalization.characters,
              style: const TextStyle(fontSize: 14),
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                hintText: 'SIGA1',
                isDense: true,
                contentPadding:
                    EdgeInsets.symmetric(horizontal: 10, vertical: 10),
              ),
            ),
            const SizedBox(height: 14),
            const Text('Número de registro empresa:',
                style: TextStyle(fontSize: 13)),
            const SizedBox(height: 6),
            TextField(
              controller: _ctrlRegistro,
              textCapitalization: TextCapitalization.characters,
              style: const TextStyle(fontSize: 14),
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                hintText: 'Ej: 12345-6',
                isDense: true,
                contentPadding:
                    EdgeInsets.symmetric(horizontal: 10, vertical: 10),
              ),
            ),
            const SizedBox(height: 14),
            const Text('Número destino (notificaciones):',
                style: TextStyle(fontSize: 13)),
            const SizedBox(height: 6),
            TextField(
              controller: _ctrlCelular,
              keyboardType: TextInputType.phone,
              style: const TextStyle(fontSize: 14),
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                hintText: '63092051',
                isDense: true,
                contentPadding:
                    EdgeInsets.symmetric(horizontal: 10, vertical: 10),
              ),
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
                LengthLimitingTextInputFormatter(8),
              ],
            ),
            const SizedBox(height: 4),
            const Text('Número del operador que recibirá las notificaciones',
                style: TextStyle(fontSize: 11, color: Colors.grey)),
            const SizedBox(height: 14),
            Row(children: [
              const Text('Mi número celular (este teléfono):',
                  style: TextStyle(fontSize: 13)),
              if (_numeroCelularLeido) ...[
                const SizedBox(width: 6),
                const Icon(Icons.sim_card, size: 14, color: Color(0xFF25D366)),
                const SizedBox(width: 2),
                const Text('leído del SIM',
                    style: TextStyle(fontSize: 10, color: Color(0xFF25D366))),
              ],
            ]),
            const SizedBox(height: 6),
            TextField(
              controller: _ctrlMiCelular,
              enabled: !_numeroCelularLeido,
              keyboardType: TextInputType.phone,
              style: const TextStyle(fontSize: 14),
              decoration: InputDecoration(
                border: const OutlineInputBorder(),
                hintText: 'Número de este teléfono',
                isDense: true,
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                filled: _numeroCelularLeido,
                fillColor: _numeroCelularLeido
                    ? const Color(0xFFE8F5E9)
                    : null,
                suffixIcon: _numeroCelularLeido
                    ? const Icon(Icons.lock, size: 16, color: Color(0xFF25D366))
                    : null,
              ),
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
                LengthLimitingTextInputFormatter(15),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              _numeroCelularLeido
                  ? 'Número detectado automáticamente del SIM'
                  : 'Número con que este dispositivo se identifica en el sistema',
              style: const TextStyle(fontSize: 11, color: Colors.grey),
            ),
            const SizedBox(height: 14),
            const Text('Nombre de usuario:', style: TextStyle(fontSize: 13)),
            const SizedBox(height: 6),
            TextField(
              controller: _ctrlUsuario,
              textCapitalization: TextCapitalization.characters,
              style: const TextStyle(fontSize: 14),
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                hintText: 'OPERADOR',
                isDense: true,
                contentPadding:
                    EdgeInsets.symmetric(horizontal: 10, vertical: 10),
              ),
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancelar',
                      style: TextStyle(fontSize: 13)),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: _guardar,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF25D366),
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('Guardar',
                      style: TextStyle(fontSize: 13)),
                ),
              ],
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}

// ─── Diálogo de detalle de notificación ───────────────────────────────────────
class _NotifDetalleDialog extends StatelessWidget {
  final String titulo;
  final String empresa;
  final String servidor;
  final Map<String, dynamic> data;
  final String cuerpoRaw;

  const _NotifDetalleDialog({
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
              // Empresa y servidor
              Row(children: [
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE8F5E9),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      const Text('EMPRESA',
                          style: TextStyle(fontSize: 10, color: Color(0xFF388E3C),
                              fontWeight: FontWeight.bold)),
                      const SizedBox(height: 2),
                      Text(empresa,
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
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
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      const Text('SERVIDOR',
                          style: TextStyle(fontSize: 10, color: Color(0xFF1565C0),
                              fontWeight: FontWeight.bold)),
                      const SizedBox(height: 2),
                      Text(servidor,
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                    ]),
                  ),
                ),
              ]),
              const SizedBox(height: 12),
              if (esFactura) ...[
                _campo('Nombre / Razón social', data['nombre']?.toString()),
                _campo('DUI / NIT', data['dui']?.toString()),
                _campo('Registro IVA', data['registro_iva']?.toString()),
                _campo('Giro', data['giro']?.toString()),
                _campo('Dirección', data['direccion']?.toString()),
                _campo('Celular', data['celular']?.toString()),
                _campo('Email', data['email']?.toString()),
                _campo('Concepto', data['concepto']?.toString()),
                _campo('Monto', montoStr),
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
