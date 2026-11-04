import 'dart:io';
import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'api_client.dart';
import 'device_signals.dart';
import 'offline_queue.dart';
import 'quality_control.dart';
import 'queue_backup.dart';
import 'species.dart';
import 'package:gal/gal.dart';

abstract class CaptureCamera {
  bool get initialized;
  double get aspectRatio;
  Widget preview();
  Future<XFile> takePicture();
  Future<void> dispose();
}

class NativeCaptureCamera implements CaptureCamera {
  final CameraController controller;
  NativeCaptureCamera(this.controller);
  static Future<CaptureCamera> open() async {
    final cameras = await availableCameras();
    if (cameras.isEmpty) {
      throw StateError('No camera is available');
    }
    final rear = cameras.where(
      (camera) => camera.lensDirection == CameraLensDirection.back,
    );
    final controller = CameraController(
      rear.isEmpty ? cameras.first : rear.first,
      ResolutionPreset.high,
      enableAudio: false,
    );
    try {
      await controller.initialize();
      return NativeCaptureCamera(controller);
    } catch (_) {
      await controller.dispose();
      rethrow;
    }
  }

  @override
  bool get initialized => controller.value.isInitialized;
  @override
  double get aspectRatio => controller.value.aspectRatio;
  @override
  Widget preview() => CameraPreview(controller);
  @override
  Future<XFile> takePicture() => controller.takePicture();
  @override
  Future<void> dispose() => controller.dispose();
}

abstract class LocationAccess {
  Future<bool> enabled();
  Future<LocationPermission> check();
  Future<LocationPermission> request();
  Future<Position> position();
}

class NativeLocationAccess implements LocationAccess {
  @override
  Future<bool> enabled() => Geolocator.isLocationServiceEnabled();
  @override
  Future<LocationPermission> check() => Geolocator.checkPermission();
  @override
  Future<LocationPermission> request() => Geolocator.requestPermission();
  @override
  Future<Position> position() => Geolocator.getCurrentPosition(
    locationSettings: const LocationSettings(
      accuracy: LocationAccuracy.high,
      timeLimit: Duration(seconds: 8),
    ),
  );
}

Future<Map<String, dynamic>?> captureLocation(
  LocationAccess access,
  String source,
) async {
  try {
    if (!await access.enabled()) {
      return null;
    }
    var permission = await access.check();
    if (permission == LocationPermission.denied) {
      permission = await access.request();
    }
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      return null;
    }
    final position = await access.position();
    return {
      'gps': {'latitude': position.latitude, 'longitude': position.longitude},
      'gps_evidence': {
        'source': source,
        'is_mock': position.isMocked,
        'accuracy_m': position.accuracy,
        'observed_at': position.timestamp.toUtc().toIso8601String(),
      },
    };
  } catch (_) {
    return null;
  }
}

/// Native defaults remain the production path; tests replace boundaries, not screen logic.
class CaptureEnvironment {
  final ApiClient api;
  final String backend;
  final String operatorId;
  final Future<OfflineQueue> Function() openQueue;
  final Future<CaptureCamera> Function() openCamera;
  final Future<Map<String, dynamic>?> Function() gps;
  final Future<Map<String, dynamic>> Function() deviceSignals;
  final Future<LocalQuality> Function(XFile, SpeciesConfig) quality;
  final Future<Directory> Function() exportDirectory;
  final Future<void> Function(File, Rect) share;
  final DateTime Function() now;
  final Future<Map<String, dynamic>> Function(String, String) backup;
  final bool fieldTools;
  final Future<void> Function(String, String)? saveGallery;
  CaptureEnvironment({
    required this.api,
    required this.backend,
    required this.operatorId,
    required this.openQueue,
    required this.openCamera,
    required this.gps,
    required this.deviceSignals,
    required this.quality,
    required this.exportDirectory,
    required this.share,
    DateTime Function()? now,
    Future<Map<String, dynamic>> Function(String, String)? backup,
    this.fieldTools = false,
    this.saveGallery,
  }) : now = now ?? DateTime.now,
       backup =
           backup ?? ((root, path) => compute(exportPhoneQueue, [root, path]));

  factory CaptureEnvironment.native({String Function()? backupShareText}) =>
      CaptureEnvironment(
        fieldTools: true,
        saveGallery: (path, name) async {
          if (!await Gal.hasAccess(toAlbum: true)) {
            await Gal.requestAccess(toAlbum: true);
          }
          await Gal.putImageBytes(
            await File(path).readAsBytes(),
            album: 'BioLivestock',
            name: name,
          );
        },
        api: ApiClient(),
        backend: apiBaseUrl.replaceAll(RegExp(r'/+$'), ''),
        operatorId: authenticatedOperatorId,
        openQueue: () async => OfflineQueue(
          Directory(
            '${(await getApplicationSupportDirectory()).path}/capture_queue',
          ),
        ),
        openCamera: NativeCaptureCamera.open,
        gps: () => captureLocation(
          NativeLocationAccess(),
          Platform.isAndroid ? 'android_location' : 'ios_location',
        ),
        deviceSignals: readDeviceSignals,
        quality: (photo, config) async => compute(checkLocalQuality, {
          'bytes': await photo.readAsBytes(),
          'quality': config.quality,
        }),
        exportDirectory: () async => Directory(
          '${(await getTemporaryDirectory()).path}/capture_exports',
        ),
        share: (file, origin) async {
          await SharePlus.instance.share(
            ShareParams(
              files: [XFile(file.path)],
              sharePositionOrigin: origin,
              text:
                  backupShareText?.call() ??
                  'BioLivestock phone backup — save a copy outside this app.',
            ),
          );
        },
      );
}
