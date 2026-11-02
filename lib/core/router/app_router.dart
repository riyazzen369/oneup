import '../../features/privacy/privacy.dart';
import '../../features/experts/experts.dart';
import '../../features/org/org_ui.dart';
import '../../features/report/report_screen.dart';
import '../../features/plus/plus_ui.dart';
import '../../features/plus/entitlement.dart';
import '../../features/plus/services.dart';
import '../../features/report/monthly_report.dart';
import '../../features/quick/quick_check_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../features/profile/ui/edit_profile_screen.dart';
import '../../features/articles/ui/articles_ui.dart';

import '../../features/splash/splash_screen.dart';
import '../../features/onboarding/onboarding_screen.dart';
import '../../features/auth/login_screen.dart';
import '../../features/auth/otp_screen.dart';
import '../../features/profile_setup/profile_setup_screen.dart';
import '../../features/consent/consent_screen.dart';
import '../../features/shell/main_shell.dart';
import '../../features/home/home_page.dart';
import '../../features/assess/assess_page.dart';
import '../../features/assess/ui/question_screen.dart';
import '../../features/assess/ui/dimension_complete_screen.dart';
import '../../features/profile/about_screen.dart';
import '../../features/results/results_screen.dart';
import '../../features/results/dimension_detail_screen.dart';
import '../../features/results/trends_screen.dart';
import '../../features/results/circle_paradigm_screen.dart';
import '../../features/results/oneup_focus_screen.dart';
import '../theme/app_colors.dart';
import '../../features/learn/learn_page.dart';
import '../../features/learn/lesson_reader.dart';
import '../../features/games/games_page.dart';
import '../../features/games/game_screens.dart';
import '../../features/market/market_page.dart';
import '../../features/market/market_screens.dart';
import '../../features/market/market_category.dart';
import '../../features/profile/profile_page.dart';
import '../../features/consult/data/consult_models.dart';
import '../../features/consult/ui/consult_page.dart';
import '../../features/consult/ui/consultant_profile_screen.dart';
import '../../features/consult/ui/booking_screen.dart';
import '../../features/consult/ui/payment_screen.dart';
import '../../features/consult/ui/booking_confirmed_screen.dart';
import '../../features/consult/ui/my_sessions_screen.dart';
import '../../features/consult/ui/call_screen.dart';
import '../../features/companion/ui/companion_screen.dart';
import '../safety/crisis_screen.dart';

class Routes {
  static const splash = '/';
  static const onboarding = '/onboarding';
  static const login = '/login';
  static const otp = '/otp';
  static const profileSetup = '/profile-setup';
  static const consent = '/consent';
  static const home = '/home';
  static const assess = '/assess';
  static const games = '/games';
  static const learn = '/learn';
  static const market = '/market';
  static const profile = '/profile';
}

WellnessDimension? _dim(GoRouterState s) => WellnessDimension.values.where((d) => d.name == s.pathParameters['dim']).firstOrNull;
Consultant? _cons(GoRouterState s) => sampleConsultants.where((c) => c.id == s.pathParameters['id']).firstOrNull;

/// Shown for bad deep links or missing route data instead of crashing.
class NotFoundScreen extends StatelessWidget {
  const NotFoundScreen({super.key});
  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(),
        body: Center(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Text('This page is not available.'),
            TextButton(onPressed: () => context.go(Routes.home), child: const Text('Go home')),
          ]),
        ),
      );
}

final _rootKey = GlobalKey<NavigatorState>();

final routerProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    navigatorKey: _rootKey,
    initialLocation: Routes.splash,
    errorBuilder: (_, __) => const NotFoundScreen(),
    routes: [
      GoRoute(path: Routes.splash, builder: (_, __) => const SplashScreen()),
      GoRoute(path: Routes.onboarding, builder: (_, __) => const OnboardingScreen()),
      GoRoute(path: Routes.login, builder: (_, __) => const LoginScreen()),
      GoRoute(path: Routes.otp, builder: (_, s) => OtpScreen(phone: s.extra as String? ?? '')),
      GoRoute(path: Routes.profileSetup, builder: (_, __) => const ProfileSetupScreen()),
      GoRoute(path: Routes.consent, builder: (_, __) => const ConsentScreen()),
      // Assess is now opened from Home (pushed, with back), no longer a tab.
      GoRoute(path: Routes.assess, builder: (_, __) => const AssessPage()),
      GoRoute(
        path: '/assess/q/:dim',
        builder: (_, s) => _dim(s) == null ? const NotFoundScreen() : QuestionScreen(dimension: _dim(s)!),
      ),
      GoRoute(
        path: '/assess/done/:dim',
        builder: (_, s) => _dim(s) == null
            ? const NotFoundScreen()
            : DimensionCompleteScreen(
                dimension: _dim(s)!,
                score: s.extra as int? ?? 0,
              ),
      ),
      GoRoute(path: '/report', builder: (_, s) => ReportScreen(weekId: s.uri.queryParameters['week'])),
      GoRoute(path: '/plus', builder: (_, __) => const PlusScreen()),
      GoRoute(path: '/privacy', builder: (_, __) => const PrivacyScreen()),
      GoRoute(path: '/experts', builder: (_, __) => const ExpertsScreen()),
      GoRoute(path: '/org', builder: (_, __) => const OrgDashboardScreen()),
      GoRoute(path: '/org/join', builder: (_, __) => const OrgJoinScreen()),
      GoRoute(path: '/org/demo', builder: (_, __) => const OrgDemoFormScreen()),
      GoRoute(path: '/coaching', builder: (_, __) => const CoachingScreen()),
      GoRoute(path: '/support', builder: (_, __) => const SupportScreen()),
      GoRoute(path: '/reports', builder: (_, s) => ReportsDashboard(monthly: s.uri.queryParameters['view'] == 'monthly')),
      GoRoute(path: '/quick', builder: (_, __) => const QuickCheckScreen()),
      GoRoute(path: '/quick/result', builder: (_, __) => const QuickResultScreen()),
      GoRoute(path: '/results', builder: (_, __) => const ResultsScreen()),
      GoRoute(
        path: '/results/dim/:dim',
        builder: (_, s) => _dim(s) == null ? const NotFoundScreen() : DimensionDetailScreen(dimension: _dim(s)!),
      ),
      GoRoute(path: '/circle', builder: (_, __) => const CircleParadigmScreen()),
      GoRoute(path: '/focus', builder: (_, __) => const OneUpFocusScreen()),
      GoRoute(path: '/trends', builder: (_, __) => const TrendsScreen()),
      GoRoute(path: '/learn/:id', builder: (_, s) => LessonReader(id: s.pathParameters['id']!)),
      GoRoute(path: '/consult/c/:id', builder: (_, s) => _cons(s) == null ? const NotFoundScreen() : ConsultantProfileScreen(c: _cons(s)!)),
      GoRoute(
          path: '/consult/book/:id',
          builder: (_, s) => _cons(s) == null
              ? const NotFoundScreen()
              : Consumer(
                  builder: (_, ref, __) => ref.watch(isPlusProvider)
                      ? BookingScreen(c: _cons(s)!)
                      : Scaffold(
                          appBar: AppBar(title: const Text('Book a session')),
                          body: const Padding(
                            padding: EdgeInsets.all(16),
                            child: PlusLockCard(
                                feature: PlusFeature.consultation,
                                message: 'Booking a SAMPLE expert (demo booking) is part of OneUP Plus. '
                                    'Crisis help stays free and immediate for everyone.'),
                          ),
                        ))),
      GoRoute(
          path: '/consult/pay',
          builder: (_, s) => s.extra is BookingDraft ? PaymentScreen(draft: s.extra! as BookingDraft) : const NotFoundScreen()),
      GoRoute(
          path: '/consult/done',
          builder: (_, s) => s.extra is Booking ? BookingConfirmedScreen(booking: s.extra! as Booking) : const NotFoundScreen()),
      GoRoute(path: '/consult/sessions', builder: (_, __) => const MySessionsScreen()),
      GoRoute(path: '/consult/call/:id', builder: (_, s) => CallScreen(bookingId: s.pathParameters['id']!)),
      GoRoute(path: '/market/p/:id', builder: (_, s) => ProductScreen(id: s.pathParameters['id']!)),
      GoRoute(path: '/market/c/:name', builder: (_, s) => CategoryScreen(name: s.pathParameters['name']!)),
      GoRoute(path: '/market/cart', builder: (_, __) => const CartScreen()),
      GoRoute(path: '/market/checkout', builder: (_, __) => const CheckoutScreen()),
      GoRoute(path: '/market/orders', builder: (_, __) => const OrdersScreen()),
      GoRoute(path: '/market/wishlist', builder: (_, __) => const WishlistScreen()),
      GoRoute(path: '/companion', builder: (_, __) => const CompanionScreen()),
      GoRoute(path: '/games/:id', builder: (_, s) => gameScreen(s.pathParameters['id']!)),
      GoRoute(path: '/crisis', builder: (_, __) => const CrisisScreen()),
      GoRoute(path: '/about', builder: (_, __) => const AboutScreen()),
      GoRoute(path: '/articles', builder: (_, __) => const ArticlesScreen()),
      GoRoute(path: '/profile/edit', builder: (_, __) => const EditProfileScreen()),
      StatefulShellRoute.indexedStack(
        builder: (_, __, shell) => MainShell(shell: shell),
        branches: [
          StatefulShellBranch(routes: [GoRoute(path: Routes.home, builder: (_, __) => const HomePage())]),
          StatefulShellBranch(routes: [GoRoute(path: Routes.games, builder: (_, __) => const GamesPage())]),
          StatefulShellBranch(routes: [GoRoute(path: Routes.learn, builder: (_, __) => const LearnPage())]),
          StatefulShellBranch(routes: [GoRoute(path: Routes.market, builder: (_, __) => const MarketPage())]),
          StatefulShellBranch(routes: [
            GoRoute(
              path: '/consult',
              builder: (_, s) {
                final q = s.uri.queryParameters['type'];
                return ConsultPage(initialType: ConsultType.values.where((t) => t.name == q).firstOrNull);
              },
            ),
          ]),
          StatefulShellBranch(routes: [GoRoute(path: Routes.profile, builder: (_, __) => const ProfilePage())]),
        ],
      ),
    ],
  );
});
