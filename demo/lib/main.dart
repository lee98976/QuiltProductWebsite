import 'dart:ui';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart' hide FirebaseService;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:quilt/Components/navbar.dart';
import 'package:quilt/Components/confirmation_hub.dart';
import 'package:quilt/Components/parent_connection_link_listener.dart';
import 'package:quilt/Providers/current_user_profile_notifier.dart';
import 'package:quilt/Service/auth_service.dart';
import 'package:quilt/Service/calendar_account_service.dart';
import 'package:quilt/Service/firebase_service.dart';
import 'package:quilt/Service/upload_picker_service.dart';
import 'package:quilt/Utility/app_decorations.dart';
import 'package:quilt/Utility/app_theme.dart';
import 'package:quilt/Utility/startup_warmup.dart';
import 'package:quilt/firebase_options_selector.dart';
import 'Screens/loginpage.dart';

Future<void> main() async {
  PaintingBinding.shaderWarmUp = const QuiltShaderWarmUp();
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  FlutterError.onError = (details) {
    debugPrint('Demo error: ${details.exceptionAsString()}\n${details.stack}');
  };
  PlatformDispatcher.instance.onError = (error, stack) {
    debugPrint('Uncaught application error: $error\n$stack');
    return true;
  };
  ErrorWidget.builder = (details) => const Directionality(
    textDirection: TextDirection.ltr,
    child: ColoredBox(
      color: Color(0xFFF8FAFC),
      child: Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text(
            'This screen could not be displayed. Please go back and try again.',
            textAlign: TextAlign.center,
          ),
        ),
      ),
    ),
  );

  runApp(const QuiltBootstrapApp());
}

Future<void> _initializeServices() async {
  if (Firebase.apps.isEmpty) {
    await Firebase.initializeApp(
      options: QuiltFirebaseOptions.currentPlatform,
    ).timeout(const Duration(seconds: 15));
  }
  if (!kIsWeb) {
    FirebaseFirestore.instance.settings = const Settings(
      persistenceEnabled: true,
      cacheSizeBytes: 104857600,
    );
  } else {
    await FirebaseAuth.instance
        .setPersistence(Persistence.NONE)
        .timeout(const Duration(seconds: 10));
    await FirebaseAuth.instance.signOut().timeout(const Duration(seconds: 10));
  }
}

class QuiltBootstrapApp extends StatefulWidget {
  const QuiltBootstrapApp({super.key});

  @override
  State<QuiltBootstrapApp> createState() => _QuiltBootstrapAppState();
}

class _QuiltBootstrapAppState extends State<QuiltBootstrapApp> {
  late Future<void> _initialization;

  @override
  void initState() {
    super.initState();
    _initialization = _initializeServices();
  }

  void _retry() {
    setState(() => _initialization = _initializeServices());
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<void>(
      future: _initialization,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const _BootstrapMaterialApp(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(),
                SizedBox(height: 20),
                Text('Starting Quilt…'),
              ],
            ),
          );
        }
        if (snapshot.hasError) {
          return _BootstrapMaterialApp(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.cloud_off_outlined, size: 48),
                const SizedBox(height: 16),
                const Text(
                  'Quilt could not start.',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Check your connection, then try again.',
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 20),
                FilledButton.icon(
                  onPressed: _retry,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Try again'),
                ),
              ],
            ),
          );
        }

        return _buildConfiguredApp();
      },
    );
  }
}

