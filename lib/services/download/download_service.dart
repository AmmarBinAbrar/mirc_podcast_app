// Copyright 2025 Ammar Bin Abrar and the project contributors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:mirc/entities/episode.dart';

abstract class DownloadService {
  Future<bool> downloadEpisode(Episode episode);

  Future<Episode?> findEpisodeByTaskId(String taskId);

  void dispose();
}
