import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'manage_account_screen.dart';
import 'privacy_screen.dart';
import 'security_and_login_screen.dart';
import 'creator_tools_screen.dart';
import 'balance_screen.dart';
import 'qr_code_screen.dart';
import 'share_sheet.dart';
import 'push_notifications_screen.dart';
import 'app_language_screen.dart';
import 'dark_mode_screen.dart';
import 'content_preferences_screen.dart';
import 'ads_screen.dart';
import 'digital_wellbeing_screen.dart';
import 'family_pairing_screen.dart';
import 'data_saver_screen.dart';
import 'report_a_problem_screen.dart';
import 'help_center_screen.dart';
import 'safety_center_screen.dart';
import 'community_guidelines_screen.dart';
import 'terms_of_service_screen.dart';
import 'privacy_policy_screen.dart';
import 'copyright_policy_screen.dart';
import 'join_testers_screen.dart';
import 'account_switcher_sheet.dart';
import 'login_screen.dart';
import 'services/auth_service.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  String _cacheSize = '46 M';
  bool _isClearingCache = false;

  Future<void> _clearCache() async {
    if (_isClearingCache || _cacheSize == '0 M') return;

    setState(() {
      _isClearingCache = true;
    });

    await Future.delayed(const Duration(milliseconds: 1500));

    if (!mounted) return;

    setState(() {
      _cacheSize = '0 M';
      _isClearingCache = false;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Cache cleared successfully!'),
        backgroundColor: Colors.green,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _handleLogout() async {
    // Show confirmation dialog before actual logout
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: Theme.of(context).brightness == Brightness.dark
              ? const Color(0xFF1E1E1E)
              : Colors.white,
          title: const Text(
            'Log out',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
          ),
          content: const Text(
            'Are you sure you want to log out from Likeehit?',
            style: TextStyle(fontSize: 14, color: Colors.grey),
          ),
          actions: <Widget>[
            TextButton(
              child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
              onPressed: () => Navigator.of(context).pop(false),
            ),
            TextButton(
              child: const Text(
                'Log out',
                style: TextStyle(
                  color: Colors.redAccent,
                  fontWeight: FontWeight.bold,
                ),
              ),
              onPressed: () => Navigator.of(context).pop(true),
            ),
          ],
        );
      },
    );

    if (confirm == true) {
      if (!mounted) return;

      // Step 1: Show small circular loading progress overlay
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(
          child: CircularProgressIndicator.adaptive(
            valueColor: AlwaysStoppedAnimation<Color>(Colors.redAccent),
          ),
        ),
      );

      try {
        // Step 2: Call Firebase Authentication sign-out synchronously
        await AuthService.instance.signOut();

        // Step 3: Clear sensitive cached user sessions, shared preferences
        final prefs = await SharedPreferences.getInstance();
        await prefs.clear();

        // Also clear local memory states if applicable
        if (mounted) {
          setState(() {
            _cacheSize = '0 M';
          });
        }

        if (!mounted) return;

        // Step 4: Instantly redirect user to the global Welcome/Login screen
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (context) => const LoginScreen()),
          (Route<dynamic> route) => false, // Clears the entire navigation stack
        );
      } catch (e) {
        if (!mounted) return;
        Navigator.of(context).pop(); // Remove loading dialog on error
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to log out: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final Color bgColor = isDark ? Colors.black : Colors.white;
    final Color textColor = isDark ? Colors.white : Colors.black;
    final Color headerColor = isDark ? Colors.grey[400]! : Colors.grey[600]!;
    final Color iconColor = isDark ? Colors.white70 : Colors.black87;
    final Color chevronColor = isDark ? Colors.grey[600]! : Colors.grey[400]!;
    final Color dividerColor = isDark ? Colors.grey[900]! : Colors.grey[200]!;

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: bgColor,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: textColor),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Settings and privacy',
          style: TextStyle(
            color: textColor,
            fontSize: 18,
            fontWeight: FontWeight.w600,
            fontFamily: 'Inter',
          ),
        ),
      ),
      body: ListView(
        children: [
          // SECTION 1: ACCOUNT
          _buildSectionHeader('Account', headerColor),
          _buildListTile(
            icon: Icons.person_outline,
            title: 'Manage account',
            textColor: textColor,
            iconColor: iconColor,
            chevronColor: chevronColor,
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const ManageAccountScreen(),
                ),
              );
            },
          ),
          _buildListTile(
            icon: Icons.lock_outline,
            title: 'Privacy',
            textColor: textColor,
            iconColor: iconColor,
            chevronColor: chevronColor,
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const PrivacyScreen()),
              );
            },
          ),
          _buildListTile(
            icon: Icons.security,
            title: 'Security and login',
            textColor: textColor,
            iconColor: iconColor,
            chevronColor: chevronColor,
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const SecurityAndLoginScreen(),
                ),
              );
            },
          ),
          _buildListTile(
            icon: Icons.stars_outlined,
            title: 'Creator tools',
            textColor: textColor,
            iconColor: iconColor,
            chevronColor: chevronColor,
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const CreatorToolsScreen(),
                ),
              );
            },
          ),
          _buildListTile(
            icon: Icons.account_balance_wallet_outlined,
            title: 'Balance',
            textColor: textColor,
            iconColor: iconColor,
            chevronColor: chevronColor,
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const BalanceScreen()),
              );
            },
          ),
          _buildListTile(
            icon: Icons.qr_code_scanner,
            title: 'QR code',
            textColor: textColor,
            iconColor: iconColor,
            chevronColor: chevronColor,
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const QrCodeScreen()),
              );
            },
          ),
          _buildListTile(
            icon: Icons.ios_share,
            title: 'Share profile',
            textColor: textColor,
            iconColor: iconColor,
            chevronColor: chevronColor,
            onTap: () {
              showLikeehitShareSheet(context);
            },
          ),
          Divider(color: dividerColor, height: 1),

          // SECTION 2: CONTENT & ACTIVITY
          _buildSectionHeader('Content & Activity', headerColor),
          _buildListTile(
            icon: Icons.notifications_none,
            title: 'Push notifications',
            textColor: textColor,
            iconColor: iconColor,
            chevronColor: chevronColor,
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const PushNotificationsScreen(),
                ),
              );
            },
          ),
          _buildListTile(
            icon: Icons.language,
            title: 'App language',
            trailingText: 'English',
            textColor: textColor,
            iconColor: iconColor,
            chevronColor: chevronColor,
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const AppLanguageScreen(),
                ),
              );
            },
          ),
          _buildListTile(
            icon: Icons.dark_mode_outlined,
            title: 'Dark mode',
            textColor: textColor,
            iconColor: iconColor,
            chevronColor: chevronColor,
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const DarkModeScreen()),
              );
            },
          ),
          _buildListTile(
            icon: Icons.video_settings_outlined,
            title: 'Content preferences',
            textColor: textColor,
            iconColor: iconColor,
            chevronColor: chevronColor,
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const ContentPreferencesScreen(),
                ),
              );
            },
          ),
          _buildListTile(
            icon: Icons.campaign_outlined,
            title: 'Ads',
            textColor: textColor,
            iconColor: iconColor,
            chevronColor: chevronColor,
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const AdsScreen()),
              );
            },
          ),
          _buildListTile(
            icon: Icons.umbrella_outlined,
            title: 'Digital Wellbeing',
            textColor: textColor,
            iconColor: iconColor,
            chevronColor: chevronColor,
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const DigitalWellbeingScreen(),
                ),
              );
            },
          ),
          _buildListTile(
            icon: Icons.family_restroom,
            title: 'Family Pairing',
            textColor: textColor,
            iconColor: iconColor,
            chevronColor: chevronColor,
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const FamilyPairingScreen(),
                ),
              );
            },
          ),
          Divider(color: dividerColor, height: 1),

          // SECTION 3: CACHE & CELLULAR DATA
          _buildSectionHeader('Cache & Cellular Data', headerColor),
          _buildListTile(
            icon: Icons.delete_outline,
            title: 'Clear cache',
            trailingWidget: _isClearingCache
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.0,
                      color: Colors.grey,
                    ),
                  )
                : null,
            trailingText: _isClearingCache ? null : _cacheSize,
            textColor: textColor,
            iconColor: iconColor,
            chevronColor: chevronColor,
            onTap: _clearCache,
          ),
          _buildListTile(
            icon: Icons.speed,
            title: 'Data Saver',
            textColor: textColor,
            iconColor: iconColor,
            chevronColor: chevronColor,
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const DataSaverScreen(),
                ),
              );
            },
          ),
          Divider(color: dividerColor, height: 1),

          // SECTION 4: SUPPORT
          _buildSectionHeader('Support', headerColor),
          _buildListTile(
            icon: Icons.edit_outlined,
            title: 'Report a problem',
            textColor: textColor,
            iconColor: iconColor,
            chevronColor: chevronColor,
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const ReportAProblemScreen(),
                ),
              );
            },
          ),
          _buildListTile(
            icon: Icons.help_outline,
            title: 'Help Center',
            textColor: textColor,
            iconColor: iconColor,
            chevronColor: chevronColor,
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const HelpCenterScreen(),
                ),
              );
            },
          ),
          _buildListTile(
            icon: Icons.health_and_safety_outlined,
            title: 'Safety Center',
            textColor: textColor,
            iconColor: iconColor,
            chevronColor: chevronColor,
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const SafetyCenterScreen(),
                ),
              );
            },
          ),
          Divider(color: dividerColor, height: 1),

          // SECTION 5: ABOUT
          _buildSectionHeader('About', headerColor),
          _buildListTile(
            icon: Icons.gavel_outlined,
            title: 'Community Guidelines',
            textColor: textColor,
            iconColor: iconColor,
            chevronColor: chevronColor,
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const CommunityGuidelinesScreen(),
                ),
              );
            },
          ),
          _buildListTile(
            icon: Icons.article_outlined,
            title: 'Terms of Service',
            textColor: textColor,
            iconColor: iconColor,
            chevronColor: chevronColor,
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const TermsOfServiceScreen(),
                ),
              );
            },
          ),
          _buildListTile(
            icon: Icons.lock_person_outlined,
            title: 'Privacy Policy',
            textColor: textColor,
            iconColor: iconColor,
            chevronColor: chevronColor,
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const PrivacyPolicyScreen(),
                ),
              );
            },
          ),
          _buildListTile(
            icon: Icons.copyright,
            title: 'Copyright Policy',
            textColor: textColor,
            iconColor: iconColor,
            chevronColor: chevronColor,
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const CopyrightPolicyScreen(),
                ),
              );
            },
          ),
          _buildListTile(
            icon: Icons.person_add_alt_1_outlined,
            title: 'Join Likeehit Testers',
            textColor: textColor,
            iconColor: iconColor,
            chevronColor: chevronColor,
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const JoinTestersScreen(),
                ),
              );
            },
          ),
          Divider(color: dividerColor, height: 1),

          // SECTION 6: LOGIN
          _buildSectionHeader('Login', headerColor),
          _buildListTile(
            icon: Icons.swap_horiz,
            title: 'Switch account',
            textColor: textColor,
            iconColor: iconColor,
            chevronColor: chevronColor,
            onTap: () {
              showLikeehitAccountSwitcher(context);
            },
          ),
          _buildListTile(
            icon: Icons.logout,
            title: 'Logout',
            textColor: Colors.redAccent,
            iconColor: Colors.redAccent,
            chevronColor: chevronColor,
            onTap: _handleLogout,
          ),
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title, Color headerColor) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
      child: Text(
        title.toUpperCase(),
        style: TextStyle(
          color: headerColor,
          fontSize: 13,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.5,
          fontFamily: 'Inter',
        ),
      ),
    );
  }

  Widget _buildListTile({
    required IconData icon,
    required String title,
    String? trailingText,
    Widget? trailingWidget,
    required Color textColor,
    required Color iconColor,
    required Color chevronColor,
    VoidCallback? onTap,
  }) {
    return InkWell(
      onTap: onTap ?? () {},
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
        child: Row(
          children: [
            Icon(icon, color: iconColor, size: 24),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                title,
                style: TextStyle(
                  color: textColor,
                  fontSize: 16,
                  fontWeight: FontWeight.w400,
                  fontFamily: 'Inter',
                ),
              ),
            ),
            if (trailingWidget != null) ...[
              trailingWidget,
              const SizedBox(width: 8),
            ] else if (trailingText != null) ...[
              Text(
                trailingText,
                style: TextStyle(
                  color: chevronColor,
                  fontSize: 14,
                  fontFamily: 'Inter',
                ),
              ),
              const SizedBox(width: 8),
            ],
            Icon(Icons.chevron_right, color: chevronColor, size: 20),
          ],
        ),
      ),
    );
  }
}
