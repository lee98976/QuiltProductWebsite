import 'package:flutter/material.dart';
import 'package:quilt/Providers/current_user_profile_notifier.dart';
import '../Screens/eventpage.dart';
import '../Screens/clubpage.dart';
import '../Screens/homepage.dart';
import '../Screens/parent_events_page.dart';
import '../Screens/parent_students_page.dart';
import '../Screens/prospective_schools_page.dart';
import '../Screens/userpage.dart';
import '../Utility/AppSpacing.dart';
import '../Utility/app_decorations.dart';
import 'package:provider/provider.dart';
import 'package:flutter_floating_bottom_bar/flutter_floating_bottom_bar.dart';
import 'deferred_content.dart';

class Navbar extends StatefulWidget {
  const Navbar({super.key});

  @override
  State<Navbar> createState() {
    return NavbarState();
  }
}

class _NavItem {
  const _NavItem({
    required this.icon,
    required this.selectedIcon,
    required this.label,
    required this.index,
  });

  final IconData icon;
  final IconData selectedIcon;
  final String label;
  final int index;
}

class NavbarState extends State<Navbar> {
  int currentIndex = 0;
  List<Widget>? _cachedBasePages;
  _NavbarPageSignature? _cachedPageSignature;
  final _userPageKey = GlobalKey<UserPageState>();

  void _selectTab(int index) {
    if (currentIndex == index) return;
    setState(() {
      currentIndex = index;
    });
  }

  void _openHallPassInProfile() {
    _selectTab(3);
    _openHallPassAfterFrame();
  }

