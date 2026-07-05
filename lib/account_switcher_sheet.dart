import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

void showLikeehitAccountSwitcher(BuildContext context) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (context) {
      return const _AccountSwitcherSheet();
    },
  );
}

class _AccountSwitcherSheet extends StatefulWidget {
  const _AccountSwitcherSheet();

  @override
  State<_AccountSwitcherSheet> createState() => _AccountSwitcherSheetState();
}

class _AccountSwitcherSheetState extends State<_AccountSwitcherSheet> {
  final User? _currentUser = FirebaseAuth.instance.currentUser;

  // Default mock sessions if Firestore is empty
  final List<Map<String, dynamic>> _mockSessions = [
    {
      'uid': 'mock_uid_1',
      'display_name': 'Shiva Dev',
      'handle': '@shiva_dev',
      'photo_url': 'https://i.pravatar.cc/150?u=shiva_dev',
      'is_active': true,
    },
    {
      'uid': 'mock_uid_2',
      'display_name': 'Tech Insights',
      'handle': '@tech_insights',
      'photo_url': 'https://i.pravatar.cc/150?u=tech_insights',
      'is_active': false,
    },
  ];

  Future<void> _switchAccount(
    BuildContext context,
    Map<String, dynamic> account,
  ) async {
    // Show a quick loading dialog or indicator before switching
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(
        child: CircularProgressIndicator.adaptive(
          valueColor: AlwaysStoppedAnimation<Color>(Colors.redAccent),
        ),
      ),
    );

    // Simulate backend auth switch delay
    await Future.delayed(const Duration(milliseconds: 800));

    // Pop the loading dialog
    if (context.mounted) Navigator.pop(context);

    // Pop the bottom sheet
    if (context.mounted) Navigator.pop(context);

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Switched to ${account['handle']}')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final backgroundColor = isDarkMode
        ? const Color(0xFF1E1E1E)
        : const Color(0xFFFFFFFF);
    final textColor = isDarkMode ? Colors.white : Colors.black;
    final subtitleColor = isDarkMode ? Colors.white54 : Colors.black54;
    final handleColor = isDarkMode ? Colors.grey[800] : Colors.grey[200];

    return Container(
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(16.0)),
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header Section
            const SizedBox(height: 12),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[400],
                borderRadius: BorderRadius.circular(2.0),
              ),
            ),
            Stack(
              alignment: Alignment.center,
              children: [
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 16.0),
                  child: Text(
                    'Switch account',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: textColor,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      fontFamily: 'Inter',
                    ),
                  ),
                ),
                Positioned(
                  right: 8,
                  child: IconButton(
                    icon: Icon(Icons.close, color: textColor),
                    onPressed: () => Navigator.pop(context),
                  ),
                ),
              ],
            ),

            // Accounts List
            Flexible(
              child: StreamBuilder<QuerySnapshot>(
                // Fetches currently active logged-in sessions
                stream: FirebaseFirestore.instance
                    .collection('user_sessions')
                    .snapshots(),
                builder: (context, snapshot) {
                  List<Map<String, dynamic>> sessions = [];

                  if (snapshot.hasData && snapshot.data!.docs.isNotEmpty) {
                    for (var doc in snapshot.data!.docs) {
                      final data = doc.data() as Map<String, dynamic>;
                      sessions.add({
                        'uid': data['uid'] ?? '',
                        'display_name': data['display_name'] ?? 'User',
                        'handle': data['handle'] ?? '@user',
                        'photo_url': data['photo_url'] ?? '',
                        'is_active':
                            (data['uid'] == _currentUser?.uid) ||
                            (data['is_active'] == true),
                      });
                    }
                  } else {
                    // Fallback to mock data to ensure UI displays perfectly if db is empty
                    sessions = List.from(_mockSessions);
                    if (_currentUser != null &&
                        _currentUser.displayName != null) {
                      sessions[0]['display_name'] = _currentUser.displayName;
                      sessions[0]['uid'] = _currentUser.uid;
                    }
                  }

                  return ListView.builder(
                    shrinkWrap: true,
                    physics: const BouncingScrollPhysics(),
                    itemCount: sessions.length,
                    itemBuilder: (context, index) {
                      final session = sessions[index];
                      final isActive = session['is_active'] == true;

                      return ListTile(
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 24.0,
                          vertical: 8.0,
                        ),
                        leading: CircleAvatar(
                          radius: 24,
                          backgroundColor: Colors.grey[300],
                          backgroundImage: session['photo_url'].isNotEmpty
                              ? NetworkImage(session['photo_url'])
                              : null,
                          child: session['photo_url'].isEmpty
                              ? Icon(Icons.person, color: Colors.grey[600])
                              : null,
                        ),
                        title: Text(
                          session['display_name'],
                          style: TextStyle(
                            color: textColor,
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            fontFamily: 'Inter',
                          ),
                        ),
                        subtitle: Text(
                          session['handle'],
                          style: TextStyle(
                            color: subtitleColor,
                            fontSize: 13,
                            fontFamily: 'Inter',
                          ),
                        ),
                        trailing: isActive
                            ? const Icon(
                                Icons.check_circle,
                                color: Colors.green,
                                size: 24,
                              )
                            : null,
                        onTap: () => _switchAccount(context, session),
                      );
                    },
                  );
                },
              ),
            ),

            // Add Account Button
            InkWell(
              onTap: () {
                Navigator.pop(context); // Close sheet
                // Navigate to a placeholder Login Screen
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const _PlaceholderLoginScreen(),
                  ),
                );
              },
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24.0,
                  vertical: 16.0,
                ),
                child: Row(
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: handleColor,
                      ),
                      child: Icon(Icons.add, color: textColor),
                    ),
                    const SizedBox(width: 16),
                    Text(
                      'Add account',
                      style: TextStyle(
                        color: textColor,
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        fontFamily: 'Inter',
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16), // Bottom padding
          ],
        ),
      ),
    );
  }
}

class _PlaceholderLoginScreen extends StatelessWidget {
  const _PlaceholderLoginScreen();

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final backgroundColor = isDarkMode
        ? const Color(0xFF000000)
        : const Color(0xFFFFFFFF);
    final textColor = isDarkMode ? Colors.white : Colors.black;

    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        title: const Text(
          'Log In / Sign Up',
          style: TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.w600),
        ),
        backgroundColor: backgroundColor,
        foregroundColor: textColor,
        elevation: 0,
      ),
      body: Center(
        child: Text(
          'Authentication flow placeholder',
          style: TextStyle(color: textColor, fontFamily: 'Inter', fontSize: 16),
        ),
      ),
    );
  }
}
