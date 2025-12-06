// Copyright 2025 Ammar Bin Abrar and the project contributors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

// ignore_for_file: avoid_print

import 'dart:async';

import 'package:mirc/api/podcast/mobile_podcast_api.dart';
import 'package:mirc/api/podcast/podcast_api.dart';
// ignore: unused_import
import 'package:mirc/bloc/discovery/discovery_bloc.dart';
import 'package:mirc/bloc/podcast/audio_bloc.dart';
import 'package:mirc/bloc/podcast/episode_bloc.dart';
import 'package:mirc/bloc/podcast/opml_bloc.dart';
import 'package:mirc/bloc/podcast/podcast_bloc.dart';
import 'package:mirc/bloc/podcast/queue_bloc.dart';
import 'package:mirc/bloc/search/search_bloc.dart';
import 'package:mirc/bloc/settings/settings_bloc.dart';
import 'package:mirc/bloc/ui/pager_bloc.dart';
import 'package:mirc/core/environment.dart';
import 'package:mirc/entities/feed.dart';
import 'package:mirc/entities/podcast.dart';
import 'package:mirc/l10n/L.dart';
import 'package:mirc/navigation/navigation_route_observer.dart';
import 'package:mirc/repository/repository.dart';
import 'package:mirc/repository/sembast/sembast_repository.dart';
import 'package:mirc/services/audio/audio_player_service.dart';
import 'package:mirc/services/audio/default_audio_player_service.dart';
import 'package:mirc/services/download/download_service.dart';
import 'package:mirc/services/download/mobile_download_manager.dart';
import 'package:mirc/services/download/mobile_download_service.dart';
import 'package:mirc/services/podcast/mobile_opml_service.dart';
import 'package:mirc/services/podcast/mobile_podcast_service.dart';
import 'package:mirc/services/podcast/opml_service.dart';
import 'package:mirc/services/podcast/podcast_service.dart';
import 'package:mirc/services/settings/mobile_settings_service.dart';
// ignore: unused_import
import 'package:mirc/ui/library/discovery.dart';
import 'package:mirc/ui/library/downloads.dart';
import 'package:mirc/ui/library/library.dart';
import 'package:mirc/ui/podcast/mini_player.dart';
import 'package:mirc/ui/podcast/podcast_details.dart';

import 'package:mirc/ui/settings/settings.dart';
import 'package:mirc/ui/themes.dart';
// ignore: unused_import
import 'package:mirc/ui/widgets/action_text.dart';
import 'package:mirc/ui/widgets/layout_selector.dart';
// ignore: unused_import
import 'package:mirc/ui/widgets/search_slide_route.dart';
import 'package:app_links/app_links.dart';
// ignore: unnecessary_import
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart' show SchedulerBinding;
import 'package:flutter/services.dart';

import 'package:flutter_localizations/flutter_localizations.dart';
// import 'package:flutter_native_splash/flutter_native_splash.dart';
import 'package:logging/logging.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../services/settings/settings_service.dart';

var theme = Themes.lightTheme().themeData;

/// mirc is a Podcast player. You can search and subscribe to podcasts,
/// download and stream episodes and view the latest podcast charts.
// ignore: must_be_immutable
class mircPodcastApp extends StatefulWidget {
  final Repository repository;
  late PodcastApi podcastApi;
  late DownloadService downloadService;
  late AudioPlayerService audioPlayerService;
  late OPMLService opmlService;
  PodcastService? podcastService;
  SettingsBloc? settingsBloc;
  MobileSettingsService mobileSettingsService;
  List<int> certificateAuthorityBytes;

  mircPodcastApp({
    super.key,
    required this.mobileSettingsService,
    required this.certificateAuthorityBytes,
  }) : repository = SembastRepository() {
    _initializeServices();
  }

