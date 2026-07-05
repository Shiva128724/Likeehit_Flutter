import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

import 'screens/live/join_live_page.dart';
import 'screens/live/live_page.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: '.env');
  runApp(const AgoraLiveApp());
}

class AgoraLiveApp extends StatelessWidget {
  const AgoraLiveApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Agora Live',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: Colors.black,
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.redAccent,
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
      ),
      home: const LiveHomePage(),
    );
  }
}

class LiveHomePage extends StatefulWidget {
  const LiveHomePage({super.key});

  @override
  State<LiveHomePage> createState() => _LiveHomePageState();
}

class _LiveHomePageState extends State<LiveHomePage> {
  final TextEditingController _channelController = TextEditingController(
    text: 'likeehit_live',
  );

  @override
  void dispose() {
    _channelController.dispose();
    super.dispose();
  }

  void _openHost() {
    final channelId = _cleanChannelId();
    if (channelId == null) return;
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => LivePage(channelId: channelId, isHost: true),
      ),
    );
  }

  void _openJoin() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => JoinLivePage(initialChannelId: _channelController.text),
      ),
    );
  }

  String? _cleanChannelId() {
    final value = _channelController.text.trim();
    if (value.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter a live room ID')),
      );
      return null;
    }
    return value;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 28),
              const Text(
                'LikeeHit Live',
                style: TextStyle(fontSize: 32, fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 8),
              const Text(
                'Stable Agora live streaming',
                style: TextStyle(color: Colors.white60),
              ),
              const Spacer(),
              TextField(
                controller: _channelController,
                decoration: InputDecoration(
                  labelText: 'Live room ID',
                  filled: true,
                  fillColor: const Color(0xFF151515),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
              const SizedBox(height: 14),
              FilledButton.icon(
                onPressed: _openHost,
                icon: const Icon(Icons.videocam_rounded),
                label: const Text('Start Live'),
              ),
              const SizedBox(height: 10),
              OutlinedButton.icon(
                onPressed: _openJoin,
                icon: const Icon(Icons.live_tv_rounded),
                label: const Text('Join Live'),
              ),
              const Spacer(),
            ],
          ),
        ),
      ),
    );
  }
}
