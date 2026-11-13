import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_bluetooth_serial/flutter_bluetooth_serial.dart';
import 'package:permission_handler/permission_handler.dart';

void main() {
  runApp(const PanelEnergiaApp());
}

class PanelEnergiaApp extends StatelessWidget {
  const PanelEnergiaApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Panel Energía BT',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: const Color(0xFF0D0F14),
      ),
      home: const PantallaPanelPrincipal(),
    );
  }
}

class DatosMedidor {
  final int sys;
  final int vista;
  final String hora;
  final int dia;
  final int red;
  final double vac;
  final int r1;
  final double i1;
  final double p1;
  final double e1;
  final double m1;
  final int f1;
  final int r2;
  final double i2;
  final double p2;
  final double e2;
  final double m2;
  final int f2;
  final int pago;

  const DatosMedidor({
    this.sys = 1,
    this.vista = 0,
    this.hora = '00:00:00',
    this.dia = 1,
    this.red = 1,
    this.vac = 220.0,
    this.r1 = 0,
    this.i1 = 0.0,
    this.p1 = 0.0,
    this.e1 = 0.0,
    this.m1 = 0.0,
    this.f1 = 0,
    this.r2 = 0,
    this.i2 = 0.0,
    this.p2 = 0.0,
    this.e2 = 0.0,
    this.m2 = 0.0,
    this.f2 = 0,
    this.pago = 0,
  });

  factory DatosMedidor.fromJson(Map<String, dynamic> json) {
    return DatosMedidor(
      sys: (json['sys'] ?? 1) as int,
      vista: (json['v'] ?? 0) as int,
      hora: (json['hora'] ?? '00:00:00').toString(),
      dia: (json['dia'] ?? 1) as int,
      red: (json['red'] ?? 0) as int,
      vac: (json['vac'] ?? 0.0).toDouble(),
      r1: (json['r1'] ?? 0) as int,
      i1: (json['i1'] ?? 0.0).toDouble(),
      p1: (json['p1'] ?? 0.0).toDouble(),
      e1: (json['e1'] ?? 0.0).toDouble(),
      m1: (json['m1'] ?? 0.0).toDouble(),
      f1: (json['f1'] ?? 0) as int,
      r2: (json['r2'] ?? 0) as int,
      i2: (json['i2'] ?? 0.0).toDouble(),
      p2: (json['p2'] ?? 0.0).toDouble(),
      e2: (json['e2'] ?? 0.0).toDouble(),
      m2: (json['m2'] ?? 0.0).toDouble(),
      f2: (json['f2'] ?? 0) as int,
      pago: (json['pago'] ?? 0) as int,
    );
  }
}

class PantallaPanelPrincipal extends StatefulWidget {
  const PantallaPanelPrincipal({super.key});

  @override
  State<PantallaPanelPrincipal> createState() => _PantallaPanelPrincipalState();
}

class _PantallaPanelPrincipalState extends State<PantallaPanelPrincipal> {
  BluetoothConnection? _conexion;
  StreamSubscription<Uint8List>? _suscripcionDatos;
  bool _conectado = false;
  bool _conectando = false;
  String _nombreDispositivo = 'PANEL_ENERGIA_BT';
  String _bufferRecepcion = '';

  DatosMedidor _datos = const DatosMedidor();
  int _alertaPagoActiva = 0;
  Timer? _timerPago;

  @override
  void initState() {
    super.initState();
    _iniciarPermisosYAutoConexion();
  }

  @override
  void dispose() {
    _timerPago?.cancel();
    _suscripcionDatos?.cancel();
    _conexion?.dispose();
    super.dispose();
  }

  Future<void> _iniciarPermisosYAutoConexion() async {
    await [
      Permission.bluetoothConnect,
      Permission.bluetoothScan,
      Permission.location,
    ].request();

    await _intentarConectarAutomatico();
  }

