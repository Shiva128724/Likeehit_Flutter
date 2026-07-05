import 'package:flutter/material.dart';
import 'theme_notifier.dart';

class DarkModeScreen extends StatelessWidget {
  const DarkModeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: themeNotifier,
      builder: (context, _) {
        final isDarkMode =
            themeNotifier.themeMode == ThemeMode.dark ||
            (themeNotifier.themeMode == ThemeMode.system &&
                MediaQuery.of(context).platformBrightness == Brightness.dark);

        final backgroundColor = isDarkMode
            ? const Color(0xFF000000)
            : const Color(0xFFFFFFFF);
        final textColor = isDarkMode ? Colors.white : Colors.black87;
        final subtitleColor = isDarkMode ? Colors.white54 : Colors.black54;
        final iconColor = isDarkMode ? Colors.white : Colors.black87;

        return Scaffold(
          backgroundColor: backgroundColor,
          appBar: AppBar(
            title: const Text(
              'Dark mode',
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
          body: ListView(
            children: [
              const SizedBox(height: 16),
              _buildSelectionTile(
                title: 'Light',
                icon: Icons.wb_sunny_outlined,
                isSelected: !isDarkMode,
                onTap: () {
                  themeNotifier.setDarkMode(false);
                },
                textColor: textColor,
                iconColor: iconColor,
              ),
              _buildSelectionTile(
                title: 'Dark',
                icon: Icons.nights_stay_outlined,
                isSelected: isDarkMode,
                onTap: () {
                  themeNotifier.setDarkMode(true);
                },
                textColor: textColor,
                iconColor: iconColor,
              ),
              Padding(
                padding: const EdgeInsets.only(
                  left: 16.0,
                  right: 16.0,
                  top: 24.0,
                  bottom: 8.0,
                ),
                child: Text(
                  'Changing the theme will immediately alter the appearance of the entire Likeehit interface.',
                  style: TextStyle(
                    color: subtitleColor,
                    fontSize: 13,
                    fontFamily: 'Inter',
                    height: 1.4,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSelectionTile({
    required String title,
    required IconData icon,
    required bool isSelected,
    required VoidCallback onTap,
    required Color textColor,
    required Color iconColor,
  }) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(
        horizontal: 16.0,
        vertical: 8.0,
      ),
      leading: Icon(icon, color: iconColor),
      title: Text(
        title,
        style: TextStyle(color: textColor, fontSize: 16, fontFamily: 'Inter'),
      ),
      trailing: isSelected
          ? const Icon(Icons.radio_button_checked, color: Colors.red)
          : const Icon(Icons.radio_button_unchecked, color: Colors.grey),
      onTap: onTap,
    );
  }
}
