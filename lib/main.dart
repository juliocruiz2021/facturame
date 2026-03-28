import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import 'services/api_service.dart';
import 'services/firebase_service.dart';
import 'services/recepcion_service.dart';
import 'helpers/device_uuid.dart';
import 'screens/notificaciones_screen.dart';
import 'widgets/notif_detalle_dialog.dart';

// ─── Constantes de configuración ──────────────────────────────────────────────
const String _kDefaultBackendUrl = 'http://192.168.1.10:8000';
const String _kDefaultNombreEmpresa = 'EMPRESA DE PRUEBA';
const String _kDefaultNumRegistro = '12345-6';
const String _kDefaultNombreServidor = 'SIGA1';
const String _kDefaultCelularDest = '63092051';
const String _kDefaultMiCelular = ''; // número propio de este teléfono
const String _kDefaultNombreUsuario = 'OPERADOR';

int? _parseMensajeId(dynamic raw) {
  if (raw == null) return null;
  return int.tryParse(raw.toString());
}

class _NotifTapPayload {
  final String titulo;
  final String cuerpo;
  final int? mensajeId;

  const _NotifTapPayload({
    required this.titulo,
    required this.cuerpo,
    required this.mensajeId,
  });
}

_NotifTapPayload _resolverPayloadLocal(String payload) {
  try {
    final json = jsonDecode(payload) as Map<String, dynamic>;
    return _NotifTapPayload(
      titulo: json['titulo']?.toString() ?? 'NotificaciÃ³n',
      cuerpo: json['cuerpo']?.toString() ?? '',
      mensajeId: _parseMensajeId(json['mensaje_id']),
    );
  } catch (_) {
    return _NotifTapPayload(
      titulo: 'Solicitud recibida',
      cuerpo: payload,
      mensajeId: null,
    );
  }
}

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
  final String syncId;
  final DateTime? updatedAt;
  final String nombre;
  final String dui;
  final String registroIva;
  final String giro;
  final String direccion;
  final String celular;
  final String email;

  Contacto({
    required this.syncId,
    this.updatedAt,
    required this.nombre,
    required this.dui,
    required this.registroIva,
    required this.giro,
    required this.direccion,
    required this.celular,
    required this.email,
  });

  factory Contacto.fromJson(Map<String, dynamic> j) => Contacto(
    syncId: j['sync_id'] ?? '',
    updatedAt: DateTime.tryParse(j['updated_at'] ?? ''),
    nombre: j['nombre'] ?? '',
    dui: j['dui'] ?? '',
    registroIva: j['registro_iva'] ?? '',
    giro: j['giro'] ?? '',
    direccion: j['direccion'] ?? '',
    celular: j['celular'] ?? '',
    email: j['email'] ?? '',
  );

  Map<String, dynamic> toJson() => {
    'sync_id': syncId,
    'updated_at': updatedAt?.toUtc().toIso8601String(),
    'nombre': nombre,
    'dui': dui,
    'registro_iva': registroIva,
    'giro': giro,
    'direccion': direccion,
    'celular': celular,
    'email': email,
  };

  Contacto copyWith({
    String? syncId,
    DateTime? updatedAt,
    String? nombre,
    String? dui,
    String? registroIva,
    String? giro,
    String? direccion,
    String? celular,
    String? email,
  }) {
    return Contacto(
      syncId: syncId ?? this.syncId,
      updatedAt: updatedAt ?? this.updatedAt,
      nombre: nombre ?? this.nombre,
      dui: dui ?? this.dui,
      registroIva: registroIva ?? this.registroIva,
      giro: giro ?? this.giro,
      direccion: direccion ?? this.direccion,
      celular: celular ?? this.celular,
      email: email ?? this.email,
    );
  }
}

// ─── Almacenamiento local ─────────────────────────────────────────────────────
class ContactosDB {
  static const _key = 'contactos_v2';

  static int _indexOf(List<Contacto> lista, Contacto contacto) {
    if (contacto.syncId.isNotEmpty) {
      final idx = lista.indexWhere((item) => item.syncId == contacto.syncId);
      if (idx >= 0) return idx;
    }

    return lista.indexWhere(
      (x) =>
          x.nombre.toLowerCase() == contacto.nombre.toLowerCase() &&
          x.dui == contacto.dui &&
          x.registroIva.toLowerCase() == contacto.registroIva.toLowerCase() &&
          x.celular == contacto.celular,
    );
  }

