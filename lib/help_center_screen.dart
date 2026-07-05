import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class ArticleDetailScreen extends StatelessWidget {
  final Map<String, dynamic> article;

  const ArticleDetailScreen({super.key, required this.article});

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final backgroundColor = isDarkMode
        ? const Color(0xFF000000)
        : const Color(0xFFFFFFFF);
    final headingColor = isDarkMode ? Colors.white : Colors.black;
    final bodyColor = isDarkMode ? Colors.grey[300] : const Color(0xFF333333);

    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        title: const Text(
          'Article',
          style: TextStyle(
            fontFamily: 'Inter',
            fontWeight: FontWeight.w600,
            fontSize: 17,
          ),
        ),
        backgroundColor: backgroundColor,
        foregroundColor: headingColor,
        elevation: 0,
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              article['title'] ?? 'Untitled',
              style: TextStyle(
                color: headingColor,
                fontSize: 18,
                fontWeight: FontWeight.bold,
                fontFamily: 'Inter',
              ),
            ),
            const SizedBox(height: 16),
            Text(
              article['content'] ?? '',
              style: TextStyle(
                color: bodyColor,
                fontSize: 14,
                height: 1.5,
                fontFamily: 'Inter',
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class HelpCenterScreen extends StatefulWidget {
  const HelpCenterScreen({super.key});

  @override
  State<HelpCenterScreen> createState() => _HelpCenterScreenState();
}

class _HelpCenterScreenState extends State<HelpCenterScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  // Default hardcoded articles as per instructions
  final List<Map<String, dynamic>> _defaultArticles = [
    {
      'title': 'How to create a Likeehit account?',
      'icon': Icons.account_circle_outlined,
      'content':
          'To create an account, download the app, tap on Profile, and select Sign Up.',
    },
    {
      'title': 'Resetting your forgotten password',
      'icon': Icons.lock_open_outlined,
      'content':
          'Tap on Forgot Password on the login screen and follow the email instructions.',
    },
    {
      'title': 'Why can\'t I upload a video feed?',
      'icon': Icons.error_outline,
      'content':
          'Ensure your app is updated to the latest version and you have a stable internet connection.',
    },
    {
      'title': 'Keeping your Likeehit wallet secure',
      'icon': Icons.account_balance_wallet_outlined,
      'content':
          'Never share your OTP or password with anyone. Enable 2-step verification in Security settings.',
    },
  ];

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() {
      setState(() {
        _searchQuery = _searchController.text.toLowerCase();
      });
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  IconData _getIconData(String iconName) {
    switch (iconName) {
      case 'account_circle_outlined':
        return Icons.account_circle_outlined;
      case 'lock_open_outlined':
        return Icons.lock_open_outlined;
      case 'error_outline':
        return Icons.error_outline;
      case 'account_balance_wallet_outlined':
        return Icons.account_balance_wallet_outlined;
      default:
        return Icons.article_outlined;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final backgroundColor = isDarkMode
        ? const Color(0xFF000000)
        : const Color(0xFFFFFFFF);
    final textColor = isDarkMode ? Colors.white : Colors.black87;
    final hintColor = isDarkMode ? Colors.white54 : Colors.black54;
    final searchBgColor = isDarkMode
        ? Colors.grey[900]!
        : const Color(0xFFF5F5F5);
    final headerColor = isDarkMode ? Colors.grey[400]! : Colors.grey[600]!;

    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        title: const Text(
          'Help Center',
          style: TextStyle(
            fontFamily: 'Inter',
            fontWeight: FontWeight.w600,
            fontSize: 17,
          ),
        ),
        backgroundColor: backgroundColor,
        foregroundColor: textColor,
        elevation: 0,
        centerTitle: true,
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: 16.0,
              vertical: 8.0,
            ),
            child: TextField(
              controller: _searchController,
              style: TextStyle(color: textColor, fontFamily: 'Inter'),
              decoration: InputDecoration(
                hintText: 'Search for topics or articles...',
                hintStyle: TextStyle(color: hintColor, fontFamily: 'Inter'),
                prefixIcon: Icon(Icons.search, color: hintColor),
                filled: true,
                fillColor: searchBgColor,
                contentPadding: const EdgeInsets.symmetric(vertical: 0),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8.0),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Text(
              'POPULAR ARTICLES',
              style: TextStyle(
                color: headerColor,
                fontSize: 13,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.5,
                fontFamily: 'Inter',
              ),
            ),
          ),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('help_articles')
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return const Center(child: Text('Something went wrong'));
                }

                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(
                    child: CircularProgressIndicator.adaptive(),
                  );
                }

                List<Map<String, dynamic>> combinedArticles = [];

                if (snapshot.hasData && snapshot.data!.docs.isNotEmpty) {
                  for (var doc in snapshot.data!.docs) {
                    final data = doc.data() as Map<String, dynamic>;
                    combinedArticles.add({
                      'title': data['title'] ?? 'Untitled',
                      'content': data['content'] ?? '',
                      'icon': _getIconData(data['icon'] ?? ''),
                    });
                  }
                } else {
                  combinedArticles = List.from(_defaultArticles);
                }

                // Apply local filter
                final filteredArticles = combinedArticles.where((article) {
                  final title = article['title'].toString().toLowerCase();
                  return title.contains(_searchQuery);
                }).toList();

                if (filteredArticles.isEmpty) {
                  return Center(
                    child: Text(
                      'No articles found.',
                      style: TextStyle(color: hintColor, fontFamily: 'Inter'),
                    ),
                  );
                }

                return ListView.builder(
                  itemCount: filteredArticles.length,
                  itemBuilder: (context, index) {
                    final article = filteredArticles[index];
                    return ListTile(
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16.0,
                        vertical: 4.0,
                      ),
                      leading: Icon(
                        article['icon'],
                        color: textColor,
                        size: 24,
                      ),
                      title: Text(
                        article['title'],
                        style: TextStyle(
                          color: textColor,
                          fontSize: 15,
                          fontFamily: 'Inter',
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                      trailing: Icon(
                        Icons.chevron_right,
                        color: isDarkMode ? Colors.grey[600] : Colors.grey[400],
                        size: 20,
                      ),
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) =>
                                ArticleDetailScreen(article: article),
                          ),
                        );
                      },
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