  Future<void> _intentarConectarAutomatico() async {
    try {
      List<BluetoothDevice> vinculados =
          await FlutterBluetoothSerial.instance.getBondedDevices();
      for (final dev in vinculados) {
        if (dev.name == 'PANEL_ENERGIA_BT') {
          await _conectarADispositivo(dev);
          return;
        }
      }
    } catch (_) {}
  }

  Future<void> _seleccionarDispositivo() async {
    await [
      Permission.bluetoothConnect,
      Permission.bluetoothScan,
      Permission.location,
    ].request();

    List<BluetoothDevice> vinculados = [];
    try {
      vinculados = await FlutterBluetoothSerial.instance.getBondedDevices();
    } catch (e) {
      _mostrarSnack('Activa el Bluetooth en tu teléfono');
      return;
    }

    if (!mounted) return;

    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF181C24),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (ctx) {
        return Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'DISPOSITIVOS VINCULADOS',
                style: TextStyle(
                  color: Colors.cyanAccent,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 10),
              if (vinculados.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(16),
                  child: Text(
                    'No hay dispositivos vinculados.\nVincula "PANEL_ENERGIA_BT" primero en los Ajustes Bluetooth de Android.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.white70),
                  ),
                )
              else
                ...vinculados.map(
                  (d) => ListTile(
                    leading: Icon(
                      Icons.bluetooth,
                      color: d.name == 'PANEL_ENERGIA_BT'
                          ? Colors.greenAccent
                          : Colors.cyanAccent,
                    ),
                    title: Text(
                      d.name ?? 'Desconocido',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    subtitle: Text(d.address),
                    onTap: () {
                      Navigator.pop(ctx);
                      _conectarADispositivo(d);
                    },
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _conectarADispositivo(BluetoothDevice dispositivo) async {
    if (_conectando) return;
    setState(() {
      _conectando = true;
      _nombreDispositivo = dispositivo.name ?? 'PANEL_ENERGIA_BT';
    });

    try {
      await _suscripcionDatos?.cancel();
      await _conexion?.close();

      final conn = await BluetoothConnection.toAddress(dispositivo.address);
      _conexion = conn;

      setState(() {
        _conectado = true;
        _conectando = false;
      });

      _suscripcionDatos = conn.input?.listen(
        (Uint8List data) {
          _bufferRecepcion += ascii.decode(data, allowInvalid: true);
          while (_bufferRecepcion.contains('\n')) {
            int idx = _bufferRecepcion.indexOf('\n');
            String linea = _bufferRecepcion.substring(0, idx).trim();
            _bufferRecepcion = _bufferRecepcion.substring(idx + 1);
            if (linea.startsWith('{') && linea.endsWith('}')) {
              _procesarJson(linea);
            }
          }
        },
        onDone: () {
          if (mounted) {
            setState(() {
              _conectado = false;
            });
          }
        },
      );

      _enviarComando('?');
    } catch (e) {
      if (mounted) {
        setState(() {
          _conectado = false;
          _conectando = false;
        });
        _mostrarSnack('No se pudo conectar a $_nombreDispositivo');
      }
    }
  }

  void _procesarJson(String linea) {
    try {
      final Map<String, dynamic> mapa = jsonDecode(linea);
      final nuevosDatos = DatosMedidor.fromJson(mapa);

      if (nuevosDatos.pago > 0) {
        _alertaPagoActiva = nuevosDatos.pago;
        _timerPago?.cancel();
        _timerPago = Timer(const Duration(milliseconds: 1400), () {
          if (mounted) {
            setState(() {
              _alertaPagoActiva = 0;
            });
          }
        });
      }

      if (mounted) {
        setState(() {
          _datos = nuevosDatos;
        });
      }
    } catch (_) {}
  }

  void _enviarComando(String cmd) {
    if (!_conectado || _conexion == null) {
      _mostrarSnack('Conecta primero al Bluetooth PANEL_ENERGIA_BT');
      return;
    }
    try {
      _conexion!.output.add(Uint8List.fromList(utf8.encode(cmd)));
    } catch (_) {
      setState(() => _conectado = false);
    }
  }

  void _confirmarReset() {
    if (!_conectado) {
      _mostrarSnack('Conecta primero al Bluetooth PANEL_ENERGIA_BT');
      return;
    }
    String objetivo = 'TODO EL SISTEMA (DPTO 1 y DPTO 2)';
    if (_datos.vista == 1) objetivo = 'DPTO 1 (Recibo individual)';
    if (_datos.vista == 2) objetivo = 'DPTO 2 (Recibo individual)';

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1A1E26),
        title: const Text(
          'REGISTRAR PAGO Y RESETEAR',
          style: TextStyle(color: Colors.amberAccent, fontSize: 16),
        ),
        content: Text(
          '¿Confirmas el pago y reinicio a S/. 0.00 para:\n\n$objetivo?',
          style: const TextStyle(color: Colors.white),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('CANCELAR', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF00E676),
              foregroundColor: Colors.black,
            ),
            onPressed: () {
              Navigator.pop(ctx);
              _enviarComando('R');
            },
            child: const Text(
              'CONFIRMAR PAGO',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  void _mostrarSnack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Column(
            children: [
              _construirBarraConexion(),
              const SizedBox(height: 8),
              Expanded(
                child: Container(
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: Colors.black,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(
                      color: _conectado
                          ? const Color(0xFF00E5FF)
                          : const Color(0xFF3A3F4B),
                      width: 2.5,
                    ),
                    boxShadow: const [
                      BoxShadow(
                        color: Colors.black87,
                        blurRadius: 12,
                        offset: Offset(0, 4),
                      ),
                    ],
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: _alertaPagoActiva > 0
                      ? _construirPantallaPagoVerde(_alertaPagoActiva)
                      : _construirContenidoTFT(),
                ),
              ),
              const SizedBox(height: 10),
              _construirPanel5Botones(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _construirBarraConexion() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFF161A22),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white12),
      ),
      child: Row(
        children: [
          Icon(
            _conectado
                ? Icons.bluetooth_connected
                : Icons.bluetooth_disabled,
            color: _conectado ? const Color(0xFF00FF00) : Colors.redAccent,
            size: 20,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              _conectando
                  ? 'Conectando a $_nombreDispositivo...'
                  : (_conectado
                      ? 'BT: $_nombreDispositivo'
                      : 'BT DESCONECTADO'),
              style: TextStyle(
                color: _conectado ? const Color(0xFF00FF00) : Colors.redAccent,
                fontWeight: FontWeight.bold,
                fontSize: 13,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          ElevatedButton.icon(
            onPressed: _seleccionarDispositivo,
            icon: const Icon(Icons.search, size: 16),
            label: Text(_conectado ? 'CAMBIAR' : 'CONECTAR'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF00B8D4),
              foregroundColor: Colors.black,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              textStyle:
                  const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }

  Widget _construirPantallaPagoVerde(int tipo) {
    String subtitulo = 'TOTAL CANCELADO';
    String pie = 'NUEVO MES: S/. 0';
    if (tipo == 1) {
      subtitulo = 'DPTO 1: S/. 0';
      pie = 'NUEVO CICLO';
    } else if (tipo == 2) {
      subtitulo = 'DPTO 2: S/. 0';
      pie = 'NUEVO CICLO';
    }

    return Container(
      color: const Color(0xFF00FF00),
      width: double.infinity,
      height: double.infinity,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.check_circle, color: Colors.black, size: 64),
          const SizedBox(height: 16),
          const Text(
            'PAGO REGISTRADO',
            style: TextStyle(
              color: Colors.black,
              fontSize: 26,
              fontWeight: FontWeight.w900,
              fontFamily: 'monospace',
            ),
          ),
          const SizedBox(height: 12),
          Text(
            subtitulo,
            style: const TextStyle(
              color: Colors.black,
              fontSize: 22,
              fontWeight: FontWeight.bold,
              fontFamily: 'monospace',
            ),
          ),
          const SizedBox(height: 12),
          Text(
            pie,
            style: const TextStyle(
              color: Colors.black,
              fontSize: 20,
              fontWeight: FontWeight.bold,
              fontFamily: 'monospace',
            ),
          ),
        ],
      ),
    );
  }

  Widget _construirContenidoTFT() {
    bool hayRed = _datos.red == 1;
    bool alertaFinMes = _datos.f1 == 1 || _datos.f2 == 1;

    return Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                _datos.hora,
                style: const TextStyle(
                  color: Color(0xFFFFFF00),
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  fontFamily: 'monospace',
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  border: Border.all(color: const Color(0xFF00FFFF), width: 1.5),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  'DIA: ${_datos.dia.toString().padLeft(2, '0')}/30',
                  style: const TextStyle(
                    color: Color(0xFF00FFFF),
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    fontFamily: 'monospace',
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            hayRed ? 'Red AC: 220V OK' : 'Red AC: SIN RED',
            style: TextStyle(
              color:
                  hayRed ? const Color(0xFF00FF00) : const Color(0xFFFF1744),
              fontSize: 13,
              fontWeight: FontWeight.bold,
              fontFamily: 'monospace',
            ),
          ),
          if (_datos.sys == 0)
            Container(
              margin: const EdgeInsets.only(top: 6),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
              decoration: BoxDecoration(
                color: Colors.red.shade900,
                borderRadius: BorderRadius.circular(4),
              ),
              child: const Text(
                'SISTEMA APAGADO (STANDBY)',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                  fontFamily: 'monospace',
                ),
              ),
            ),
          if (alertaFinMes && _datos.sys == 1)
            Container(
              margin: const EdgeInsets.only(top: 6),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
              decoration: BoxDecoration(
                color: Colors.redAccent,
                borderRadius: BorderRadius.circular(4),
              ),
              child: const Text(
                'ALERTA DIA 30: CORTE POR FIN DE CICLO',
                style: TextStyle(
                  color: Colors.black,
                  fontWeight: FontWeight.w900,
                  fontSize: 11,
                  fontFamily: 'monospace',
                ),
              ),
            ),
          const SizedBox(height: 6),
          Expanded(
            child: _datos.vista == 0
                ? _construirVista0General()
                : (_datos.vista == 1
                    ? _construirVistaDetalleDpto(
                        titulo: 'DPTO 1: RECIBO',
                        colorTema: const Color(0xFF00FFFF),
                        colorCajaMonto: const Color(0xFF00FF00),
                        releActivo: _datos.r1 == 1,
                        corriente: _datos.i1,
                        potencia: _datos.p1,
                        energia: _datos.e1,
                        monto: _datos.m1,
                      )
                    : _construirVistaDetalleDpto(
                        titulo: 'DPTO 2: RECIBO',
                        colorTema: const Color(0xFFFF00FF),
                        colorCajaMonto: const Color(0xFFFF00FF),
                        releActivo: _datos.r2 == 1,
                        corriente: _datos.i2,
                        potencia: _datos.p2,
                        energia: _datos.e2,
                        monto: _datos.m2,
                      )),
          ),
        ],
      ),
    );
  }

  Widget _construirVista0General() {
    double pTotal = _datos.sys == 1 ? (_datos.p1 + _datos.p2) : 0.0;
    double montoTotal = _datos.m1 + _datos.m2;

    return Column(
      children: [
        const Text(
          'PANEL GENERAL',
          style: TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.bold,
            fontFamily: 'monospace',
          ),
        ),
        const SizedBox(height: 6),
        Expanded(
          flex: 5,
          child: TacometroAnimado(
            valor: pTotal,
            maxValor: 3000.0,
            esMulticolor: true,
            colorFijo: const Color(0xFF00FF00),
            textoPrincipal: '${pTotal.toStringAsFixed(0)} W',
            textoSub: '/ 3000 W',
          ),
        ),
        const SizedBox(height: 8),
        Expanded(
          flex: 5,
          child: Row(
            children: [
              Expanded(
                child: _construirTarjetaDpto(
                  titulo: 'DPTO 1',
                  colorBorde: const Color(0xFF00FFFF),
                  encendido: _datos.sys == 1 && _datos.r1 == 1,
                  corriente: _datos.sys == 1 ? _datos.i1 : 0.0,
                  potencia: _datos.sys == 1 ? _datos.p1 : 0.0,
                  monto: _datos.m1,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _construirTarjetaDpto(
                  titulo: 'DPTO 2',
                  colorBorde: const Color(0xFFFF00FF),
                  encendido: _datos.sys == 1 && _datos.r2 == 1,
                  corriente: _datos.sys == 1 ? _datos.i2 : 0.0,
                  potencia: _datos.sys == 1 ? _datos.p2 : 0.0,
                  monto: _datos.m2,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: const Color(0xFF00FF00),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'TOTAL: S/.',
                style: TextStyle(
                  color: Colors.black,
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                  fontFamily: 'monospace',
                ),
              ),
              Text(
                montoTotal.toStringAsFixed(2).padLeft(6),
                style: const TextStyle(
                  color: Colors.black,
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                  fontFamily: 'monospace',
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _construirTarjetaDpto({
    required String titulo,
    required Color colorBorde,
    required bool encendido,
    required double corriente,
    required double potencia,
    required double monto,
  }) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        border: Border.all(color: colorBorde, width: 1.8),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                titulo,
                style: TextStyle(
                  color: colorBorde,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                  fontFamily: 'monospace',
                ),
              ),
              Text(
                encendido ? '(ON)' : '(OFF)',
                style: TextStyle(
                  color: encendido
                      ? const Color(0xFF00FF00)
                      : const Color(0xFFFF1744),
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                  fontFamily: 'monospace',
                ),
              ),
            ],
          ),
          Text(
            '${corriente.toStringAsFixed(1)} A',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.bold,
              fontFamily: 'monospace',
            ),
          ),
          Text(
            '${potencia.toStringAsFixed(0)} W',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.bold,
              fontFamily: 'monospace',
            ),
          ),
          Text(
            'S/.${monto.toStringAsFixed(2).padLeft(6)}',
            style: const TextStyle(
              color: Color(0xFFFFFF00),
              fontSize: 15,
              fontWeight: FontWeight.bold,
              fontFamily: 'monospace',
            ),
          ),
        ],
      ),
    );
  }

  Widget _construirVistaDetalleDpto({
    required String titulo,
    required Color colorTema,
    required Color colorCajaMonto,
    required bool releActivo,
    required double corriente,
    required double potencia,
    required double energia,
    required double monto,
  }) {
    bool activoReal = _datos.sys == 1 && releActivo;
    double iMostrar = _datos.sys == 1 ? corriente : 0.0;
    double pMostrar = _datos.sys == 1 ? potencia : 0.0;

    return Column(
      children: [
        Text(
          titulo,
          style: TextStyle(
            color: colorTema,
            fontSize: 20,
            fontWeight: FontWeight.bold,
            fontFamily: 'monospace',
          ),
        ),
        const SizedBox(height: 6),
        Expanded(
          flex: 4,
          child: TacometroAnimado(
            valor: iMostrar,
            maxValor: 15.0,
            esMulticolor: false,
            colorFijo: colorTema,
            textoPrincipal: '${iMostrar.toStringAsFixed(2)} A',
            textoSub: '/ 15.0 A',
          ),
        ),
        const SizedBox(height: 6),
        Expanded(
          flex: 5,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _filaParametro(
                  'ESTADO:',
                  activoReal ? 'CONECTADO' : 'CORTADO',
                  activoReal
                      ? const Color(0xFF00FF00)
                      : const Color(0xFFFF1744),
                ),
                _filaParametro(
                  'VOLTAJE:',
                  '${_datos.vac.toStringAsFixed(1)} V',
                  Colors.white,
                ),
                _filaParametro(
                  'CORRIENTE:',
                  '${iMostrar.toStringAsFixed(2)} A',
                  Colors.white,
                ),
                _filaParametro(
                  'POTENCIA:',
                  '${pMostrar.toStringAsFixed(0)} W',
                  Colors.white,
                ),
                _filaParametro(
                  'ENERGIA:',
                  '${energia.toStringAsFixed(1)} kWh',
                  Colors.white,
                ),
                _filaParametro(
                  'TARIFA:',
                  'S/. 0.85/kWh',
                  Colors.white70,
                ),
              ],
            ),
          ),
        ),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            border: Border.all(color: colorCajaMonto, width: 2),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Center(
            child: Text(
              'S/.${monto.toStringAsFixed(2).padLeft(6)}',
              style: TextStyle(
                color: colorCajaMonto,
                fontSize: 28,
                fontWeight: FontWeight.w900,
                fontFamily: 'monospace',
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _filaParametro(String etiqueta, String valor, Color colorValor) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          etiqueta,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 13,
            fontWeight: FontWeight.bold,
            fontFamily: 'monospace',
          ),
        ),
        Text(
          valor,
          style: TextStyle(
            color: colorValor,
            fontSize: 14,
            fontWeight: FontWeight.bold,
            fontFamily: 'monospace',
          ),
        ),
      ],
    );
  }

  Widget _construirPanel5Botones() {
    bool sysOn = _datos.sys == 1;
    bool d1On = sysOn && _datos.r1 == 1;
    bool d2On = sysOn && _datos.r2 == 1;

    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFF161A22),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white12),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: _botonTactil(
                  titulo: 'MODO',
                  subtitulo: 'Vista ${_datos.vista + 1}/3',
                  icono: Icons.dashboard_customize,
                  colorFondo: const Color(0xFF1E3A5F),
                  colorBorde: const Color(0xFF40C4FF),
                  onTap: () => _enviarComando('M'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _botonTactil(
                  titulo: 'DPTO 1',
                  subtitulo: d1On ? 'ON' : 'OFF',
                  icono: Icons.electric_bolt,
                  colorFondo:
                      d1On ? const Color(0xFF004D40) : const Color(0xFF262B36),
                  colorBorde: d1On
                      ? const Color(0xFF00FF00)
                      : const Color(0xFF00FFFF),
                  onTap: () => _enviarComando('1'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _botonTactil(
                  titulo: 'DPTO 2',
                  subtitulo: d2On ? 'ON' : 'OFF',
                  icono: Icons.electric_bolt,
                  colorFondo:
                      d2On ? const Color(0xFF4A148C) : const Color(0xFF262B36),
                  colorBorde: d2On
                      ? const Color(0xFF00FF00)
                      : const Color(0xFFFF00FF),
                  onTap: () => _enviarComando('2'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: _botonTactil(
                  titulo: 'RESET / PAGO',
                  subtitulo: _datos.vista == 0
                      ? 'Todo S/. 0'
                      : 'Dpto ${_datos.vista} S/. 0',
                  icono: Icons.payments_outlined,
                  colorFondo: const Color(0xFF4E342E),
                  colorBorde: Colors.amberAccent,
                  onTap: _confirmarReset,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _botonTactil(
                  titulo: 'SISTEMA',
                  subtitulo: sysOn ? 'ENCENDIDO' : 'APAGADO',
                  icono: Icons.power_settings_new,
                  colorFondo: sysOn
                      ? const Color(0xFF1B5E20)
                      : const Color(0xFF7F0000),
                  colorBorde:
                      sysOn ? const Color(0xFF00FF00) : Colors.redAccent,
                  onTap: () => _enviarComando('S'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _botonTactil({
    required String titulo,
    required String subtitulo,
    required IconData icono,
    required Color colorFondo,
    required Color colorBorde,
    required VoidCallback onTap,
  }) {
    return Material(
      color: colorFondo,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: colorBorde, width: 1.6),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icono, color: colorBorde, size: 22),
              const SizedBox(height: 4),
              Text(
                titulo,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
                textAlign: TextAlign.center,
              ),
              Text(
                subtitulo,
                style: TextStyle(
                  color: colorBorde,
                  fontWeight: FontWeight.w700,
                  fontSize: 11,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class TacometroAnimado extends StatelessWidget {
  final double valor;
  final double maxValor;
  final bool esMulticolor;
  final Color colorFijo;
  final String textoPrincipal;
  final String textoSub;

  const TacometroAnimado({
    super.key,
    required this.valor,
    required this.maxValor,
    required this.esMulticolor,
    required this.colorFijo,
    required this.textoPrincipal,
    required this.textoSub,
  });

  @override
  Widget build(BuildContext context) {
    double fraccionObjetivo = (valor / maxValor).clamp(0.0, 1.0);

    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0.0, end: fraccionObjetivo),
      duration: const Duration(milliseconds: 350),
      curve: Curves.easeOutCubic,
      builder: (context, fraccionAnimada, _) {
        return CustomPaint(
          painter: _TacometroPainter(
            fraccion: fraccionAnimada,
            esMulticolor: esMulticolor,
            colorFijo: colorFijo,
          ),
          child: Center(
            child: Padding(
              padding: const EdgeInsets.only(top: 28),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    textoPrincipal,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                      fontFamily: 'monospace',
                    ),
                  ),
                  Text(
                    textoSub,
                    style: const TextStyle(
                      color: Colors.white60,
                      fontSize: 12,
                      fontFamily: 'monospace',
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _TacometroPainter extends CustomPainter {
  final double fraccion;
  final bool esMulticolor;
  final Color colorFijo;

  _TacometroPainter({
    required this.fraccion,
    required this.esMulticolor,
    required this.colorFijo,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final double cx = size.width / 2;
    final double cy = size.height * 0.82;
    final double rOut = math.min(size.width * 0.44, size.height * 0.74);
    final double rIn = rOut * 0.78;

    final int anguloCorte = 180 - (fraccion * 180).round();
    final Paint paintSegmento = Paint()
      ..strokeWidth = 2.6
      ..strokeCap = StrokeCap.butt;

    for (int deg = 180; deg >= 0; deg -= 2) {
      double rad = deg * math.pi / 180.0;
      double cosA = math.cos(rad);
      double sinA = math.sin(rad);

      if (deg >= anguloCorte) {
        if (esMulticolor) {
          if (deg > 115) {
            paintSegmento.color = const Color(0xFF00FF00);
          } else if (deg > 55) {
            paintSegmento.color = const Color(0xFFFFFF00);
          } else {
            paintSegmento.color = const Color(0xFFFF1744);
          }
        } else {
          paintSegmento.color = colorFijo;
        }
      } else {
        paintSegmento.color = const Color(0xFF292D36);
      }

      Offset p1 = Offset(cx - rIn * cosA, cy - rIn * sinA);
      Offset p2 = Offset(cx - rOut * cosA, cy - rOut * sinA);
      canvas.drawLine(p1, p2, paintSegmento);
    }

    double radAguja = (180.0 - (fraccion * 180.0)) * math.pi / 180.0;
    double rAguja = rIn - 4;
    Offset puntaAguja = Offset(
      cx - rAguja * math.cos(radAguja),
      cy - rAguja * math.sin(radAguja),
    );

    final Paint paintAguja = Paint()
      ..color = Colors.white
      ..strokeWidth = 3.0
      ..strokeCap = StrokeCap.round;

    canvas.drawLine(Offset(cx, cy), puntaAguja, paintAguja);

    canvas.drawCircle(
      Offset(cx, cy),
      6.0,
      Paint()..color = const Color(0xFFFF1744),
    );
    canvas.drawCircle(
      Offset(cx, cy),
      6.0,
      Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5,
    );
  }

  @override
  bool shouldRepaint(covariant _TacometroPainter oldDelegate) {
    return oldDelegate.fraccion != fraccion ||
        oldDelegate.esMulticolor != esMulticolor ||
        oldDelegate.colorFijo != colorFijo;
  }
}
