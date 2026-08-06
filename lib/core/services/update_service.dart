import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

class UpdateService {
  static const String _repoOwner = 'marvynmesquita';
  static const String _repoName = 'bpm-bank';

  Future<void> checkForUpdates({required Function(String newVersion, String url) onUpdateAvailable}) async {
    try {
      final packageInfo = await PackageInfo.fromPlatform();
      final currentVersion = packageInfo.version;

      final url = Uri.parse('https://api.github.com/repos/$_repoOwner/$_repoName/releases/latest');
      final response = await http.get(url);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final latestVersionTag = data['tag_name'] as String;
        final latestVersion = latestVersionTag.replaceAll('v', '');
        
        final assets = data['assets'] as List;
        String? apkUrl;
        if (assets.isNotEmpty) {
          apkUrl = assets.first['browser_download_url'];
        } else {
          apkUrl = data['html_url'];
        }

        if (_isNewerVersion(currentVersion, latestVersion)) {
          onUpdateAvailable(latestVersion, apkUrl!);
        }
      }
    } catch (e) {
      // Ignorar erros de rede silenciosamente
    }
  }

  bool _isNewerVersion(String currentVersion, String latestVersion) {
    final currentParts = currentVersion.split('.').map(int.parse).toList();
    final latestParts = latestVersion.split('.').map(int.parse).toList();

    for (int i = 0; i < currentParts.length; i++) {
      if (latestParts.length <= i) return false;
      if (latestParts[i] > currentParts[i]) return true;
      if (latestParts[i] < currentParts[i]) return false;
    }
    
    if (latestParts.length > currentParts.length) return true;

    return false;
  }

  Future<void> downloadUpdate(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }
}