  void _initializeServices() {
    try {
      // Initialize API
      podcastApi = MobilePodcastApi();
      podcastApi.addClientAuthorityBytes(certificateAuthorityBytes);

      // Initialize podcast service
      podcastService = MobilePodcastService(
        api: podcastApi,
        repository: repository,
        settingsService: mobileSettingsService,
      );

      assert(podcastService != null, 'Podcast service initialization failed');

      // Initialize download service
      downloadService = MobileDownloadService(
        repository: repository,
        downloadManager: MobileDownloaderManager(),
        podcastService: podcastService!,
      );

      // Initialize audio service
      audioPlayerService = DefaultAudioPlayerService(
        repository: repository,
        settingsService: mobileSettingsService,
        podcastService: podcastService!,
      );

      // Initialize settings
      settingsBloc = SettingsBloc(mobileSettingsService);

      // Initialize OPML service
      opmlService = MobileOPMLService(
        podcastService: podcastService!,
        repository: repository,
      );
    } catch (e, stackTrace) {
      // ignore: duplicate_ignore
      // ignore: avoid_print
      print('Error initializing services: $e');
      // ignore: duplicate_ignore
      // ignore: avoid_print
      print(stackTrace);
      rethrow;
    }
  }

  @override
  mircPodcastAppState createState() => mircPodcastAppState();
}

class mircPodcastAppState extends State<mircPodcastApp> {
  ThemeData? theme;

  @override
  void initState() {
    super.initState();
    
    // Initialize app state
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      // Show the library screen first and let the podcast load
      if (mounted) {
        final podcastBloc = Provider.of<PodcastBloc>(context, listen: false);
        podcastBloc.podcastEvent(PodcastEvent.reloadSubscriptions);
      }
    });

    /// Listen to theme change events from settings.
    widget.settingsBloc!.settings.listen((event) {
      setState(() {
        var newTheme = Themes.darkTheme().themeData;

        /// As we add new themes, we will move this selection into its own theme module.
        switch (event.theme) {
          case 'system':
            var brightness = SchedulerBinding.instance.platformDispatcher.platformBrightness;
            newTheme = brightness == Brightness.dark ? Themes.darkTheme().themeData : Themes.lightTheme().themeData;
            break;
          case 'light':
            newTheme = Themes.lightTheme().themeData;
            break;
          case 'dark':
            newTheme = Themes.darkTheme().themeData;
            break;
        }

        /// Only update the theme if it has changed.
        if (newTheme != theme) {
          theme = newTheme;
        }
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        Provider<SearchBloc>(
          create: (_) => SearchBloc(
            podcastService: widget.podcastService!,
          ),
          dispose: (_, value) => value.dispose(),
        ),
        
        Provider<EpisodeBloc>(
          create: (_) =>
              EpisodeBloc(podcastService: widget.podcastService!, audioPlayerService: widget.audioPlayerService),
          dispose: (_, value) => value.dispose(),
        ),
        Provider<PodcastBloc>(
          create: (_) => PodcastBloc(
              podcastService: widget.podcastService!,
              audioPlayerService: widget.audioPlayerService,
              downloadService: widget.downloadService,
              settingsService: widget.mobileSettingsService),
          dispose: (_, value) => value.dispose(),
        ),
        Provider<PagerBloc>(
          create: (_) => PagerBloc(),
          dispose: (_, value) => value.dispose(),
        ),
        Provider<AudioBloc>(
          create: (_) => AudioBloc(audioPlayerService: widget.audioPlayerService),
          dispose: (_, value) => value.dispose(),
        ),
        Provider<SettingsBloc?>(
          create: (_) => widget.settingsBloc,
          dispose: (_, value) => value!.dispose(),
        ),
        Provider<OPMLBloc>(
          create: (_) => OPMLBloc(opmlService: widget.opmlService),
          dispose: (_, value) => value.dispose(),
        ),
        Provider<QueueBloc>(
          create: (_) => QueueBloc(
            audioPlayerService: widget.audioPlayerService,
            podcastService: widget.podcastService!,
          ),
          dispose: (_, value) => value.dispose(),
        )
      ],
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        showSemanticsDebugger: false,
        title: 'MIRC Podcast App',
        navigatorObservers: [NavigationRouteObserver()],
        localizationsDelegates: const <LocalizationsDelegate<Object>>[
          mircLocalisationsDelegate(),
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: const [
          Locale('en', ''),
          Locale('es', ''),
          Locale('de', ''),
          Locale('gl', ''),
          Locale('it', ''),
          Locale('nl', ''),
          Locale('ru', ''),
          Locale('vi', ''),
        ],
        theme: theme,
        // Uncomment builder below to enable accessibility checker tool.
        // builder: (context, child) => AccessibilityTools(child: child),
        home: const mircHomePage(title: 'MIRC Podcast App'),
      ),
    );
  }
}

