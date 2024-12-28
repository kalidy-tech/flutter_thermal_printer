import 'dart:async';
import 'dart:io';

import 'package:esc_pos_utils_plus/esc_pos_utils_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:flutter_thermal_printer/Windows/window_printer_manager.dart';
import 'package:flutter_thermal_printer/utils/printer.dart';
import 'package:image/image.dart' as img;
import 'package:screenshot/screenshot.dart';

import 'Others/other_printers_manager.dart';

export 'package:esc_pos_utils_plus/esc_pos_utils_plus.dart';
export 'package:flutter_blue_plus/flutter_blue_plus.dart'
    show BluetoothDevice, BluetoothConnectionState;

class FlutterThermalPrinter {
  static FlutterThermalPrinter? _instance;

  static FlutterThermalPrinter get instance {
    FlutterBluePlus.setLogLevel(LogLevel.debug);
    _instance ??= FlutterThermalPrinter._();
    return _instance!;
  }

  FlutterThermalPrinter._();

  Stream<List<Printer>> get devicesStream {
    if (Platform.isWindows) {
      return WindowPrinterManager.instance.devicesStream;
    } else {
      return OtherPrinterManager.instance.devicesStream;
    }
  }

  Stream<bool> get isBleTurnedOnStream {
    if (Platform.isWindows) {
      return WindowPrinterManager.instance.isBleTurnedOnStream;
    } else {
      return OtherPrinterManager.instance.isBleTurnedOnStream;
    }
  }

  // Future<void> startScan() async {
  //   if (Platform.isWindows) {
  //     await WindowPrinterManager.instance.startscan();
  //   } else {
  //     await OtherPrinterManager.instance.startScan();
  //   }
  // }

  // Future<void> stopScan() async {
  //   if (Platform.isWindows) {
  //     await WindowPrinterManager.instance.stopscan();
  //   } else {
  //     await OtherPrinterManager.instance.stopScan();
  //   }
  // }

  Future<bool> connect(Printer device) async {
    if (Platform.isWindows) {
      return await WindowPrinterManager.instance.connect(device);
    } else {
      return await OtherPrinterManager.instance.connect(device);
    }
  }

  Future<void> disconnect(Printer device) async {
    if (Platform.isWindows) {
      // await WindowBleManager.instance.disc(device);
    } else {
      await OtherPrinterManager.instance.disconnect(device);
    }
  }

  // Future<void> getUsbDevices() async {
  //   if (Platform.isWindows) {
  //     WindowPrinterManager.instance.getPrinters(
  //       connectionTypes: [
  //         ConnectionType.USB,
  //       ],
  //     );
  //   } else {
  //     await OtherPrinterManager.instance.startUsbScan();
  //   }
  // }

  Future<void> getPrinters({
    Duration refreshDuration = const Duration(seconds: 2),
    List<ConnectionType> connectionTypes = const [
      ConnectionType.USB,
      ConnectionType.BLE
    ],
    bool androidUsesFineLocation = false,
  }) async {
    if (Platform.isWindows) {
      WindowPrinterManager.instance.getPrinters(
        refreshDuration: refreshDuration,
        connectionTypes: connectionTypes,
      );
    } else {
      OtherPrinterManager.instance.getPrinters(
        connectionTypes: connectionTypes,
        androidUsesFineLocation: androidUsesFineLocation,
      );
    }
  }

  // Get BleState
  Future<bool> isBleTurnedOn() async {
    if (Platform.isWindows) {
      return await WindowPrinterManager.instance.isBleTurnedOn();
    } else {
      return FlutterBluePlus.adapterStateNow == BluetoothAdapterState.on;
    }
  }

  Future<void> printData(
    Printer device,
    List<int> bytes, {
    bool longData = false,
  }) async {
    if (Platform.isWindows) {
      return await WindowPrinterManager.instance.printData(
        device,
        bytes,
        longData: longData,
      );
    } else {
      return await OtherPrinterManager.instance.printData(
        device,
        bytes,
        longData: longData,
      );
    }
  }

  Future<void> printWidget(
    BuildContext context, {
    required Printer printer,
    required Widget widget,
    Duration delay = const Duration(milliseconds: 100),
    PaperSize paperSize = PaperSize.mm80,
    CapabilityProfile? profile,
    bool printOnBle = false,
  }) async {
    if (!printOnBle && printer.connectionType == ConnectionType.BLE) {
      throw Exception(
        "Image printing on BLE Printer may be slow or fail. Still need to try? Set printOnBle to true.",
      );
    }

    final controller = ScreenshotController();
    // Capture the widget as an image
    final image = await controller.captureFromLongWidget(
      widget,
      pixelRatio: View.of(context).devicePixelRatio,
      delay: delay,
    );

    if (Platform.isWindows) {
      await printData(
        printer,
        image.toList(),
        longData: true,
      );
    } else {
      CapabilityProfile profile0 = profile ?? await CapabilityProfile.load();
      final ticket = Generator(paperSize, profile0);
      final imageBytes = img.decodeImage(image);

      if (imageBytes == null) {
        throw Exception("Failed to decode the captured image.");
      }

      final totalHeight = imageBytes.height;
      final totalWidth = imageBytes.width;
      const rowsToCut =
          30; // You can adjust this value for the height of each printed segment
      final numSlices = (totalHeight / rowsToCut).ceil();

      for (var i = 0; i < numSlices; i++) {
        final startY = i * rowsToCut;
        final sliceHeight = (startY + rowsToCut > totalHeight)
            ? (totalHeight - startY)
            : rowsToCut;
        final croppedImage = img.copyCrop(
          imageBytes,
          x: 0,
          y: startY,
          width: totalWidth,
          height: sliceHeight,
        );

        final raster = ticket.imageRaster(
          croppedImage,
          imageFn: PosImageFn.bitImageRaster,
        );

        await FlutterThermalPrinter.instance.printData(
          printer,
          raster,
          longData: true,
        );
      }
    }
  }

  Future<void> stopScan() async {
    if (Platform.isWindows) {
      WindowPrinterManager.instance.stopscan();
    } else {
      OtherPrinterManager.instance.stopScan();
    }
  }

  // Turn On Bluetooth
  Future<void> turnOnBluetooth() async {
    if (Platform.isWindows) {
      await WindowPrinterManager.instance.turnOnBluetooth();
    } else {
      await OtherPrinterManager.instance.turnOnBluetooth();
    }
  }
}