  static Future<List<Contacto>> cargarTodos() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null) return [];
    final lista = jsonDecode(raw) as List;
    return lista.map((e) => Contacto.fromJson(e)).toList();
  }

  static Future<void> guardar(Contacto c) async {
    final lista = await cargarTodos();
    final idx = _indexOf(lista, c);
    if (idx >= 0) {
      lista[idx] = c;
    } else {
      lista.add(c);
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _key,
      jsonEncode(lista.map((e) => e.toJson()).toList()),
    );
  }

  static Future<void> actualizar(Contacto original, Contacto nuevo) async {
    final lista = await cargarTodos();
    final idx = _indexOf(lista, original);
    if (idx >= 0) {
      lista[idx] = nuevo;
    } else {
      lista.add(nuevo);
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _key,
      jsonEncode(lista.map((e) => e.toJson()).toList()),
    );
  }

  static Future<void> guardarTodos(List<Contacto> contactos) async {
    final normalizados = <String, Contacto>{};
    final sinSync = <Contacto>[];

    for (final contacto in contactos) {
      if (contacto.syncId.isNotEmpty) {
        normalizados[contacto.syncId] = contacto;
      } else {
        sinSync.add(contacto);
      }
    }

    final lista = [...normalizados.values, ...sinSync];
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _key,
      jsonEncode(lista.map((e) => e.toJson()).toList()),
    );
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

