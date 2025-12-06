import 'package:flutter/material.dart';
import 'package:mirc/ui/mirc_podcast_app.dart';
import 'package:mirc/services/settings/mobile_settings_service.dart';

class SplashScreen extends StatefulWidget {
  final MobileSettingsService mobileSettingsService;
  final List<int> certificateAuthorityBytes;

  const SplashScreen({
    super.key,
    required this.mobileSettingsService,
    required this.certificateAuthorityBytes,
  });

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();

    // Initialize the AnimationController with a duration
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    );

    // Fade-in effect using a 'easeIn' curve
    _fadeAnimation = CurvedAnimation(parent: _controller, curve: Curves.easeIn);
    
    // Scale effect with a more elastic feel, using 'easeInOut' for smoothness
    _scaleAnimation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeInOut,
    );

    // Start the animation after a slight delay for smoothness
    Future.delayed(const Duration(milliseconds: 200), () {
      _controller.forward();
    });

    // After the animation, navigate to the next screen
    Future.delayed(const Duration(seconds: 3), () {
      Navigator.pushReplacement(
        // ignore: use_build_context_synchronously
        context,
        MaterialPageRoute(
          builder: (_) => mircPodcastApp(
            mobileSettingsService: widget.mobileSettingsService,
            certificateAuthorityBytes: widget.certificateAuthorityBytes,
          ),
        ),
      );
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0A),
      body: Center(
        child: FadeTransition(
          opacity: _fadeAnimation,
          child: ScaleTransition(
            scale: _scaleAnimation,
            child: Image.asset(
              'assets/images/mirc-logo.png',
              width: 230, // You can tweak the size here if needed
              height: 230, // Adjust as per your design
            ),
          ),
        ),
      ),
    );
  }
}
