class AppDefaults {
  static const backendUrl = String.fromEnvironment(
    'APP_DEFAULT_BACKEND_URL',
    defaultValue: 'http://192.168.1.10:8000',
  );

  static const nombreEmpresa = String.fromEnvironment(
    'APP_DEFAULT_NOMBRE_EMPRESA',
    defaultValue: 'EMPRESA DE PRUEBA',
  );

  static const numRegistro = String.fromEnvironment(
    'APP_DEFAULT_NUM_REGISTRO',
    defaultValue: '12345-6',
  );

  static const nombreServidor = String.fromEnvironment(
    'APP_DEFAULT_NOMBRE_SERVIDOR',
    defaultValue: 'SIGA1',
  );

  static const celularDestino = String.fromEnvironment(
    'APP_DEFAULT_CELULAR_DESTINO',
    defaultValue: '63092051',
  );

  static const miCelular = String.fromEnvironment(
    'APP_DEFAULT_MI_CELULAR',
    defaultValue: '',
  );

  static const nombreUsuario = String.fromEnvironment(
    'APP_DEFAULT_NOMBRE_USUARIO',
    defaultValue: 'OPERADOR',
  );
}