  void _openHallPassAfterFrame([int attempt = 0]) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final userPageState = _userPageKey.currentState;
      if (userPageState != null) {
        userPageState.openHallPassScanner();
        return;
      }
      if (attempt < 2) {
        _openHallPassAfterFrame(attempt + 1);
      }
    });
  }

  List<Widget> _cachedTabPages(
    BuildContext context, {
    required bool profileLoading,
    required String? profileLoadError,
    required String? schoolId,
    required bool isParent,
    required bool isProspectiveStudent,
    required int profileRevision,
  }) {
    final signature = _NavbarPageSignature(
      profileLoading: profileLoading,
      profileLoadError: profileLoadError,
      schoolId: schoolId,
      isParent: isParent,
      isProspectiveStudent: isProspectiveStudent,
      profileRevision: profileRevision,
    );
    if (_cachedPageSignature == signature && _cachedBasePages != null) {
      return _cachedBasePages!;
    }

    final pages = _tabPages(
      context,
      profileLoading: profileLoading,
      profileLoadError: profileLoadError,
      schoolId: schoolId,
      isParent: isParent,
      isProspectiveStudent: isProspectiveStudent,
      profileRevision: profileRevision,
    );
    _cachedPageSignature = signature;
    _cachedBasePages = pages;
    return _cachedBasePages!;
  }

  Widget _clubsTabContent(
    BuildContext context, {
    required bool profileLoading,
    required String? profileLoadError,
    required String? schoolId,
  }) {
    final theme = Theme.of(context);

    if (profileLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (profileLoadError != null) {
      return Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Text(
            'Could not load your profile from Firestore.\n\n'
            '$profileLoadError\n\n'
            'Check security rules for Users/{uid} and your network.',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.error,
            ),
          ),
        ),
      );
    }

    final sid = schoolId;
    if (sid == null || sid.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Text(
            'Your profile is not connected to a school yet, so clubs cannot load.\n\n'
            'Choose your school during sign up again, or ask an administrator to connect your profile to a school.',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    return ClubPage(key: ValueKey(sid), schoolID: sid);
  }

  List<Widget> _tabPages(
    BuildContext context, {
    required bool profileLoading,
    required String? profileLoadError,
    required String? schoolId,
    required bool isParent,
    required bool isProspectiveStudent,
    required int profileRevision,
  }) {
    if (isProspectiveStudent) {
      return [
        HomePage(onNavigateToTab: _selectTab),
        const ProspectiveSchoolsPage(),
        UserPage(key: _userPageKey),
      ];
    }

    final clubs = _clubsTabContent(
      context,
      profileLoading: profileLoading,
      profileLoadError: profileLoadError,
      schoolId: schoolId,
    );

    if (isParent) {
      return [
        HomePage(onNavigateToTab: _selectTab),
        const ParentStudentsPage(),
        const ProspectiveSchoolsPage(),
        const ParentEventsPage(),
        UserPage(key: _userPageKey),
      ];
    }

    return [
      HomePage(
        onNavigateToTab: _selectTab,
        onOpenHallPass: _openHallPassInProfile,
      ),
      clubs,
      const EventPage(),
      UserPage(key: _userPageKey),
    ];
  }

  Widget _buildNavButton({
    required IconData icon,
    required IconData selectedIcon,
    required String label,
    required int index,
    required ThemeData theme,
  }) {
    final isSelected = currentIndex == index;
    final colorScheme = theme.colorScheme;

    return Expanded(
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            _selectTab(index);
          },
          borderRadius: BorderRadius.circular(16),
          splashColor: colorScheme.primary.withValues(alpha: 0.12),
          highlightColor: colorScheme.primary.withValues(alpha: 0.08),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  isSelected ? selectedIcon : icon,
                  color: isSelected
                      ? colorScheme.primary
                      : colorScheme.onSurfaceVariant,
                  size: 24,
                ),
                const SizedBox(height: 4),
                Text(
                  label,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: isSelected
                        ? colorScheme.onSurface
                        : colorScheme.onSurfaceVariant,
                    fontWeight: isSelected
                        ? FontWeight.w600
                        : FontWeight.normal,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  List<_NavItem> _navItemsFor({
    required bool isParent,
    required bool isProspectiveStudent,
  }) {
    if (isParent) {
      return [
        _NavItem(
          icon: Icons.home_outlined,
          selectedIcon: Icons.home,
          label: 'Home',
          index: 0,
        ),
        _NavItem(
          icon: Icons.supervisor_account_outlined,
          selectedIcon: Icons.supervisor_account,
          label: 'Students',
          index: 1,
        ),
        _NavItem(
          icon: Icons.school_outlined,
          selectedIcon: Icons.school,
          label: 'Schools',
          index: 2,
        ),
        _NavItem(
          icon: Icons.event_outlined,
          selectedIcon: Icons.event,
          label: 'Events',
          index: 3,
        ),
        _NavItem(
          icon: Icons.person_outline,
          selectedIcon: Icons.person,
          label: 'Profile',
          index: 4,
        ),
      ];
    }

    if (isProspectiveStudent) {
      return [
        _NavItem(
          icon: Icons.home_outlined,
          selectedIcon: Icons.home,
          label: 'Home',
          index: 0,
        ),
        _NavItem(
          icon: Icons.school_outlined,
          selectedIcon: Icons.school,
          label: 'Schools',
          index: 1,
        ),
        _NavItem(
          icon: Icons.person_outline,
          selectedIcon: Icons.person,
          label: 'Profile',
          index: 2,
        ),
      ];
    }

    return [
      _NavItem(
        icon: Icons.home_outlined,
        selectedIcon: Icons.home,
        label: 'Home',
        index: 0,
      ),
      _NavItem(
        icon: Icons.people_outlined,
        selectedIcon: Icons.people,
        label: 'Clubs',
        index: 1,
      ),
      _NavItem(
        icon: Icons.event_outlined,
        selectedIcon: Icons.event,
        label: 'Events',
        index: 2,
      ),
      _NavItem(
        icon: Icons.person_outline,
        selectedIcon: Icons.person,
        label: 'Profile',
        index: 3,
      ),
    ];
  }

  Widget _buildPageStack(BuildContext context) {
    return Selector<
      CurrentUserProfileNotifier,
      ({
        bool loading,
        String? err,
        String? schoolId,
        bool isParent,
        bool isProspectiveStudent,
        int pageRevision,
      })
    >(
      selector: (_, n) => (
        loading: n.loading,
        err: n.loadError,
        schoolId: n.profile?.schoolID,
        isParent: n.profile?.isParent ?? false,
        isProspectiveStudent: n.profile?.isProspectiveStudent ?? false,
        pageRevision: n.profile?.isParent == true ? n.profileRevision : 0,
      ),
      builder: (context, slice, _) {
        final pages = _cachedTabPages(
          context,
          profileLoading: slice.loading,
          profileLoadError: slice.err,
          schoolId: slice.schoolId,
          isParent: slice.isParent,
          isProspectiveStudent: slice.isProspectiveStudent,
          profileRevision: slice.pageRevision,
        );
        if (currentIndex >= pages.length) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) _selectTab(0);
          });
        }
        final safeIndex = currentIndex >= pages.length ? 0 : currentIndex;
        return IndexedStack(
          index: safeIndex,
          children: [
            for (var i = 0; i < pages.length; i++)
              RepaintBoundary(
                key: ValueKey('nav_page_$i'),
                child: DeferredContent(
                  active: i == safeIndex,
                  delay: Duration.zero,
                  child: pages[i],
                ),
              ),
          ],
        );
      },
    );
  }

  Widget _buildPhoneNav(BuildContext context, ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: theme.colorScheme.surface.withValues(alpha: 0.92),
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: AppDecorations.shadow(context).withValues(alpha: 0.06),
              blurRadius: 20,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child:
            Selector<
              CurrentUserProfileNotifier,
              ({bool isParent, bool isProspectiveStudent})
            >(
              selector: (_, n) => (
                isParent: n.profile?.isParent ?? false,
                isProspectiveStudent: n.profile?.isProspectiveStudent ?? false,
              ),
              builder: (context, slice, _) {
                final navItems = _navItemsFor(
                  isParent: slice.isParent,
                  isProspectiveStudent: slice.isProspectiveStudent,
                );
                return Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    for (final item in navItems)
                      _buildNavButton(
                        icon: item.icon,
                        selectedIcon: item.selectedIcon,
                        label: item.label,
                        index: item.index,
                        theme: theme,
                      ),
                  ],
                );
              },
            ),
      ),
    );
  }

  Widget _buildTabletRail(BuildContext context, ThemeData theme) {
    final extended = MediaQuery.sizeOf(context).width >= 1024;
    return Selector<
      CurrentUserProfileNotifier,
      ({bool isParent, bool isProspectiveStudent})
    >(
      selector: (_, n) => (
        isParent: n.profile?.isParent ?? false,
        isProspectiveStudent: n.profile?.isProspectiveStudent ?? false,
      ),
      builder: (context, slice, _) {
        final navItems = _navItemsFor(
          isParent: slice.isParent,
          isProspectiveStudent: slice.isProspectiveStudent,
        );
        final safeIndex = currentIndex >= navItems.length ? 0 : currentIndex;
        return DecoratedBox(
          decoration: BoxDecoration(
            color: theme.colorScheme.surface.withValues(alpha: 0.76),
            border: Border(
              right: BorderSide(
                color: theme.colorScheme.outlineVariant.withValues(alpha: 0.65),
              ),
            ),
          ),
          child: SafeArea(
            child: NavigationRail(
              selectedIndex: safeIndex,
              extended: extended,
              minExtendedWidth: 172,
              backgroundColor: Colors.transparent,
              indicatorColor: theme.colorScheme.primaryContainer,
              selectedIconTheme: IconThemeData(
                color: theme.colorScheme.onPrimaryContainer,
              ),
              selectedLabelTextStyle: theme.textTheme.labelLarge?.copyWith(
                color: theme.colorScheme.onSurface,
                fontWeight: FontWeight.w800,
              ),
              unselectedLabelTextStyle: theme.textTheme.labelLarge?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w600,
              ),
              onDestinationSelected: _selectTab,
              destinations: [
                for (final item in navItems)
                  NavigationRailDestination(
                    icon: Icon(item.icon),
                    selectedIcon: Icon(item.selectedIcon),
                    label: Text(item.label),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final size = MediaQuery.sizeOf(context);
    final useTabletShell = size.shortestSide >= 600;

    return Scaffold(
      extendBody: !useTabletShell,
      backgroundColor: Colors.transparent,
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: AppDecorations.screenBackground(context),
        child: useTabletShell
            ? Row(
                children: [
                  _buildTabletRail(context, theme),
                  Expanded(child: _buildPageStack(context)),
                ],
              )
            : BottomBar(
                width: size.width,
                barColor: Colors.transparent,
                body: (context, controller) => _buildPageStack(context),
                child: _buildPhoneNav(context, theme),
              ),
      ),
    );
  }
}

class _NavbarPageSignature {
  const _NavbarPageSignature({
    required this.profileLoading,
    required this.profileLoadError,
    required this.schoolId,
    required this.isParent,
    required this.isProspectiveStudent,
    required this.profileRevision,
  });

  final bool profileLoading;
  final String? profileLoadError;
  final String? schoolId;
  final bool isParent;
  final bool isProspectiveStudent;
  final int profileRevision;

  @override
  bool operator ==(Object other) {
    return other is _NavbarPageSignature &&
        other.profileLoading == profileLoading &&
        other.profileLoadError == profileLoadError &&
        other.schoolId == schoolId &&
        other.isParent == isParent &&
        other.isProspectiveStudent == isProspectiveStudent &&
        other.profileRevision == profileRevision;
  }

  @override
  int get hashCode => Object.hash(
    profileLoading,
    profileLoadError,
    schoolId,
    isParent,
    isProspectiveStudent,
    profileRevision,
  );
}
