import 'dart:io';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:permission_handler/permission_handler.dart';

class AppPermissionsSnapshot {
  const AppPermissionsSnapshot({
    required this.notificationStatus,
    required this.cameraStatus,
    required this.photosStatus,
  });

  final AuthorizationStatus notificationStatus;
  final PermissionStatus cameraStatus;
  final PermissionStatus photosStatus;

  bool get notificationsAllowed =>
      notificationStatus == AuthorizationStatus.authorized ||
      notificationStatus == AuthorizationStatus.provisional;

  bool get cameraAllowed => cameraStatus.isGranted;

  bool get galleryAllowed =>
      Platform.isAndroid || photosStatus.isGranted || photosStatus.isLimited;

  int get grantedCount => [
    notificationsAllowed,
    cameraAllowed,
    galleryAllowed,
  ].where((granted) => granted).length;

  static const int totalCount = 3;
}

class AppPermissions {
  const AppPermissions._();

  static Future<AppPermissionsSnapshot> load() async {
    final notificationSettings = await FirebaseMessaging.instance
        .getNotificationSettings();
    final cameraStatus = await Permission.camera.status;
    final photosStatus = Platform.isIOS
        ? await Permission.photos.status
        : PermissionStatus.granted;

    return AppPermissionsSnapshot(
      notificationStatus: notificationSettings.authorizationStatus,
      cameraStatus: cameraStatus,
      photosStatus: photosStatus,
    );
  }

  static Future<void> requestNotifications() async {
    final current = await FirebaseMessaging.instance.getNotificationSettings();
    if (current.authorizationStatus == AuthorizationStatus.denied) {
      await openAppSettings();
      return;
    }

    await FirebaseMessaging.instance.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );
  }

  static Future<void> requestCamera() async {
    final current = await Permission.camera.status;
    if (current.isPermanentlyDenied || current.isRestricted) {
      await openAppSettings();
      return;
    }
    await Permission.camera.request();
  }

  static Future<void> requestPhotos() async {
    if (!Platform.isIOS) return;

    final current = await Permission.photos.status;
    if (current.isPermanentlyDenied || current.isRestricted) {
      await openAppSettings();
      return;
    }
    await Permission.photos.request();
  }
}
