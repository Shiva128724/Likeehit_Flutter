import 'package:flutter/material.dart';

import 'live_page.dart';

class JoinLivePage extends StatefulWidget {
  const JoinLivePage({super.key, this.initialChannelId = ''});

  final String initialChannelId;

  @override
  State<JoinLivePage> createState() => _JoinLivePageState();
}

class _JoinLivePageState extends State<JoinLivePage> {
  late final TextEditingController _roomController;

  @override
  void initState() {
    super.initState();
    _roomController = TextEditingController(
      text: widget.initialChannelId.trim().isEmpty
          ? 'likeehit_live'
          : widget.initialChannelId.trim(),
    );
  }

  @override
  void dispose() {
    _roomController.dispose();
    super.dispose();
  }

  void _join() {
    final channelId = _roomController.text.trim();
    if (channelId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter a live room ID')),
      );
      return;
    }
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => LivePage(channelId: channelId, isHost: false),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Join Live')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Spacer(),
              const Icon(Icons.live_tv_rounded, size: 64, color: Colors.redAccent),
              const SizedBox(height: 20),
              TextField(
                controller: _roomController,
                decoration: InputDecoration(
                  labelText: 'Live room ID',
                  filled: true,
                  fillColor: const Color(0xFF151515),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                ),
                onSubmitted: (_) => _join(),
              ),
              const SizedBox(height: 14),
              FilledButton.icon(
                onPressed: _join,
                icon: const Icon(Icons.login_rounded),
                label: const Text('Watch Live'),
              ),
              const Spacer(flex: 2),
            ],
          ),
        ),
      ),
    );
  }
}
