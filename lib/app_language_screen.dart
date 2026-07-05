import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AppLanguageScreen extends StatefulWidget {
  const AppLanguageScreen({super.key});

  @override
  State<AppLanguageScreen> createState() => _AppLanguageScreenState();
}

class _AppLanguageScreenState extends State<AppLanguageScreen> {
  String _initialLanguage = 'en';
  String _selectedLanguage = 'en';
  bool _isLoading = true;
  String _searchQuery = '';

  final List<Map<String, String>> _allLanguages = [
    {'code': 'en', 'name': 'English', 'nativeName': 'English'},
    {'code': 'hi', 'name': 'Hindi', 'nativeName': 'हिन्दी'},
    {'code': 'es', 'name': 'Spanish', 'nativeName': 'Español'},
    {'code': 'fr', 'name': 'French', 'nativeName': 'Français'},
    {'code': 'ar', 'name': 'Arabic', 'nativeName': 'العربية'},
    {'code': 'pt', 'name': 'Portuguese', 'nativeName': 'Português'},
    {'code': 'de', 'name': 'German', 'nativeName': 'Deutsch'},
    {'code': 'ru', 'name': 'Russian', 'nativeName': 'Русский'},
    {'code': 'id', 'name': 'Indonesian', 'nativeName': 'Bahasa Indonesia'},
    {'code': 'zh', 'name': 'Chinese (Simplified)', 'nativeName': '中文（简体）'},
    {'code': 'ja', 'name': 'Japanese', 'nativeName': '日本語'},
    {'code': 'ko', 'name': 'Korean', 'nativeName': '한국어'},
  ];

  @override
  void initState() {
    super.initState();
    _loadSelectedLanguage();
  }

  Future<void> _loadSelectedLanguage() async {
    final prefs = await SharedPreferences.getInstance();
    final lang = prefs.getString('app_language') ?? 'en';
    setState(() {
      _initialLanguage = lang;
      _selectedLanguage = lang;
      _isLoading = false;
    });
  }

  Future<void> _saveLanguage() async {
    if (_selectedLanguage == _initialLanguage) {
      Navigator.pop(context);
      return;
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('app_language', _selectedLanguage);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Language changed to ${_allLanguages.firstWhere((l) => l['code'] == _selectedLanguage)['name']}',
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final backgroundColor = isDarkMode ? Colors.black : const Color(0xFFFFFFFF);
    final textColor = isDarkMode ? Colors.white : Colors.black87;
    final searchBgColor = isDarkMode ? Colors.grey[900] : Colors.grey[100];
    final dividerColor = isDarkMode ? Colors.grey[850]! : Colors.grey[200]!;

    final hasChanged = _selectedLanguage != _initialLanguage;

    final filteredLanguages = _allLanguages.where((lang) {
      final query = _searchQuery.toLowerCase();
      return lang['name']!.toLowerCase().contains(query) ||
          lang['nativeName']!.toLowerCase().contains(query);
    }).toList();

    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        title: const Text(
          'App language',
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
        actions: [
          TextButton(
            onPressed: hasChanged ? _saveLanguage : null,
            child: Text(
              'Done',
              style: TextStyle(
                color: hasChanged ? Colors.red : Colors.grey,
                fontWeight: hasChanged ? FontWeight.bold : FontWeight.normal,
                fontFamily: 'Inter',
                fontSize: 15,
              ),
            ),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator.adaptive())
          : Column(
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16.0,
                    vertical: 8.0,
                  ),
                  child: Container(
                    decoration: BoxDecoration(
                      color: searchBgColor,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: TextField(
                      style: TextStyle(color: textColor, fontFamily: 'Inter'),
                      onChanged: (val) {
                        setState(() {
                          _searchQuery = val;
                        });
                      },
                      decoration: InputDecoration(
                        hintText: 'Search languages',
                        hintStyle: TextStyle(color: Colors.grey[500]),
                        prefixIcon: Icon(Icons.search, color: Colors.grey[500]),
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 14,
                        ),
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: ListView.separated(
                    itemCount: filteredLanguages.length,
                    separatorBuilder: (context, index) => Padding(
                      padding: const EdgeInsets.only(left: 16.0),
                      child: Divider(color: dividerColor, height: 1),
                    ),
                    itemBuilder: (context, index) {
                      final lang = filteredLanguages[index];
                      final isSelected = _selectedLanguage == lang['code'];

                      return ListTile(
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16.0,
                          vertical: 4.0,
                        ),
                        title: Text(
                          lang['nativeName']!,
                          style: TextStyle(
                            color: textColor,
                            fontSize: 15,
                            fontFamily: 'Inter',
                          ),
                        ),
                        subtitle: lang['nativeName'] != lang['name']
                            ? Text(
                                lang['name']!,
                                style: const TextStyle(
                                  color: Colors.grey,
                                  fontSize: 12,
                                  fontFamily: 'Inter',
                                ),
                              )
                            : null,
                        trailing: isSelected
                            ? const Icon(Icons.check, color: Colors.red)
                            : null,
                        onTap: () {
                          setState(() {
                            _selectedLanguage = lang['code']!;
                          });
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