class mircHomePage extends StatefulWidget {
  final String? title;
  final bool topBarVisible;

  const mircHomePage({
    super.key,
    this.title,
    this.topBarVisible = true,
  });

  @override
  State<mircHomePage> createState() => _mircHomePageState();
}

class _mircHomePageState extends State<mircHomePage> with WidgetsBindingObserver {
  StreamSubscription<Uri>? deepLinkSubscription;
  bool _initialSubscriptionsLoaded = false;

  final log = Logger('_mircHomePageState');
  bool handledInitialLink = false;
  Widget? library;

  // Define RSS feeds with order - Islam Fort first, then Masjid Rehman
  // Only include valid, working RSS feeds
  final List<Map<String, dynamic>> rssFeeds = [
    {
      'url': 'http://masjidrehman.pk/MIRCAppRSSFeeds/islamfort_podcast.xml',
      'name': 'Islam Fort',
      'order': 1, // First position
    },
    {
      'url': 'http://masjidrehman.pk/MIRCAppRSSFeeds/jamiat_podcast.xml',
      'name': 'Jamiat ahl-Hadith',
      'order': 2, // Second position
    },
    {
      'url': 'https://masjidrehman.pk/category/audios/feed/',
      'name': 'Masjid Rehman',
      'order': 4, // Fourth position
    },

    // Add more RSS feeds here only if they are valid and working
    // Remove any feed that causes "Failed to load" errors
  ];

  @override
  void initState() {
    super.initState();

    final audioBloc = Provider.of<AudioBloc>(context, listen: false);
    final podcastBloc = Provider.of<PodcastBloc>(context, listen: false);

    WidgetsBinding.instance.addObserver(this);

    audioBloc.transitionLifecycleState(LifecycleState.resume);

    /// Handle deep links
    _setupLinkListener();

    // Load and subscribe to multiple RSS feeds automatically in order
    _loadMultiplePodcastsInOrder();
  }

