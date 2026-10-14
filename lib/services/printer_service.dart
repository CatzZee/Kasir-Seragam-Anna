import 'package:esc_pos_utils_plus/esc_pos_utils_plus.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:print_bluetooth_thermal/print_bluetooth_thermal.dart';

class PrinterDevice {
  final String name;
  final String mac;
  const PrinterDevice(this.name, this.mac);
}

class PrintResult {
  final bool success;
  final String message;
  const PrintResult(this.success, this.message);
}

/// Pembungkus tipis di atas print_bluetooth_thermal + ESC/POS.
/// Semua kegagalan dikembalikan sebagai [PrintResult] berbahasa manusia,
/// bukan exception mentah — kasir tidak perlu membaca stack trace.
class PrinterService {
  PrinterService._();
  static final PrinterService instance = PrinterService._();

  CapabilityProfile? _profile;

  Future<bool> requestPermissions() async {
    // Android 12+ memisahkan izin scan dan connect dari izin lokasi.
    final statuses = await [
      Permission.bluetooth,
      Permission.bluetoothScan,
      Permission.bluetoothConnect,
    ].request();
    return statuses.values.every((s) => s.isGranted || s.isLimited || s.isRestricted);
  }

  Future<bool> get bluetoothOn async {
    try {
      return await PrintBluetoothThermal.bluetoothEnabled;
    } catch (_) {
      return false;
    }
  }

  Future<bool> get isConnected async {
    try {
      return await PrintBluetoothThermal.connectionStatus;
    } catch (_) {
      return false;
    }
  }

  /// Hanya perangkat yang SUDAH dipasangkan di Setelan Bluetooth HP.
  /// Ini disengaja: memasangkan printer termal lebih andal lewat setelan sistem.
  Future<List<PrinterDevice>> pairedDevices() async {
    await requestPermissions();
    final list = await PrintBluetoothThermal.pairedBluetooths;
    return list.map((e) => PrinterDevice(e.name, e.macAdress)).toList();
  }

  Future<PrintResult> connect(String mac) async {
    if (mac.isEmpty) return const PrintResult(false, 'Printer belum dipilih.');
    if (!await bluetoothOn) {
      return const PrintResult(false, 'Bluetooth mati. Nyalakan Bluetooth lalu coba lagi.');
    }
    try {
      if (await isConnected) return const PrintResult(true, 'Printer sudah tersambung.');
      final ok = await PrintBluetoothThermal.connect(macPrinterAddress: mac);
      return ok
          ? const PrintResult(true, 'Printer tersambung.')
          : const PrintResult(false, 'Tidak bisa menyambung. Pastikan printer menyala dan sudah dipasangkan.');
    } catch (e) {
      return PrintResult(false, 'Gagal menyambung: $e');
    }
  }

  Future<void> disconnect() async {
    try {
      await PrintBluetoothThermal.disconnect;
    } catch (_) {}
  }

  Future<List<int>> _bytes(List<String> lines, {String? bigHeader}) async {
    _profile ??= await CapabilityProfile.load();
    final g = Generator(PaperSize.mm58, _profile!);
    var bytes = <int>[];
    bytes += g.reset();
    if (bigHeader != null) {
      bytes += g.text(
        bigHeader,
        styles: const PosStyles(
          align: PosAlign.center,
          bold: true,
          height: PosTextSize.size2,
          width: PosTextSize.size2,
        ),
      );
    }
    for (final l in lines) {
      bytes += g.text(l, styles: const PosStyles(align: PosAlign.left));
    }
    bytes += g.feed(3);
    bytes += g.cut();
    return bytes;
  }

  /// [lines] harus sudah berformat 32 kolom dari ReceiptBuilder.
  Future<PrintResult> printLines(String mac, List<String> lines, {String? bigHeader}) async {
    final conn = await connect(mac);
    if (!conn.success) return conn;
    try {
      final ok = await PrintBluetoothThermal.writeBytes(await _bytes(lines, bigHeader: bigHeader));
      return ok
          ? const PrintResult(true, 'Struk terkirim ke printer.')
          : const PrintResult(false, 'Printer menolak data. Coba matikan lalu nyalakan printer.');
    } catch (e) {
      return PrintResult(false, 'Gagal mencetak: $e');
    }
  }

  Future<PrintResult> testPrint(String mac) => printLines(
        mac,
        [
          ReceiptBuilderStub.line(),
          'Uji cetak berhasil.',
          'Lebar kertas 58 mm / 32 kolom.',
          ReceiptBuilderStub.line(),
        ],
        bigHeader: 'TES PRINTER',
      );
}

/// Helper kecil supaya PrinterService tidak perlu mengimpor UI/model.
class ReceiptBuilderStub {
  static String line() => '-' * 32;
}