class _FormularioScreenState extends State<FormularioScreen>
    with WidgetsBindingObserver {
  final _formKey = GlobalKey<FormState>();

  final _nombresCtrl = TextEditingController();
  final _duiCtrl = TextEditingController();
  final _ivaCtrl = TextEditingController();
  final _giroCtrl = TextEditingController();
  final _direccionCtrl = TextEditingController();
  final _celularCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _conceptoCtrl = TextEditingController(text: 'SERVICIOS MEDICOS');
  final _montoCtrl = TextEditingController(text: '30.00');

  final _nombresFocus = FocusNode();
  final _duiFocus = FocusNode();
  final _ivaFocus = FocusNode();
  final _giroFocus = FocusNode();
  final _direccionFocus = FocusNode();
  final _celularFocus = FocusNode();
  final _emailFocus = FocusNode();
  final _conceptoFocus = FocusNode();
  final _montoFocus = FocusNode();

  List<Contacto> _todosContactos = [];
  List<Contacto> _sugerencias = [];
  Contacto? _contactoOriginal;
  bool _esContactoExistente = false;
  bool _isSending = false;
  StreamSubscription<RemoteMessage>? _foregroundSub;
  StreamSubscription<RemoteMessage>? _tapSub;
  StreamSubscription<String>? _localTapSub;
  Timer? _contactosSyncTimer;
  int _unreadCount = 0;
  bool _isSyncingContactos = false;

  String _backendUrl = _kDefaultBackendUrl;
  String _nombreEmpresa = _kDefaultNombreEmpresa;
  String _numRegistro = _kDefaultNumRegistro;
  String _nombreServidor = _kDefaultNombreServidor;
  String _celularDest = _kDefaultCelularDest;
  String _miCelular = _kDefaultMiCelular; // número propio de este teléfono
  String _nombreUsuario = _kDefaultNombreUsuario;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _cargarContactos();
    _cargarConfiguracion();
    _nombresCtrl.addListener(_filtrarSugerencias);
    _inicializarPush();
    _actualizarBadge();
    _contactosSyncTimer = Timer.periodic(const Duration(minutes: 2), (_) {
      unawaited(_sincronizarContactosCompartidos());
    });
  }

  Future<void> _actualizarBadge() async {
    final count = await NotificacionesDB.contarNoVistas();
    if (mounted) setState(() => _unreadCount = count);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _foregroundSub?.cancel();
    _tapSub?.cancel();
    _localTapSub?.cancel();
    _contactosSyncTimer?.cancel();
    _nombresCtrl.removeListener(_filtrarSugerencias);
    for (final c in [
      _nombresCtrl,
      _duiCtrl,
      _ivaCtrl,
      _giroCtrl,
      _direccionCtrl,
      _celularCtrl,
      _emailCtrl,
      _conceptoCtrl,
      _montoCtrl,
    ]) {
      c.dispose();
    }
    for (final f in [
      _nombresFocus,
      _duiFocus,
      _ivaFocus,
      _giroFocus,
      _direccionFocus,
      _celularFocus,
      _emailFocus,
      _conceptoFocus,
      _montoFocus,
    ]) {
      f.dispose();
    }
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(_sincronizarContactosCompartidos());
    }
  }

  Future<void> _cargarContactos() async {
    final lista = await ContactosDB.cargarTodos();
    if (mounted) setState(() => _todosContactos = lista);
  }

  Contacto _normalizarContacto(Contacto contacto) {
    return contacto.copyWith(
      syncId: contacto.syncId.isNotEmpty ? contacto.syncId : const Uuid().v4(),
      updatedAt: contacto.updatedAt ?? DateTime.now().toUtc(),
    );
  }

  Future<bool> _sincronizarContactosCompartidos({bool silent = true}) async {
    if (_isSyncingContactos) return false;

    final backendUrl = _backendUrl.trim();
    final registroIva = _numRegistro.trim();
    if (backendUrl.isEmpty || registroIva.isEmpty) {
      return false;
    }

    _isSyncingContactos = true;

    try {
      final locales = (await ContactosDB.cargarTodos())
          .map(_normalizarContacto)
          .toList();
      await ContactosDB.guardarTodos(locales);

      final api = ApiService(backendUrl);
      final result = await api.syncContactosCompartidos(
        registroIva: registroIva,
        numeroCelular: _miCelular.trim().isEmpty ? null : _miCelular.trim(),
        nombreUsuario: _nombreUsuario.trim().isEmpty
            ? null
            : _nombreUsuario.trim(),
        contactos: locales.map((contacto) => contacto.toJson()).toList(),
      );

      if (!result.success) {
        if (!silent && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'No se pudo sincronizar clientes: ${result.message}',
              ),
              backgroundColor: Colors.orange,
              duration: const Duration(seconds: 4),
            ),
          );
        }
        return false;
      }

      final remotos = result.contactos
          .map(Contacto.fromJson)
          .map(_normalizarContacto)
          .toList();

      await ContactosDB.guardarTodos(remotos);
      await _cargarContactos();
      return true;
    } catch (e) {
      if (!silent && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('No se pudo sincronizar clientes: $e'),
            backgroundColor: Colors.orange,
            duration: const Duration(seconds: 4),
          ),
        );
      }
      return false;
    } finally {
      _isSyncingContactos = false;
    }
  }

  Future<void> _cargarConfiguracion() async {
    final prefs = await SharedPreferences.getInstance();
    if (mounted) {
      String prefValue(String key, String def) {
        final v = prefs.getString(key) ?? '';
        return v.isNotEmpty ? v : def;
      }

      setState(() {
        _backendUrl = prefValue('backend_url', _kDefaultBackendUrl);
        _nombreEmpresa = prefValue('nombre_empresa', _kDefaultNombreEmpresa);
        _numRegistro = prefValue('num_registro', _kDefaultNumRegistro);
        _nombreServidor = prefValue('nombre_servidor', _kDefaultNombreServidor);
        _celularDest = prefValue('celularserver', _kDefaultCelularDest);
        _miCelular = prefValue('celular_propio', _kDefaultMiCelular);
        _nombreUsuario = prefValue('nombre_usuario', _kDefaultNombreUsuario);
      });

      unawaited(_sincronizarContactosCompartidos());
    }
  }

  Future<void> _inicializarPush() async {
    try {
      await FirebaseService.initialize();

      // ── Subscripción a mensajes en foreground ──────────────────────────────
      _foregroundSub = FirebaseService.onForegroundMessage.listen((msg) {
        if (!mounted) return;
        final titulo = msg.notification?.title ?? 'Notificación';
        final cuerpo = msg.notification?.body ?? '';
        final mensajeId = _parseMensajeId(msg.data['mensaje_id']);
        // Guardar en historial y actualizar badge
        NotificacionesDB.guardar(
          NotificacionLocal(
            titulo: titulo,
            cuerpo: cuerpo,
            fecha: DateTime.now(),
            mensajeId: mensajeId,
          ),
        );
        _actualizarBadge();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  titulo,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
                if (cuerpo.isNotEmpty)
                  Builder(
                    builder: (_) {
                      final p = parsearCuerpoNotif(
                        cuerpo,
                        empresaFallback: _nombreEmpresa,
                        servidorFallback: _nombreServidor,
                      );
                      final nombre = p.data['nombre']?.toString() ?? '';
                      final txt = nombre.isNotEmpty
                          ? '${p.empresa} — $nombre'
                          : p.empresa.isNotEmpty
                          ? p.empresa
                          : cuerpo;
                      return Text(
                        txt,
                        style: const TextStyle(fontSize: 12),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      );
                    },
                  ),
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
          msg.notification?.body ?? '',
          mensajeId: _parseMensajeId(msg.data['mensaje_id']),
        );
      });

      // ── Toque en notificación local (foreground) ───────────────────────────
      _localTapSub = FirebaseService.onLocalNotificationTap.listen((payload) {
        if (!mounted) return;
        final tapData = _resolverPayloadLocal(payload);
        _mostrarDetalleNotificacion(
          tapData.titulo,
          tapData.cuerpo,
          mensajeId: tapData.mensajeId,
        );
      });

      // ── Obtener y registrar token ──────────────────────────────────────────
      final token = await FirebaseService.getToken();
      if (token == null) return;

      final uuid = await DeviceUuid.getOrCreate();
      final prefs = await SharedPreferences.getInstance();
      String prefValue(String key, String def) {
        final value = prefs.getString(key) ?? '';
        return value.isNotEmpty ? value : def;
      }

      final regIva = prefValue('num_registro', _kDefaultNumRegistro);
      final miCelular = prefs.getString('celular_propio') ?? '';
      final usuario = prefValue('nombre_usuario', _kDefaultNombreUsuario);
      final url = prefValue('backend_url', _kDefaultBackendUrl);

      // Sin registro IVA o sin número propio no se puede registrar el dispositivo.
      // NUNCA usar celularserver como fallback: causaría que este teléfono
      // sobreescriba el FCM token del destinatario en la BD.
      if (regIva.isEmpty || miCelular.isEmpty) {
        if (mounted && miCelular.isEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                '⚠ Configura "Mi número celular" para recibir notificaciones correctamente.',
              ),
              backgroundColor: Colors.orange,
              duration: Duration(seconds: 6),
            ),
          );
        }
        return;
      }

      final api = ApiService(url);
      await api.registrarDispositivo(
        registroIva: regIva,
        numeroCelular: miCelular,
        nombreUsuario: usuario,
        nombreServidor: prefValue('nombre_servidor', _kDefaultNombreServidor),
        deviceUuid: uuid,
        fcmToken: token,
      );

      // ── Refrescar token automáticamente cuando Firebase lo rote ───────────
      FirebaseService.onTokenRefresh((newToken) async {
        final p2 = await SharedPreferences.getInstance();
        final miCel2 = p2.getString('celular_propio') ?? '';
        // Solo re-registrar si el número propio está configurado
        if (miCel2.isEmpty) return;
        final api2 = ApiService(
          p2.getString('backend_url') ?? _kDefaultBackendUrl,
        );
        await api2.registrarDispositivo(
          registroIva: p2.getString('num_registro') ?? '',
          numeroCelular: miCel2,
          nombreUsuario:
              p2.getString('nombre_usuario') ?? _kDefaultNombreUsuario,
          nombreServidor:
              p2.getString('nombre_servidor') ?? _kDefaultNombreServidor,
          deviceUuid: await DeviceUuid.getOrCreate(),
          fcmToken: newToken,
        );
      });
    } catch (_) {
      // Silencioso: no bloquear la app si falla la inicialización push.
    }
  }

  Future<void> _mostrarDetalleNotificacion(
    String titulo,
    String cuerpo, {
    int? mensajeId,
  }) async {
    // Guardar en historial y actualizar badge
    await NotificacionesDB.guardar(
      NotificacionLocal(
        titulo: titulo,
        cuerpo: cuerpo,
        fecha: DateTime.now(),
        mensajeId: mensajeId,
      ),
    );
    _actualizarBadge();

    // Parsear JSON del cuerpo
    final parsed = parsearCuerpoNotif(
      cuerpo,
      empresaFallback: _nombreEmpresa,
      servidorFallback: _nombreServidor,
    );

    await RecepcionService.confirmarMensaje(mensajeId);

    // Mostrar diálogo con los datos
    if (!mounted) return;
    await showDialog(
      context: context,
      builder: (_) => NotifDetalleDialog(
        titulo: titulo,
        empresa: parsed.empresa,
        servidor: parsed.servidor,
        data: parsed.data,
        cuerpoRaw: cuerpo,
      ),
    );

    // Al cerrar el diálogo, marcar la notificación como leída
    await NotificacionesDB.marcarComoVistas();
    _actualizarBadge();
  }

  Future<void> _abrirConfiguracion() async {
    final result = await showDialog<Map<String, String>>(
      context: context,
      builder: (_) => _ConfigDialog(
        backendUrl: _backendUrl,
        nombreEmpresa: _nombreEmpresa,
        numRegistro: _numRegistro,
        nombreServidor: _nombreServidor,
        celularDest: _celularDest,
        miCelular: _miCelular,
        nombreUsuario: _nombreUsuario,
      ),
    );

    if (result == null || !mounted) return;

    final prefs = await SharedPreferences.getInstance();
    final backendNuevo = result['backend_url'] ?? '';
    final empresaNueva = result['nombre_empresa'] ?? '';
    final registroNuevo = result['num_registro'] ?? '';
    final servidorNuevo = result['nombre_servidor'] ?? '';
    final celularNuevo = result['celularserver'] ?? '';
    final miCelNuevo = result['celular_propio'] ?? '';
    final usuarioNuevo = result['nombre_usuario'] ?? '';

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
    unawaited(_sincronizarContactosCompartidos());
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
    _nombresCtrl.text = c.nombre;
    _duiCtrl.text = c.dui;
    _ivaCtrl.text = c.registroIva;
    _giroCtrl.text = c.giro;
    _direccionCtrl.text = c.direccion;
    _celularCtrl.text = c.celular;
    _emailCtrl.text = c.email;
    _contactoOriginal = c;
    _esContactoExistente = true;
    setState(() => _sugerencias = []);
    Future.delayed(
      const Duration(milliseconds: 80),
      () => _montoFocus.requestFocus(),
    );
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
    _conceptoCtrl.text = 'SERVICIOS MEDICOS';
    _montoCtrl.text = '30.00';
    _contactoOriginal = null;
    _esContactoExistente = false;
    setState(() => _sugerencias = []);
    Future.delayed(
      const Duration(milliseconds: 100),
      () => _nombresFocus.requestFocus(),
    );
  }

  Future<void> _preguntarLimpiar() async {
    if (!mounted) return;
    final limpiar = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        title: const Row(
          children: [
            Icon(Icons.check_circle, color: Color(0xFF25D366)),
            SizedBox(width: 8),
            Text('¡Enviado!', style: TextStyle(fontSize: 15)),
          ],
        ),
        content: const Text(
          '¿Registrar un nuevo cliente?',
          style: TextStyle(fontSize: 13),
        ),
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
        title: Row(
          children: [
            Icon(Icons.send, color: const Color(0xFF25D366), size: 20),
            const SizedBox(width: 8),
            const Text('Confirmar envío', style: TextStyle(fontSize: 15)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '¿Los datos son correctos?',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
            ),
            const SizedBox(height: 10),
            _fila(Icons.person_outline, 'Nombre', _nombresCtrl.text.trim()),
            _fila(Icons.badge_outlined, 'DUI', _duiCtrl.text.trim()),
            _fila(
              Icons.receipt_long_outlined,
              'Reg. IVA',
              _ivaCtrl.text.trim(),
            ),
            _fila(Icons.store_outlined, 'Giro', _giroCtrl.text.trim()),
            _fila(
              Icons.location_on_outlined,
              'Dirección',
              _direccionCtrl.text.trim(),
            ),
            _fila(Icons.phone_outlined, 'Celular', celularEnvio),
            _fila(Icons.email_outlined, 'Email', emailEnvio),
            _fila(
              Icons.medical_services_outlined,
              'Concepto',
              _conceptoCtrl.text.trim(),
            ),
            _fila(
              Icons.attach_money,
              'Monto',
              '\$${double.tryParse(_montoCtrl.text.trim())?.toStringAsFixed(2)}',
            ),
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
    final nombre = _nombresCtrl.text.trim().toUpperCase();
    final giro = _giroCtrl.text.trim().toUpperCase();
    final direccion = _direccionCtrl.text.trim().toUpperCase();
    final concepto = _conceptoCtrl.text.trim().toUpperCase();

    final contactoNuevo = Contacto(
      syncId:
          (_esContactoExistente &&
              _contactoOriginal != null &&
              _contactoOriginal!.syncId.isNotEmpty)
          ? _contactoOriginal!.syncId
          : const Uuid().v4(),
      updatedAt: DateTime.now().toUtc(),
      nombre: nombre,
      dui: _duiCtrl.text.trim(),
      registroIva: _ivaCtrl.text.trim().toUpperCase(),
      giro: giro,
      direccion: direccion,
      celular: _celularCtrl.text.trim(),
      email: _emailCtrl.text.trim(),
    );

    if (_esContactoExistente && _contactoOriginal != null) {
      await ContactosDB.actualizar(_contactoOriginal!, contactoNuevo);
    } else {
      await ContactosDB.guardar(contactoNuevo);
    }
    await _cargarContactos();
    await _sincronizarContactosCompartidos(silent: false);

    await _enviarAlBackend(
      nombre,
      giro,
      direccion,
      concepto,
      celularEnvio,
      emailEnvio,
    );
  }

  Future<void> _enviarAlBackend(
    String nombre,
    String giro,
    String direccion,
    String concepto,
    String celular,
    String email,
  ) async {
    if (!mounted) return;
    setState(() => _isSending = true);

    try {
      final cuerpo = const JsonEncoder.withIndent('  ').convert({
        'empresa': _nombreEmpresa,
        'servidor': _nombreServidor,
        'data': {
          'nombre': nombre,
          'dui': _duiCtrl.text.trim(),
          'registro_iva': _ivaCtrl.text.trim().toUpperCase(),
          'giro': giro,
          'direccion': direccion,
          'celular': celular,
          'email': email,
          'concepto': concepto,
          'monto': double.tryParse(_montoCtrl.text.trim()) ?? 0.0,
        },
      });

      final api = ApiService(_backendUrl);
      final result = await api.enviarDatos(
        registroIva: _numRegistro,
        numeroDestino: _celularDest,
        titulo: _nombreEmpresa,
        cuerpo: cuerpo,
      );

      if (!mounted) return;
      setState(() => _isSending = false);

      if (result.success) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✓ Notificación enviada a $_celularDest'),
            backgroundColor: const Color(0xFF25D366),
            duration: const Duration(seconds: 3),
          ),
        );
        await Future.delayed(const Duration(milliseconds: 600));
        await _preguntarLimpiar();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✗ Error al enviar: ${result.message}'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
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
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(ico, size: 14, color: Colors.grey),
          const SizedBox(width: 5),
          Expanded(
            child: RichText(
              text: TextSpan(
                style: const TextStyle(color: Colors.black87, fontSize: 12),
                children: [
                  TextSpan(
                    text: '$label: ',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  TextSpan(text: valor),
                ],
              ),
            ),
          ),
        ],
      ),
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
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 10,
          vertical: 10,
        ),
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
          title: const Text(
            'Facturame',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
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
                  icon: const Icon(
                    Icons.notifications_outlined,
                    color: Colors.white,
                  ),
                  tooltip: 'Historial de notificaciones',
                  onPressed: () async {
                    await Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const NotificacionesScreen(),
                      ),
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
                      constraints: const BoxConstraints(
                        minWidth: 18,
                        minHeight: 18,
                      ),
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
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2,
                      ),
                    )
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
                        contentPadding: EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 10,
                        ),
                      ),
                      validator: (v) => v == null || v.trim().isEmpty
                          ? 'Campo requerido'
                          : null,
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
                            separatorBuilder: (context, index) => const Divider(
                              height: 1,
                              indent: 12,
                              endIndent: 12,
                            ),
                            itemBuilder: (ctx, i) {
                              final c = _sugerencias[i];
                              return InkWell(
                                onTap: () => _seleccionarContacto(c),
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 8,
                                  ),
                                  child: Row(
                                    children: [
                                      const Icon(
                                        Icons.history,
                                        size: 16,
                                        color: Colors.grey,
                                      ),
                                      const SizedBox(width: 10),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              c.nombre,
                                              style: const TextStyle(
                                                fontSize: 13,
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                            Text(
                                              'DUI: ${c.dui}  •  IVA: ${c.registroIva.isEmpty ? "—" : c.registroIva}',
                                              style: const TextStyle(
                                                fontSize: 11,
                                                color: Colors.grey,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
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
                          prefixIcon: Icon(
                            Icons.location_on_outlined,
                            size: 20,
                          ),
                          border: OutlineInputBorder(),
                          filled: true,
                          fillColor: Colors.white,
                          isDense: true,
                          contentPadding: EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 10,
                          ),
                        ),
                        validator: (v) => v == null || v.trim().isEmpty
                            ? 'Campo requerido'
                            : null,
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
                          contentPadding: EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 10,
                          ),
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
                        validator: (v) => v == null || v.trim().isEmpty
                            ? 'Campo requerido'
                            : null,
                      ),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: _montoCtrl,
                        focusNode: _montoFocus,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        textInputAction: TextInputAction.done,
                        onFieldSubmitted: (_) => _confirmarYEnviar(),
                        style: const TextStyle(fontSize: 13),
                        inputFormatters: [
                          FilteringTextInputFormatter.allow(
                            RegExp(r'^\d*\.?\d{0,2}'),
                          ),
                        ],
                        decoration: const InputDecoration(
                          labelText: 'Monto',
                          labelStyle: TextStyle(fontSize: 13),
                          prefixIcon: Icon(Icons.attach_money, size: 20),
                          border: OutlineInputBorder(),
                          filled: true,
                          fillColor: Colors.white,
                          isDense: true,
                          contentPadding: EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 10,
                          ),
                        ),
                        validator: (v) {
                          if (v == null || v.trim().isEmpty) {
                            return 'Campo requerido';
                          }
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
      text: r,
      selection: TextSelection.collapsed(offset: r.length),
    );
  }
}

