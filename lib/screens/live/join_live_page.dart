import 'package:flutter/material.dart';

import '../../services/agora_service.dart';
import 'live_page.dart';

class JoinLivePage extends StatelessWidget {
  const JoinLivePage({super.key, this.liveID = 'room_1'});

  final String liveID;

  void _join(BuildContext context) {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => LivePage(liveID: liveID, isHost: false),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: const Text('Join Live'),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Spacer(),
              const Icon(
                Icons.live_tv_rounded,
                size: 68,
                color: Colors.redAccent,
              ),
              const SizedBox(height: 20),
              const Text(
                AgoraService.defaultChannelName,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Viewer mode',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white54),
              ),
              const SizedBox(height: 24),
              FilledButton.icon(
                onPressed: () => _join(context),
                icon: const Icon(Icons.login_rounded),
                label: const Text('Watch Live'),
                style: FilledButton.styleFrom(
                  backgroundColor: Colors.redAccent,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
              ),
              const Spacer(flex: 2),
            ],
          ),
        ),
      ),
    );
  }
}