class _BootstrapMaterialApp extends StatelessWidget {
  const _BootstrapMaterialApp({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Quilt',
      theme: AppTheme.forOption(QuiltThemeOption.options.first),
      home: Scaffold(
        body: Builder(
          builder: (context) => DecoratedBox(
            decoration: AppDecorations.screenBackground(context),
            child: SafeArea(
              child: Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 420),
                    child: child,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

Widget _buildConfiguredApp() {
  return MultiProvider(
    providers: [
      Provider(create: (_) => FirebaseService()),
      Provider(create: (_) => const UploadPickerService()),
      Provider(
        create: (context) => AuthService(context.read<FirebaseService>()),
      ),
      Provider(
        create: (context) => CalendarAccountService(
          context.read<AuthService>(),
          context.read<FirebaseService>(),
        ),
      ),
      ChangeNotifierProvider(
        create: (context) => CurrentUserProfileNotifier(
          context.read<AuthService>(),
          context.read<FirebaseService>(),
        ),
      ),
    ],
    child: const MyApp(),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    final themeId = context.select<CurrentUserProfileNotifier, String?>(
      (notifier) => notifier.profile?.appThemeId,
    );
    final themeOption = QuiltThemeOption.byId(themeId);

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Quilt',
      theme: AppTheme.forOption(themeOption),
      builder: (context, child) {
        return QuiltConfirmationHost(child: child ?? const SizedBox.shrink());
      },
      home: const ParentConnectionLinkListener(
        child: MyHomePage(title: 'Quilt Home Page'),
      ),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});

  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  @override
  Widget build(BuildContext context) {
    final auth = context.read<AuthService>();
    final profileGate = context
        .select<
          CurrentUserProfileNotifier,
          ({
            bool isGuestSession,
            bool loading,
            bool hasProfile,
            String? loadError,
          })
        >(
          (notifier) => (
            isGuestSession: notifier.isGuestSession,
            loading: notifier.loading,
            hasProfile: notifier.profile != null,
            loadError: notifier.loadError,
          ),
        );

    if (profileGate.isGuestSession) {
      return const Navbar();
    }

    return StreamBuilder<User?>(
      stream: auth.authStateChanges,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Scaffold(
            body: SizedBox.expand(
              child: DecoratedBox(
                decoration: AppDecorations.screenBackground(context),
                child: const Center(child: CircularProgressIndicator()),
              ),
            ),
          );
        } else if (auth.currentUser != null &&
            !auth.isCurrentUserSupportedAccount) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              auth.signOut();
            }
          });
          return const LoginPage();
        } else if (auth.currentUser != null) {
          if (profileGate.loading) {
            return Scaffold(
              body: SizedBox.expand(
                child: DecoratedBox(
                  decoration: AppDecorations.screenBackground(context),
                  child: const Center(child: CircularProgressIndicator()),
                ),
              ),
            );
          }
          if (profileGate.loadError != null) {
            return _ProfileLoadFailure(
              onRetry: context.read<CurrentUserProfileNotifier>().refresh,
              onSignOut: context.read<CurrentUserProfileNotifier>().signOut,
            );
          }
          if (!profileGate.hasProfile) {
            return const LoginPage();
          }
          return const Navbar();
        } else {
          return const LoginPage();
        }
      },
    );
  }
}

class _ProfileLoadFailure extends StatefulWidget {
  const _ProfileLoadFailure({required this.onRetry, required this.onSignOut});

  final Future<void> Function() onRetry;
  final Future<void> Function() onSignOut;

  @override
  State<_ProfileLoadFailure> createState() => _ProfileLoadFailureState();
}

class _ProfileLoadFailureState extends State<_ProfileLoadFailure> {
  bool _working = false;

  Future<void> _run(Future<void> Function() action) async {
    setState(() => _working = true);
    try {
      await action();
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: DecoratedBox(
        decoration: AppDecorations.screenBackground(context),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 440),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.sync_problem_outlined, size: 52),
                    const SizedBox(height: 16),
                    Text(
                      'We could not load your Quilt profile.',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Check your connection and try again. You can also sign out and use a different account.',
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 20),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        onPressed: _working ? null : () => _run(widget.onRetry),
                        icon: const Icon(Icons.refresh),
                        label: const Text('Try again'),
                      ),
                    ),
                    const SizedBox(height: 8),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: _working
                            ? null
                            : () => _run(widget.onSignOut),
                        icon: const Icon(Icons.logout),
                        label: const Text('Sign out'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
