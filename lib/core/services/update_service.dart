import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

class UpdateService {
  static const String _repoOwner = 'marvynmesquita';
  static const String _repoName = 'bpm-bank';
  static const String _githubApi = 'https://api.github.com/repos/$_repoOwner/$_repoName/releases/latest';

  static const String _userAgent = 'bpm-bank-update-checker/1.0 (+https://github.com/$_repoOwner/$_repoName)';

  Future<Map<String, dynamic>?> _fetchLatestRelease() async {
    try {
      final uri = Uri.parse(_githubApi);
      final response = await http.get(uri, headers: {
        'User-Agent': _userAgent,
        'Accept': 'application/vnd.github.v3+json',
      }).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data as Map<String, dynamic>;
      }
      if (kDebugMode) {
        debugPrint('[UpdateService] API GitHub retornou status: ${response.statusCode}');
      }
      return null;
    } catch (e, stackTrace) {
      if (kDebugMode) {
        debugPrint('[UpdateService] Erro ao buscar release: $e');
        debugPrint('$stackTrace');
      }
      return null;
    }
  }

  String _extractVersion(String tag) {
    var version = tag.trim();
    if (version.startsWith('v')) {
      version = version.substring(1);
    }
    final buildIndex = version.indexOf('+');
    if (buildIndex >= 0) {
      version = version.substring(0, buildIndex);
    }
    return version;
  }

  bool _isNewerVersion(String currentVersion, String latestVersion) {
    try {
      final currentParts = _extractVersion(currentVersion)
          .split('.')
          .where((e) => e.isNotEmpty)
          .map(int.tryParse)
          .whereType<int>()
          .toList();
      final latestParts = _extractVersion(latestVersion)
          .split('.')
          .where((e) => e.isNotEmpty)
          .map(int.tryParse)
          .whereType<int>()
          .toList();

      if (currentParts.isEmpty || latestParts.isEmpty) return false;

      final maxLen = currentParts.length > latestParts.length
          ? currentParts.length
          : latestParts.length;

      for (int i = 0; i < maxLen; i++) {
        final cur = i < currentParts.length ? currentParts[i] : 0;
        final lat = i < latestParts.length ? latestParts[i] : 0;

        if (lat > cur) return true;
        if (lat < cur) return false;
      }

      return false;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[UpdateService] Erro ao comparar versões: $e');
      }
      return false;
    }
  }

  String _pickDownloadUrl(Map<String, dynamic> data) {
    final releasePageUrl = data['html_url'] as String? ??
        'https://github.com/$_repoOwner/$_repoName/releases/latest';

    final assets = (data['assets'] as List?) ?? [];

    if (kIsWeb) {
      return releasePageUrl;
    }

    String? apkUrl;
    String? aabUrl;
    String? fallbackUrl;

    for (final asset in assets) {
      if (asset is! Map<String, dynamic>) continue;
      final name = (asset['name'] as String? ?? '').toLowerCase();
      final download = asset['browser_download_url'] as String?;
      if (download == null) continue;

      fallbackUrl ??= download;
      if (name.endsWith('.apk')) apkUrl = download;
      if (name.endsWith('.aab')) aabUrl = download;
    }

    if (Platform.isAndroid) {
      return apkUrl ?? aabUrl ?? fallbackUrl ?? releasePageUrl;
    }

    return releasePageUrl;
  }

  Future<UpdateCheckResult> checkForUpdatesFull() async {
    final release = await _fetchLatestRelease();
    if (release == null) {
      return UpdateCheckResult(status: UpdateStatus.error, currentVersion: '');
    }

    PackageInfo? packageInfo;
    try {
      packageInfo = await PackageInfo.fromPlatform();
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[UpdateService] PackageInfo falhou: $e');
      }
    }

    final currentVersion = packageInfo?.version ?? '0.0.0';
    final tagName = (release['tag_name'] as String?) ?? '';
    final latestVersion = _extractVersion(tagName);
    final releasePageUrl = release['html_url'] as String? ?? '';
    final downloadUrl = _pickDownloadUrl(release);
    final releaseNotes = release['body'] as String?;

    final hasUpdate = _isNewerVersion(currentVersion, latestVersion);

    return UpdateCheckResult(
      status: UpdateStatus.success,
      currentVersion: currentVersion,
      latestVersion: latestVersion,
      hasUpdate: hasUpdate,
      downloadUrl: downloadUrl,
      releasePageUrl: releasePageUrl,
      releaseNotes: releaseNotes,
    );
  }

  Future<void> checkForUpdates({
    required Function(String newVersion, String url) onUpdateAvailable,
  }) async {
    final result = await checkForUpdatesFull();
    if (result.status == UpdateStatus.success &&
        result.hasUpdate &&
        result.latestVersion != null &&
        result.downloadUrl != null) {
      onUpdateAvailable(result.latestVersion!, result.downloadUrl!);
    }
  }

  Future<void> downloadUpdate(String url) async {
    try {
      final uri = Uri.parse(url);
      if (await canLaunchUrl(uri)) {
        await launchUrl(
          uri,
          mode: LaunchMode.externalApplication,
        );
      } else if (kDebugMode) {
        debugPrint('[UpdateService] Não foi possível abrir URL: $url');
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[UpdateService] Erro ao baixar atualização: $e');
      }
    }
  }
}

enum UpdateStatus { idle, loading, success, error }

class UpdateCheckResult {
  final UpdateStatus status;
  final String currentVersion;
  final String? latestVersion;
  final bool hasUpdate;
  final String? downloadUrl;
  final String? releasePageUrl;
  final String? releaseNotes;

  UpdateCheckResult({
    required this.status,
    required this.currentVersion,
    this.latestVersion,
    this.hasUpdate = false,
    this.downloadUrl,
    this.releasePageUrl,
    this.releaseNotes,
  });
}