  void _loadMultiplePodcastsInOrder() async {
    if (_initialSubscriptionsLoaded) return;
    
    try {
      final podcastBloc = Provider.of<PodcastBloc>(context, listen: false);
      
      // Sort feeds by order
      rssFeeds.sort((a, b) => (a['order'] as int).compareTo(b['order'] as int));
      
      int successfulSubscriptions = 0;
      int failedSubscriptions = 0;
      List<String> failedFeeds = [];
      
      for (var feed in rssFeeds) {
        try {
          final String feedUrl = feed['url'];
          final String feedName = feed['name'];
          final int order = feed['order'];
          
          print('Loading podcast $order: $feedName');
          
          // Validate URL before attempting to load
          if (!_isValidUrl(feedUrl)) {
            print('Invalid URL: $feedUrl');
            failedSubscriptions++;
            failedFeeds.add('$feedName (Invalid URL)');
            continue;
          }
          
          final podcast = Podcast.fromUrl(url: feedUrl);
          
          // Load the podcast first with better error handling
          final loadedPodcast = await podcastBloc.podcastService.loadPodcast(
            podcast: podcast,
            highlightNewEpisodes: false,
            refresh: true,
          ).catchError((error, stackTrace) {
            print('Error loading podcast $feedName: $error');
            print('Stack trace: $stackTrace');
            return null;
          });
          
          if (loadedPodcast != null) {
            // Try to subscribe with error handling
            try {
              await podcastBloc.podcastService.subscribe(loadedPodcast);
              successfulSubscriptions++;
              print('Successfully subscribed to position $order: $feedName');
            } catch (subscribeError) {
              print('Error subscribing to $feedName: $subscribeError');
              failedSubscriptions++;
              failedFeeds.add('$feedName (Subscribe Error)');
            }
          } else {
            print('Failed to load podcast: $feedName');
            failedSubscriptions++;
            failedFeeds.add('$feedName (Load Failed)');
          }
        } catch (e) {
          print('Error processing ${feed['name']}: $e');
          failedSubscriptions++;
          failedFeeds.add('${feed['name']} (Processing Error)');
        }
        
        // Add a small delay between subscriptions to avoid overwhelming the system
        await Future.delayed(const Duration(milliseconds: 1000));
      }
      
      // Reload the library to show all subscriptions
      if (mounted) {
        podcastBloc.podcastEvent(PodcastEvent.reloadSubscriptions);
        
        // Show success/error message
        if (successfulSubscriptions > 0 || failedSubscriptions > 0) {
          String message = 'Successfully subscribed to $successfulSubscriptions podcasts';
          if (failedSubscriptions > 0) {
            message += '. Failed: $failedSubscriptions podcasts';
            if (failedFeeds.isNotEmpty) {
              message += '\nFailed feeds: ${failedFeeds.join(', ')}';
            }
          }
          
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(message),
              duration: const Duration(seconds: 5),
              action: failedSubscriptions > 0 ? SnackBarAction(
                label: 'Details',
                onPressed: () {
                  _showFailedFeedsDialog(failedFeeds);
                },
              ) : null,
            ),
          );
        }
      }
      
