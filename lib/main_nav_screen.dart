import 'package:flutter/material.dart';
import 'video_feed_screen.dart';
import 'live_discovery_screen.dart';
import 'profile_screen.dart';
import 'tiktok_camera_screen.dart';
import 'inbox_screen.dart';

class MainNavScreen extends StatefulWidget {
  const MainNavScreen({super.key});

  @override
  State<MainNavScreen> createState() => _MainNavScreenState();
}

class _MainNavScreenState extends State<MainNavScreen> {
  int _selectedIndex = 0;

  final List<Widget> _pages = [
    const VideoFeedScreen(),
    const LiveDiscoveryScreen(),
    const SizedBox.shrink(), // Center button handled manually
    const InboxScreen(),
    const ProfileScreen(),
  ];

  void _onItemTapped(int index) {
    if (index == 2) {
      // Center "+" button pressed -> Go to TikTokCameraScreen
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => const TikTokCameraScreen()),
      );
    } else {
      setState(() {
        _selectedIndex = index;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: _pages[_selectedIndex],
      bottomNavigationBar: Theme(
        data: ThemeData(
          splashColor: Colors.transparent,
          highlightColor: Colors.transparent,
        ),
        child: BottomNavigationBar(
          backgroundColor: Colors.black,
          type: BottomNavigationBarType.fixed,
          showSelectedLabels: true,
          showUnselectedLabels: true,
          selectedItemColor: Colors.white,
          unselectedItemColor: Colors.grey,
          selectedFontSize: 10,
          unselectedFontSize: 10,
          currentIndex: _selectedIndex,
          onTap: _onItemTapped,
          items: [
            const BottomNavigationBarItem(
              icon: Icon(Icons.home),
              label: 'Home',
            ),
            const BottomNavigationBarItem(
              icon: Icon(Icons.live_tv),
              label: 'Live',
            ),
            BottomNavigationBarItem(
              icon: Container(
                height: 30,
                width: 45,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.add, color: Colors.black, size: 24),
              ),
              label: '',
            ),
            const BottomNavigationBarItem(
              icon: Icon(Icons.message_outlined),
              label: 'Inbox',
            ),
            const BottomNavigationBarItem(
              icon: Icon(Icons.person_outline),
              label: 'Me',
            ),
          ],
        ),
      ),
    );
  }
}
