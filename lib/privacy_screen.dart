import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class PrivacyScreen extends StatefulWidget {
  const PrivacyScreen({super.key});

  @override
  State<PrivacyScreen> createState() => _PrivacyScreenState();
}

class _PrivacyScreenState extends State<PrivacyScreen> {
  Future<void> _updatePrivacySetting(String key, dynamic value) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid != null) {
      // Updates nested field in map or merges if it exists.
      // Doing it this way safely merges nested keys without overwriting the whole object
      await FirebaseFirestore.instance.collection('users').doc(uid).set({
        'privacy_settings': {key: value},
      }, SetOptions(merge: true));
    }
  }

  void _showMockOptionSheet(
    String title,
    String key,
    List<String> options,
    String currentValue,
  ) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1E1E1E),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                title,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              ...options.map((option) {
                return ListTile(
                  title: Text(
                    option,
                    style: TextStyle(
                      color: option == currentValue
                          ? Colors.redAccent
                          : Colors.white,
                    ),
                  ),
                  trailing: option == currentValue
                      ? const Icon(Icons.check, color: Colors.redAccent)
                      : null,
                  onTap: () {
                    _updatePrivacySetting(key, option);
                    Navigator.pop(context);
                  },
                );
              }),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid ?? 'me';
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
          'Privacy',
          style: TextStyle(
            color: textColor,
            fontSize: 18,
            fontWeight: FontWeight.w600,
            fontFamily: 'Inter',
          ),
        ),
      ),
      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance
            .collection('users')
            .doc(uid)
            .snapshots(),
        builder: (context, snapshot) {
          Map<String, dynamic> privacySettings = {};

          if (snapshot.hasData && snapshot.data!.exists) {
            final data = snapshot.data!.data() as Map<String, dynamic>;
            privacySettings =
                data['privacy_settings'] as Map<String, dynamic>? ?? {};
          }

          // Defaults
          final bool isPrivate = privacySettings['is_private'] ?? false;
          final bool adAuthorization =
              privacySettings['ad_authorization'] ?? false;

          final String downloads = privacySettings['downloads'] ?? 'On';
          final String comments = privacySettings['comments'] ?? 'Everyone';
          final String mentionsAndTags =
              privacySettings['mentions_and_tags'] ?? 'Everyone';
          final String directMessages =
              privacySettings['direct_messages'] ?? 'Friends';
          final String duet = privacySettings['duet'] ?? 'Everyone';
          final String stitch = privacySettings['stitch'] ?? 'Everyone';
          final String likedVideos =
              privacySettings['liked_videos'] ?? 'Only me';
          final String profileViews = privacySettings['profile_views'] ?? 'Off';

          return ListView(
            children: [
              // SECTION 1: DISCOVERABILITY
              _buildSectionHeader('Discoverability', headerColor),
              _buildSwitchTile(
                icon: Icons.lock_outline,
                title: 'Private account',
                value: isPrivate,
                textColor: textColor,
                iconColor: iconColor,
                onChanged: (val) => _updatePrivacySetting('is_private', val),
              ),
              _buildListTile(
                icon: Icons.person_add_alt,
                title: 'Suggest your account to others',
                textColor: textColor,
                iconColor: iconColor,
                chevronColor: chevronColor,
                onTap: () {}, // Sub-screen mock
              ),
              Divider(color: dividerColor, height: 1),

              // SECTION 2: PERSONALIZATION & DATA
              _buildSectionHeader('Personalization & Data', headerColor),
              _buildSwitchTile(
                icon: Icons.bar_chart_outlined,
                title: 'Ad authorization',
                value: adAuthorization,
                textColor: textColor,
                iconColor: iconColor,
                onChanged: (val) =>
                    _updatePrivacySetting('ad_authorization', val),
              ),
              _buildListTile(
                icon: Icons.file_download_outlined,
                title: 'Download your data',
                textColor: textColor,
                iconColor: iconColor,
                chevronColor: chevronColor,
                onTap: () {}, // Sub-screen mock
              ),
              Divider(color: dividerColor, height: 1),

              // SECTION 3: SAFETY
              _buildSectionHeader('Safety', headerColor),
              _buildListTile(
                icon: Icons.download_outlined,
                title: 'Downloads',
                trailingText: downloads,
                textColor: textColor,
                iconColor: iconColor,
                chevronColor: chevronColor,
                onTap: () => _showMockOptionSheet(
                  'Video downloads',
                  'downloads',
                  ['On', 'Off'],
                  downloads,
                ),
              ),
              _buildListTile(
                icon: Icons.chat_bubble_outline,
                title: 'Comments',
                trailingText: comments,
                textColor: textColor,
                iconColor: iconColor,
                chevronColor: chevronColor,
                onTap: () => _showMockOptionSheet(
                  'Who can comment on your videos',
                  'comments',
                  ['Everyone', 'Friends', 'No one'],
                  comments,
                ),
              ),
              _buildListTile(
                icon: Icons.alternate_email,
                title: 'Mentions and tags',
                trailingText: mentionsAndTags,
                textColor: textColor,
                iconColor: iconColor,
                chevronColor: chevronColor,
                onTap: () => _showMockOptionSheet(
                  'Who can mention you',
                  'mentions_and_tags',
                  ['Everyone', 'Friends', 'No one'],
                  mentionsAndTags,
                ),
              ),
              _buildListTile(
                icon: Icons.send_outlined,
                title: 'Direct messages',
                trailingText: directMessages,
                textColor: textColor,
                iconColor: iconColor,
                chevronColor: chevronColor,
                onTap: () => _showMockOptionSheet(
                  'Who can send you direct messages',
                  'direct_messages',
                  ['Everyone', 'Friends', 'No one'],
                  directMessages,
                ),
              ),
              _buildListTile(
                icon: Icons.vertical_split_outlined,
                title: 'Duet',
                trailingText: duet,
                textColor: textColor,
                iconColor: iconColor,
                chevronColor: chevronColor,
                onTap: () => _showMockOptionSheet(
                  'Who can Duet with your videos',
                  'duet',
                  ['Everyone', 'Friends', 'Only me'],
                  duet,
                ),
              ),
              _buildListTile(
                icon: Icons.cut_outlined,
                title: 'Stitch',
                trailingText: stitch,
                textColor: textColor,
                iconColor: iconColor,
                chevronColor: chevronColor,
                onTap: () => _showMockOptionSheet(
                  'Who can Stitch with your videos',
                  'stitch',
                  ['Everyone', 'Friends', 'Only me'],
                  stitch,
                ),
              ),
              _buildListTile(
                icon: Icons.favorite_border,
                title: 'Liked videos',
                trailingText: likedVideos,
                textColor: textColor,
                iconColor: iconColor,
                chevronColor: chevronColor,
                onTap: () => _showMockOptionSheet(
                  'Who can watch your liked videos',
                  'liked_videos',
                  ['Everyone', 'Only me'],
                  likedVideos,
                ),
              ),
              _buildListTile(
                icon: Icons.visibility_outlined,
                title: 'Profile views',
                trailingText: profileViews,
                textColor: textColor,
                iconColor: iconColor,
                chevronColor: chevronColor,
                onTap: () => _showMockOptionSheet(
                  'Profile view history',
                  'profile_views',
                  ['On', 'Off'],
                  profileViews,
                ),
              ),
              _buildListTile(
                icon: Icons.block_outlined,
                title: 'Blocked accounts',
                textColor: textColor,
                iconColor: iconColor,
                chevronColor: chevronColor,
                onTap: () {}, // Sub-screen mock
              ),
            ],
          );
        },
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
    required Color textColor,
    required Color iconColor,
    required Color chevronColor,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
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
            if (trailingText != null) ...[
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

  Widget _buildSwitchTile({
    required IconData icon,
    required String title,
    required bool value,
    required Color textColor,
    required Color iconColor,
    required ValueChanged<bool> onChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
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
          Switch.adaptive(
            value: value,
            activeTrackColor: Colors.redAccent,
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }
}
