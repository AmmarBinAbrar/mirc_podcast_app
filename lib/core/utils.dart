// Copyright 2025 Ammar Bin Abrar and the project contributors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

// Copyright 2025 Ammar Bin Abrar and the project contributors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:io';
import 'package:mirc/entities/episode.dart';
import 'package:mirc/entities/podcast.dart';
import 'package:mirc/services/settings/settings_service.dart';
import 'package:mirc/services/settings/mobile_settings_service.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:share_plus/share_plus.dart';

/// =======================
/// STORAGE FUNCTIONS
/// =======================

/// Returns the full file path for an episode on the device
Future<String> resolvePath(Episode episode) async {
  if (Platform.isIOS) {
    return join(await getStorageDirectory(), episode.filepath, episode.filename);
  }

  return join(episode.filepath!, episode.filename);
}

/// Returns the directory path for storing an episode
Future<String> resolveDirectory({required Episode episode, bool full = false}) async {
  if (full || Platform.isAndroid) {
    return join(await getStorageDirectory(), safePath(episode.podcast!));
  }

  return safePath(episode.podcast!)!;
}

/// Creates the download directory if it doesn't exist
Future<void> createDownloadDirectory(Episode episode) async {
  final path = join(await getStorageDirectory(), safePath(episode.podcast!));
  Directory(path).createSync(recursive: true);
}

/// Checks if the app has storage permissions
Future<bool> hasStoragePermission() async {
  final SettingsService? settings = await MobileSettingsService.instance();

  if (Platform.isIOS || !settings!.storeDownloadsSDCard) {
    return true;
  }

  final permissionStatus = await Permission.storage.request();
  return permissionStatus.isGranted;
}

/// Returns the main storage directory for the app
Future<String> getStorageDirectory() async {
  final SettingsService? settings = await MobileSettingsService.instance();
  Directory directory;

  if (Platform.isIOS) {
    directory = await getApplicationDocumentsDirectory();
  } else if (settings!.storeDownloadsSDCard) {
    directory = await _getSDCard();
  } else {
    directory = await getApplicationSupportDirectory();
  }

  return join(directory.path, 'mirc');
}

/// Checks if the device has an external SD card
Future<bool> hasExternalStorage() async {
  try {
    await _getSDCard();
    return true;
  } catch (_) {
    return false;
  }
}

/// Gets the SD card directory path
Future<Directory> _getSDCard() async {
  final dirs = await getExternalStorageDirectories(type: StorageDirectory.podcasts);

  if (dirs != null) {
    for (final d in dirs) {
      if (!d.path.contains('emulated')) {
        return d.absolute;
      }
    }
  }

  throw ('No SD card found');
}

/// =======================
/// FILE NAME / PATH SANITIZATION
/// =======================

/// Sanitizes strings for use as directory names
String? safePath(String? s) => s?.replaceAll(RegExp(r'[^\w\s]+'), '').trim();

/// Sanitizes strings for use as filenames
String? safeFile(String? s) => s?.replaceAll(RegExp(r'[^\w\s\.]+'), '').trim();

/// =======================
/// URL / NETWORK HELPERS
/// =======================

/// Resolves a URL and optionally forces HTTPS
Future<String> resolveUrl(String url, {bool forceHttps = false}) async {
  if (forceHttps && url.startsWith('http://')) {
    url = url.replaceFirst('http://', 'https://');
  }

  // TODO: Optionally, you could follow redirects or check if URL is reachable
  return url;
}

/// =======================
/// SHARE FUNCTIONS
/// =======================

/// Share podcast using its original RSS / website URL
Future<void> sharePodcast({required Podcast podcast}) async {
  String url = '';

  final rss = podcast.url.toLowerCase(); // RSS feed URL

  if (rss.contains('islamfort')) {
    url = 'https://islamfort.com/videos/';
  } else if (rss.contains('jamiat')) {
    url = 'https://jamiatsindh.org/en/sec/audio/';
  } else if (rss.contains('masjidrehman')) {
    url = 'https://masjidrehman.pk/category/audios/';
  } else {
    return; // agar koi match na ho
  }

  await SharePlus.instance.share(
    ShareParams(
      text: '${podcast.title}\n\n$url',
    ),
  );
}



/// Share episode using the best available URL
Future<void> shareEpisode({required Episode episode}) async {
  final String? url = _resolveEpisodeShareUrl(episode);
  if (url == null || url.isEmpty) return;

  final text = '''
${episode.title}

$url
''';

  await SharePlus.instance.share(
    ShareParams(text: text.trim()),
  );
}

/// Prefer episode page URL, fallback to audio file URL
String? _resolveEpisodeShareUrl(Episode episode) {
  if (episode.link != null && episode.link!.isNotEmpty) {
    return episode.link;
  }

  // Uncomment this if you want to fallback to the media file
  // if (episode.contentUrl != null && episode.contentUrl!.isNotEmpty) {
  //   return episode.contentUrl;
  // }

  return null;
}
