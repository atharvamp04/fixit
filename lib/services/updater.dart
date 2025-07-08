import 'dart:convert';
import 'dart:io';
import 'package:dio/dio.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';

class Updater {
  final String versionUrl;

  Updater({required this.versionUrl});

  Future<void> checkForUpdate() async {
    try {
      final response = await Dio().get(versionUrl);
      final data = response.data;

      final latestVersion = data['version'];
      final installerUrl = data['url'];

      final info = await PackageInfo.fromPlatform();
      final currentVersion = info.version;

      if (currentVersion != latestVersion) {
        print('🔔 New version $latestVersion available (current: $currentVersion)');
        final tempDir = await getTemporaryDirectory();
        final installerPath = '${tempDir.path}/InvexaSetup.exe';

        print('⬇️ Downloading installer...');
        await Dio().download(installerUrl, installerPath);

        print('🚀 Launching installer...');
        await Process.start(installerPath, []);
        exit(0); // Close the current app
      } else {
        print('✅ You are on the latest version: $currentVersion');
      }
    } catch (e) {
      print('❌ Update check failed: $e');
    }
  }
}