class _CelularFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(TextEditingValue o, TextEditingValue v) {
    var d = v.text.replaceAll(RegExp(r'[^0-9]'), '');
    if (d.length > 8) d = d.substring(0, 8);
    final r = d.length <= 4 ? d : '${d.substring(0, 4)}-${d.substring(4)}';
    return v.copyWith(
      text: r,
      selection: TextSelection.collapsed(offset: r.length),
    );
  }
}

class _UpperCaseFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(TextEditingValue o, TextEditingValue v) {
    final upper = v.text.toUpperCase();
    return v.copyWith(
      text: upper,
      selection: TextSelection.collapsed(offset: upper.length),
    );
  }
}

// ─── Diálogo de configuración ─────────────────────────────────────────────────
class _ConfigDialog extends StatefulWidget {
  final String backendUrl,
      nombreEmpresa,
      numRegistro,
      nombreServidor,
      celularDest,
      miCelular,
      nombreUsuario;

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

  @override
  void initState() {
    super.initState();
    _ctrlBackend = TextEditingController(text: widget.backendUrl);
    _ctrlEmpresa = TextEditingController(text: widget.nombreEmpresa);
    _ctrlRegistro = TextEditingController(text: widget.numRegistro);
    _ctrlServidor = TextEditingController(text: widget.nombreServidor);
    _ctrlCelular = TextEditingController(text: widget.celularDest);
    _ctrlMiCelular = TextEditingController(text: widget.miCelular);
    _ctrlUsuario = TextEditingController(text: widget.nombreUsuario);
  }

