// Copyright 2025 Ammar Bin Abrar and the project contributors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:mirc/bloc/podcast/opml_bloc.dart';
import 'package:mirc/bloc/podcast/podcast_bloc.dart';
import 'package:mirc/bloc/settings/settings_bloc.dart';
import 'package:mirc/core/utils.dart';
import 'package:mirc/entities/app_settings.dart';
import 'package:mirc/l10n/L.dart';
import 'package:mirc/state/opml_state.dart';
// ignore: unused_import
import 'package:mirc/ui/library/opml_export.dart';
import 'package:mirc/ui/library/opml_import.dart';
import 'package:mirc/ui/settings/episode_refresh.dart';

import 'package:mirc/ui/settings/settings_section_label.dart';
import 'package:mirc/ui/settings/theme_select.dart';
import 'package:mirc/ui/widgets/action_text.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dialogs/flutter_dialogs.dart';
import 'package:provider/provider.dart';

/// This is the settings page and allows the user to select various
/// options for the app.
///
/// This is a self contained page and so, unlike the other forms, talks directly
/// to a settings service rather than a BLoC. Whilst this deviates slightly from
/// the overall architecture, adding a BLoC to simply be consistent with the rest
/// of the application would add unnecessary complexity.
///
/// This page is built with both Android & iOS in mind. However, the
/// rest of the application is not prepared for iOS design; this
/// is in preparation for the iOS version.
class Settings extends StatefulWidget {
  const Settings({
    super.key,
  });

  @override
  State<Settings> createState() => _SettingsState();
}

class _SettingsState extends State<Settings> {
  bool sdcard = true;

  Widget _buildList(BuildContext context) {
    var settingsBloc = Provider.of<SettingsBloc>(context);
    var podcastBloc = Provider.of<PodcastBloc>(context);
    var opmlBloc = Provider.of<OPMLBloc>(context);

    return StreamBuilder<AppSettings>(
        stream: settingsBloc.settings,
        initialData: settingsBloc.currentSettings,
        builder: (context, snapshot) {
          return ListView(
            children: [
              SettingsDividerLabel(label: L.of(context)!.settings_personalisation_divider_label),
              const ThemeSelectWidget(),
              SettingsDividerLabel(label: L.of(context)!.settings_episodes_divider_label),
              MergeSemantics(
                child: ListTile(
                  title: Text(L.of(context)!.settings_mark_deleted_played_label),
                  trailing: Switch.adaptive(
                    value: snapshot.data!.markDeletedEpisodesAsPlayed,
                    onChanged: (value) => setState(() => settingsBloc.markDeletedAsPlayed(value)),
                  ),
                ),
              ),
              MergeSemantics(
                child: ListTile(
                    shape: const RoundedRectangleBorder(side: BorderSide.none),
                    title: Text(L.of(context)!.settings_delete_played_label),
                    trailing: Switch.adaptive(
                      value: snapshot.data!.deleteDownloadedPlayedEpisodes,
                      onChanged: (value) => setState(() => settingsBloc.deleteDownloadedPlayedEpisodes(value)),
                    )),
              ),
              sdcard
                  ? MergeSemantics(
                      child: ListTile(
                        title: Text(L.of(context)!.settings_download_sd_card_label),
                        trailing: Switch.adaptive(
                          value: snapshot.data!.storeDownloadsSDCard,
                          onChanged: (value) => sdcard
                              ? setState(() {
                                  if (value) {
                                    _showStorageDialog(enableExternalStorage: true);
                                  } else {
                                    _showStorageDialog(enableExternalStorage: false);
                                  }

                                  settingsBloc.storeDownloadonSDCard(value);
                                })
                              : null,
                        ),
                      ),
                    )
                  : const SizedBox(
                      height: 0,
                      width: 0,
                    ),
              SettingsDividerLabel(label: L.of(context)!.settings_playback_divider_label),
              MergeSemantics(
                child: ListTile(
                  title: Text(L.of(context)!.settings_auto_open_now_playing),
                  trailing: Switch.adaptive(
                    value: snapshot.data!.autoOpenNowPlaying,
                    onChanged: (value) => setState(() => settingsBloc.setAutoOpenNowPlaying(value)),
                  ),
                ),
              ),
              MergeSemantics(
                child: ListTile(
                  title: Text(L.of(context)!.settings_continuous_play_option),
                  subtitle: Text(L.of(context)!.settings_continuous_play_subtitle),
                  trailing: Switch.adaptive(
                    value: snapshot.data!.autoPlay,
                    onChanged: (value) => setState(() => settingsBloc.autoPlay(value)),
                  ),
                ),
              ),
              const EpisodeRefreshWidget(),
              // OPML import/export hidden and "Data" divider removed.
            ],
          );
        });
  }

  Widget _buildAndroid(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: Theme.of(context).appBarTheme.systemOverlayStyle!,
      child: Scaffold(
        appBar: AppBar(
          elevation: 0.0,
          title: Text(
            L.of(context)!.settings_label,
          ),
        ),
        body: _buildList(context),
      ),
    );
  }

  Widget _buildIos(BuildContext context) {
    return CupertinoPageScaffold(
      navigationBar: CupertinoNavigationBar(
        padding: const EdgeInsetsDirectional.all(0.0),
        leading: CupertinoButton(
            child: Icon(
              Icons.arrow_back_ios,
              semanticLabel: L.of(context)?.go_back_button_label,
            ),
            onPressed: () {
              Navigator.pop(context);
            }),
        middle: Text(
          L.of(context)!.settings_label,
          style: TextStyle(color: Theme.of(context).colorScheme.primary),
        ),
        backgroundColor: Theme.of(context).colorScheme.surface,
      ),
      child: Material(child: _buildList(context)),
    );
  }

  void _showStorageDialog({required bool enableExternalStorage}) {
    showPlatformDialog<void>(
      context: context,
      useRootNavigator: false,
      builder: (_) => BasicDialogAlert(
        title: Text(L.of(context)!.settings_download_switch_label),
        content: Text(
          enableExternalStorage
              ? L.of(context)!.settings_download_switch_card
              : L.of(context)!.settings_download_switch_internal,
        ),
        actions: <Widget>[
          BasicDialogAction(
            title: Text(
              L.of(context)!.ok_button_label,
            ),
            onPressed: () {
              Navigator.pop(context);
            },
          ),
        ],
      ),
    );
  }

  @override
  Widget build(context) {
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return _buildAndroid(context);
      case TargetPlatform.iOS:
        return _buildIos(context);
      default:
        assert(false, 'Unexpected platform $defaultTargetPlatform');
        return _buildAndroid(context);
    }
  }

  @override
  void initState() {
    super.initState();

    hasExternalStorage().then((value) {
      setState(() {
        sdcard = value;
      });
    });
  }
}