      _initialSubscriptionsLoaded = true;
      
    } catch (e) {
      print('Error loading multiple podcasts: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading podcasts: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    }
  }

  // Helper method to validate URLs
  bool _isValidUrl(String url) {
    try {
      final uri = Uri.parse(url);
      return uri.isAbsolute && (uri.scheme == 'http' || uri.scheme == 'https');
    } catch (e) {
      return false;
    }
  }

  // Show dialog with failed feeds details
  void _showFailedFeedsDialog(List<String> failedFeeds) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Failed to Load Podcasts'),
          content: SizedBox(
            width: double.maxFinite,
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: failedFeeds.length,
              itemBuilder: (context, index) {
                return ListTile(
                  leading: const Icon(Icons.error, color: Colors.red),
                  title: Text(failedFeeds[index]),
                );
              },
            ),
          ),
          actions: <Widget>[
            TextButton(
              child: const Text('OK'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }

  /// We listen to external links from outside the app. For example, someone may navigate
  /// to a web page that supports 'Open with mirc'.
  void _setupLinkListener() async {
    final appLinks = AppLinks(); // AppLinks is singleton

    // Subscribe to all events (initial link and further)
    deepLinkSubscription = appLinks.uriLinkStream.listen((uri) {
      // Do something (navigation, ...)
      _handleLinkEvent(uri);
    });
  }

  /// This method handles the actual link supplied from [uni_links], either
  /// at app startup or during running.
  void _handleLinkEvent(Uri uri) async {
    if ((uri.scheme == 'MIRC-subscribe' || uri.scheme == 'https') &&
        (uri.query.startsWith('uri=') || uri.query.startsWith('url='))) {
      var path = uri.query.substring(4);
      var loadPodcastBloc = Provider.of<PodcastBloc>(context, listen: false);
      var routeName = NavigationRouteObserver().top!.settings.name;

      /// If we are currently on the podcast details page, we can simply request (via
      /// the BLoC) that we load this new URL. If not, we pop the stack until we are
      /// back at root and then load the podcast details page.
      if (routeName != null && routeName == 'podcastdetails') {
        loadPodcastBloc.load(Feed(
          podcast: Podcast.fromUrl(url: path),
          backgroundFetch: false,
          errorSilently: false,
        ));
      } else {
        /// Pop back to route.
        Navigator.of(context).popUntil((route) {
          var currentRouteName = NavigationRouteObserver().top!.settings.name;

          return currentRouteName == null || currentRouteName == '' || currentRouteName == '/';
        });

        /// Once we have reached the root route, push podcast details.
        await Navigator.push(
          context,
          MaterialPageRoute<void>(
              fullscreenDialog: true,
              settings: const RouteSettings(name: 'podcastdetails'),
              builder: (context) => PodcastDetails(Podcast.fromUrl(url: path), loadPodcastBloc)),
        );
      }
    }
  }

  @override
  void dispose() {
    final audioBloc = Provider.of<AudioBloc>(context, listen: false);
    audioBloc.transitionLifecycleState(LifecycleState.pause);

    deepLinkSubscription?.cancel();

    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) async {
    final audioBloc = Provider.of<AudioBloc>(context, listen: false);
    var settingsBloc = Provider.of<SettingsBloc>(context, listen: false);

    switch (state) {
      case AppLifecycleState.resumed:
        audioBloc.transitionLifecycleState(LifecycleState.resume);
        if (context.mounted) {
          SettingsService? settings = await MobileSettingsService.instance();
          settingsBloc.theme(settings!.theme);
        }
        break;
      case AppLifecycleState.paused:
        audioBloc.transitionLifecycleState(LifecycleState.pause);
        break;
      default:
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final pager = Provider.of<PagerBloc>(context);
    final searchBloc = Provider.of<EpisodeBloc>(context);
    final backgroundColour = Theme.of(context).scaffoldBackgroundColor;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: Theme.of(context).appBarTheme.systemOverlayStyle!,
      child: Scaffold(
        backgroundColor: backgroundColour,
        body: Column(
          children: <Widget>[
            Expanded(
              child: CustomScrollView(
                slivers: <Widget>[
                  SliverVisibility(
                    visible: widget.topBarVisible,
                    sliver: SliverAppBar(
                      title: const ExcludeSemantics(
                        child: TitleWidget(),
                      ),
                      backgroundColor: backgroundColour,
                      floating: false,
                      pinned: true,
                      snap: false,
                      automaticallyImplyLeading: false,  // This removes the back button
                      actions: <Widget>[
                        PopupMenuButton<String>(
                          onSelected: _menuSelect,
                          icon: Icon(
                            Icons.more_vert,
                            semanticLabel: L.of(context)!.podcast_options_overflow_menu_semantic_label,
                          ),
                          itemBuilder: (BuildContext context) {
                            return <PopupMenuEntry<String>>[
                              if (feedbackUrl.isNotEmpty)
                                PopupMenuItem<String>(
                                  textStyle: Theme.of(context).textTheme.titleMedium,
                                  value: 'feedback',
                                  child: Focus(
                                    child: Row(
                                      crossAxisAlignment: CrossAxisAlignment.center,
                                      children: [
                                        const Padding(
                                          padding: EdgeInsets.only(right: 8.0),
                                          child: Icon(Icons.feedback_outlined, size: 18.0),
                                        ),
                                        Expanded(
                                          child: Text(L.of(context)!.feedback_menu_item_label),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              PopupMenuItem<String>(
                                textStyle: Theme.of(context).textTheme.titleMedium,
                                value: 'settings',
                                child: Row(
                                  children: [
                                    const Padding(
                                      padding: EdgeInsets.only(right: 8.0),
                                      child: Icon(Icons.settings, size: 18.0),
                                    ),
                                    Expanded(
                                      child: Text(L.of(context)!.settings_label),
                                    ),
                                  ],
                                ),
                              ),
                              PopupMenuItem<String>(
                                textStyle: Theme.of(context).textTheme.titleMedium,
                                value: 'about',
                                child: Row(
                                  children: [
                                    const Padding(
                                      padding: EdgeInsets.only(right: 8.0),
                                      child: Icon(Icons.info_outline, size: 18.0),
                                    ),
                                    Expanded(
                                      child: Text(L.of(context)!.about_label),
                                    ),
                                  ],
                                ),
                              ),
                            ];
                          },
                        ),
                      ],
                    ),
                  ),
                  StreamBuilder<int>(
                      stream: pager.currentPage,
                      builder: (BuildContext context, AsyncSnapshot<int> snapshot) {
                        return _fragment(snapshot.data, searchBloc);
                      }),
                ],
              ),
            ),
            const MiniPlayer(),
          ],
        ),
        bottomNavigationBar: StreamBuilder<int>(
            stream: pager.currentPage,
            initialData: 0,
            builder: (BuildContext context, AsyncSnapshot<int> snapshot) {
              int index = snapshot.data ?? 0;

              return BottomNavigationBar(
                type: BottomNavigationBarType.fixed,
                backgroundColor: Theme.of(context).bottomAppBarTheme.color,
                selectedIconTheme: Theme.of(context).iconTheme,
                selectedItemColor: Theme.of(context).iconTheme.color,
                selectedFontSize: 11.0,
                unselectedFontSize: 11.0,
                unselectedItemColor:
                    HSLColor.fromColor(Theme.of(context).bottomAppBarTheme.color!).withLightness(0.8).toColor(),
                currentIndex: index,
                onTap: pager.changePage,
                items: <BottomNavigationBarItem>[
                  BottomNavigationBarItem(
                    icon: index == 0 ? const Icon(Icons.library_music) : const Icon(Icons.library_music_outlined),
                    label: L.of(context)!.library,
                  ),
                  BottomNavigationBarItem(
                    icon: index == 1 ? const Icon(Icons.download) : const Icon(Icons.download_outlined),
                    label: L.of(context)!.downloads,
                  ),
                ],
              );
            }),
      ),
    );
  }

  Widget _fragment(int? index, EpisodeBloc searchBloc) {
    if (index == 0) {
      return const Library();
    } else {
      return const Downloads();
    }
  }

  void _menuSelect(String choice) async {
    final theme = Theme.of(context);

    switch (choice) {
      case 'about':
        showAboutDialog(
            context: context,
            applicationName: 'MIRC Podcast App',
            applicationVersion: 'v${Environment.projectVersion}',
            applicationIcon: Image.asset(
              'assets/images/mirc-logo.png',
              width: 52.0,
              height: 52.0,
            ),
            children: <Widget>[
              const Text('\u00a9 2025 Ammar Bin Abrar'),
              GestureDetector(
                onTap: () {
                  _launchEmail();
                },
                child: Text(
                  'hello@mirc.app',
                  style: TextStyle(
                    decoration: TextDecoration.underline,
                    // ignore: deprecated_member_use
                    color: Theme.of(context).indicatorColor,
                  ),
                ),
              ),
            ]);
        break;
      case 'settings':
        await Navigator.push(
          context,
          MaterialPageRoute<void>(
            fullscreenDialog: true,
            settings: const RouteSettings(name: 'settings'),
            builder: (context) => const Settings(),
          ),
        );
        break;
      case 'feedback':
        _launchFeedback();
        break;
      case 'layout':
        await showModalBottomSheet<void>(
          context: context,
          backgroundColor: theme.secondaryHeaderColor,
          barrierLabel: L.of(context)!.scrim_layout_selector,
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(16.0),
              topRight: Radius.circular(16.0),
            ),
          ),
          builder: (context) => const LayoutSelectorWidget(),
        );
        break;
    }
  }

  void _launchFeedback() async {
    final uri = Uri.parse(feedbackUrl);

    if (!await launchUrl(
      uri,
      mode: LaunchMode.externalApplication,
    )) {
      throw Exception('Could not launch $uri');
    }
  }

  void _launchEmail() async {
    final uri = Uri.parse('mailto:hello@mircplayer.app');

    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    } else {
      throw 'Could not launch $uri';
    }
  }
}

class TitleWidget extends StatelessWidget {
  const TitleWidget({
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final titleTheme = Theme.of(context).textTheme.titleLarge?.copyWith(
          fontWeight: FontWeight.bold,
          fontFamily: 'MontserratRegular',
          fontSize: 18,
        );

    return Text(
      'MIRC Podcast App',
      style: titleTheme,
    );
  }
}