  /// Intenta leer el número del SIM.
  /// Si lo obtiene → lo copia al portapapeles y lo pega en el campo.
  /// Si no lo obtiene → abre Ajustes > Acerca del teléfono para que el
  /// usuario lo vea, lo copie manualmente y lo pegue en el campo.
  Future<void> _obtenerNumeroCelular() async {
    try {
      // 1. Solicitar permiso (retorna true si ya estaba concedido)
      final granted =
          await _channel.invokeMethod<bool>('requestPhonePermission') ?? false;
      if (!granted) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Concede el permiso de teléfono y vuelve a pulsar el botón.',
              ),
              duration: Duration(seconds: 5),
            ),
          );
        }
        return;
      }

      // 2. Intentar leer el número
      final numero = await _channel.invokeMethod<String>('getPhoneNumber');
      if (numero != null && numero.isNotEmpty) {
        final limpio = numero
            .replaceAll(RegExp(r'^\+\d{1,3}'), '')
            .replaceAll(RegExp(r'\D'), '');
        if (limpio.isNotEmpty && mounted) {
          // Pegar en el campo Y copiar al portapapeles
          await Clipboard.setData(ClipboardData(text: limpio));
          if (!mounted) return;
          setState(() {
            _ctrlMiCelular.text = limpio;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Número pegado: $limpio'),
              backgroundColor: const Color(0xFF25D366),
              duration: const Duration(seconds: 3),
            ),
          );
          return;
        }
      }

      // 3. No se pudo leer → abrir Ajustes y avisar al usuario
      await _channel.invokeMethod('openSimSettings');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Tu número aparece en "Estado del SIM". '
              'Cópialo desde ahí y pégalo en el campo.',
            ),
            duration: Duration(seconds: 7),
          ),
        );
      }
    } catch (_) {}
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
      'backend_url': _ctrlBackend.text.trim(),
      'nombre_empresa': _ctrlEmpresa.text.trim().toUpperCase(),
      'num_registro': _ctrlRegistro.text.trim().toUpperCase(),
      'nombre_servidor': _ctrlServidor.text.trim().toUpperCase(),
      'celularserver': _ctrlCelular.text.trim(),
      'celular_propio': _ctrlMiCelular.text.trim(),
      'nombre_usuario': _ctrlUsuario.text.trim().toUpperCase(),
    });
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      titlePadding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
      contentPadding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
      title: const Row(
        children: [
          Icon(Icons.settings, color: Color(0xFF25D366)),
          SizedBox(width: 8),
          Text(
            'Configuración',
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
          ),
        ],
      ),
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
                contentPadding: EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 10,
                ),
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
                contentPadding: EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 10,
                ),
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
                contentPadding: EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 10,
                ),
              ),
            ),
            const SizedBox(height: 14),
            const Text(
              'Número de registro empresa:',
              style: TextStyle(fontSize: 13),
            ),
            const SizedBox(height: 6),
            TextField(
              controller: _ctrlRegistro,
              textCapitalization: TextCapitalization.characters,
              style: const TextStyle(fontSize: 14),
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                hintText: 'Ej: 12345-6',
                isDense: true,
                contentPadding: EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 10,
                ),
              ),
            ),
            const SizedBox(height: 14),
            const Text(
              'Número destino (notificaciones):',
              style: TextStyle(fontSize: 13),
            ),
            const SizedBox(height: 6),
            TextField(
              controller: _ctrlCelular,
              keyboardType: TextInputType.phone,
              style: const TextStyle(fontSize: 14),
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                hintText: '63092051',
                isDense: true,
                contentPadding: EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 10,
                ),
              ),
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
                LengthLimitingTextInputFormatter(8),
              ],
            ),
            const SizedBox(height: 4),
            const Text(
              'Número del operador que recibirá las notificaciones',
              style: TextStyle(fontSize: 11, color: Colors.grey),
            ),
            const SizedBox(height: 14),
            const Text(
              'Mi número celular (este teléfono):',
              style: TextStyle(fontSize: 13),
            ),
            const SizedBox(height: 6),
            TextField(
              controller: _ctrlMiCelular,
              keyboardType: TextInputType.phone,
              style: const TextStyle(fontSize: 14),
              decoration: InputDecoration(
                border: const OutlineInputBorder(),
                hintText: 'Número de este teléfono',
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 10,
                ),
                suffixIcon: IconButton(
                  tooltip: 'Obtener número del dispositivo',
                  icon: const Icon(
                    Icons.phone_android,
                    size: 18,
                    color: Color(0xFF25D366),
                  ),
                  onPressed: _obtenerNumeroCelular,
                ),
              ),
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
                LengthLimitingTextInputFormatter(15),
              ],
            ),
            const SizedBox(height: 4),
            const Text(
              'Toca 📱 para obtenerlo automáticamente o escríbelo manualmente',
              style: TextStyle(fontSize: 11, color: Colors.grey),
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
                contentPadding: EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 10,
                ),
              ),
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancelar', style: TextStyle(fontSize: 13)),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: _guardar,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF25D366),
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('Guardar', style: TextStyle(fontSize: 13)),
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
