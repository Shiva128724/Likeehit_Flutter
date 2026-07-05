import 'package:flutter/material.dart';
import '../models/text_overlay_item.dart';

class TextEditorOverlay extends StatefulWidget {
  final TextOverlayItem? initialItem;

  const TextEditorOverlay({super.key, this.initialItem});

  @override
  State<TextEditorOverlay> createState() => _TextEditorOverlayState();
}

class _TextEditorOverlayState extends State<TextEditorOverlay> {
  late TextEditingController _textController;
  late double _fontSize;
  late Color _selectedColor;
  late String _selectedFontFamily;
  late int _bgType; // 0 = Transparent, 1 = Filled, 2 = Inverted
  late TextAlign _alignment;
  late String _selectedEffect;

  final List<Color> _colors = [
    Colors.white,
    Colors.black,
    Colors.redAccent,
    Colors.blueAccent,
    Colors.greenAccent,
    Colors.yellowAccent,
    Colors.purpleAccent,
    Colors.orangeAccent,
  ];

  final List<String> _fonts = ['Modern', 'Classic', 'Neon', 'Serif'];
  final List<String> _effects = ['None', 'Hard Shadow', 'Block Offset'];

  @override
  void initState() {
    super.initState();
    _textController = TextEditingController(
      text: widget.initialItem?.text ?? '',
    );
    _fontSize = widget.initialItem?.fontSize ?? 28.0;
    _selectedColor = widget.initialItem?.color ?? Colors.white;
    _selectedFontFamily = widget.initialItem?.fontFamily ?? 'Modern';
    _bgType = widget.initialItem?.bgType ?? 0;
    _alignment = widget.initialItem?.alignment ?? TextAlign.center;
    _selectedEffect = widget.initialItem?.effect ?? 'None';
  }

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  void _onDone() {
    if (_textController.text.trim().isEmpty) {
      Navigator.pop(context, null);
      return;
    }

    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;

    // Use initial item's coordinates if it exists, otherwise spawn in center
    final dx =
        widget.initialItem?.dx ?? (screenWidth / 2) - 50; // Approximated center
    final dy =
        widget.initialItem?.dy ??
        (screenHeight / 2) - 50; // Approximated center

    final result = TextOverlayItem(
      text: _textController.text,
      dx: dx,
      dy: dy,
      fontSize: _fontSize,
      color: _selectedColor,
      fontFamily: _selectedFontFamily,
      bgType: _bgType,
      alignment: _alignment,
      effect: _selectedEffect,
    );

    Navigator.pop(context, result);
  }

  void _toggleAlignment() {
    setState(() {
      if (_alignment == TextAlign.center) {
        _alignment = TextAlign.left;
      } else if (_alignment == TextAlign.left) {
        _alignment = TextAlign.right;
      } else {
        _alignment = TextAlign.center;
      }
    });
  }

  void _toggleBackground() {
    setState(() {
      _bgType = (_bgType + 1) % 3;
    });
  }

  TextStyle _buildTextStyle() {
    FontWeight weight = FontWeight.bold;
    String family = 'sans-serif';
    double letterSpacing = 0.0;

    if (_selectedFontFamily == 'Classic') {
      family = 'serif';
      weight = FontWeight.normal;
    } else if (_selectedFontFamily == 'Neon') {
      family = 'sans-serif';
      weight = FontWeight.w900;
      letterSpacing = 1.5;
    } else if (_selectedFontFamily == 'Serif') {
      family = 'serif';
      weight = FontWeight.w600;
    }

    Color textColor = _selectedColor;
    Color bgColor = Colors.transparent;

    if (_bgType == 1) {
      // Filled
      bgColor = _selectedColor == Colors.black ? Colors.white : Colors.black;
    } else if (_bgType == 2) {
      // Inverted
      bgColor = _selectedColor;
      textColor = _selectedColor == Colors.white ? Colors.black : Colors.white;
      if (_selectedColor == Colors.black) {
        bgColor = Colors.white;
        textColor = Colors.black;
      }
    }

    List<Shadow>? shadows;
    if (_selectedEffect == 'Hard Shadow') {
      shadows = [
        Shadow(
          color: Colors.black.withValues(alpha: 0.8),
          offset: const Offset(2, 2),
          blurRadius: 0,
        ),
      ];
    } else if (_selectedEffect == 'Block Offset') {
      shadows = [
        Shadow(
          color: _selectedColor == Colors.black ? Colors.white : Colors.black,
          offset: const Offset(3, 3),
          blurRadius: 0,
        ),
      ];
    } else {
      // Subtle default shadow for legibility if transparent
      if (_bgType == 0) {
        shadows = [
          Shadow(color: Colors.black.withValues(alpha: 0.5), blurRadius: 4),
        ];
      }
    }

    return TextStyle(
      fontSize: _fontSize,
      color: textColor,
      backgroundColor: bgColor,
      fontFamily: family,
      fontWeight: weight,
      letterSpacing: letterSpacing,
      shadows: shadows,
      height: 1.2,
    );
  }

  Widget _buildTopToolbar() {
    IconData alignIcon = Icons.format_align_center;
    if (_alignment == TextAlign.left) alignIcon = Icons.format_align_left;
    if (_alignment == TextAlign.right) alignIcon = Icons.format_align_right;

    return Padding(
      padding: const EdgeInsets.only(top: 48.0, left: 16.0, right: 16.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              IconButton(
                icon: Icon(alignIcon, color: Colors.white, size: 28),
                onPressed: _toggleAlignment,
              ),
              const SizedBox(width: 8),
              IconButton(
                icon: const Icon(
                  Icons.font_download,
                  color: Colors.white,
                  size: 28,
                ),
                onPressed: _toggleBackground,
              ),
            ],
          ),
          ElevatedButton(
            onPressed: _onDone,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: Colors.black,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            ),
            child: const Text(
              'Done',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSizeSlider() {
    return Positioned(
      left: 16,
      top: 150,
      bottom: 250,
      child: RotatedBox(
        quarterTurns: -1,
        child: SliderTheme(
          data: SliderTheme.of(context).copyWith(
            activeTrackColor: Colors.white,
            inactiveTrackColor: Colors.white30,
            thumbColor: Colors.white,
            trackHeight: 2.0,
            thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 8.0),
          ),
          child: Slider(
            value: _fontSize,
            min: 14.0,
            max: 100.0,
            onChanged: (val) {
              setState(() {
                _fontSize = val;
              });
            },
          ),
        ),
      ),
    );
  }

  Widget _buildBottomToolbar() {
    return Container(
      color: Colors.black54,
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Effects Chips
          SizedBox(
            height: 36,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: _effects.length,
              itemBuilder: (context, index) {
                final effect = _effects[index];
                final isSelected = effect == _selectedEffect;
                return GestureDetector(
                  onTap: () => setState(() => _selectedEffect = effect),
                  child: Container(
                    margin: const EdgeInsets.only(right: 8),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: isSelected ? Colors.white : Colors.white24,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      effect,
                      style: TextStyle(
                        color: isSelected ? Colors.black : Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 16),
          // Font Row
          SizedBox(
            height: 36,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: _fonts.length,
              itemBuilder: (context, index) {
                final font = _fonts[index];
                final isSelected = font == _selectedFontFamily;
                return GestureDetector(
                  onTap: () => setState(() => _selectedFontFamily = font),
                  child: Container(
                    margin: const EdgeInsets.only(right: 12),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: isSelected ? Colors.white : Colors.transparent,
                      ),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      font,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 16),
          // Color Palette Row
          SizedBox(
            height: 32,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: _colors.length,
              itemBuilder: (context, index) {
                final color = _colors[index];
                final isSelected = color == _selectedColor;
                return GestureDetector(
                  onTap: () => setState(() => _selectedColor = color),
                  child: Container(
                    width: 32,
                    height: 32,
                    margin: const EdgeInsets.only(right: 12),
                    decoration: BoxDecoration(
                      color: color,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: isSelected ? Colors.white : Colors.transparent,
                        width: 3,
                      ),
                      boxShadow: [
                        if (isSelected)
                          const BoxShadow(color: Colors.black54, blurRadius: 4),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black.withValues(alpha: 0.6),
      resizeToAvoidBottomInset: true,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Dismiss area
          GestureDetector(
            onTap: _onDone,
            child: Container(color: Colors.transparent),
          ),

          _buildSizeSlider(),

          // Text Input Center
          Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 50.0),
              child: IntrinsicWidth(
                child: TextField(
                  controller: _textController,
                  autofocus: true,
                  style: _buildTextStyle(),
                  textAlign: _alignment,
                  cursorColor: Colors.white,
                  maxLines: null,
                  decoration: const InputDecoration(
                    border: InputBorder.none,
                    hintText: 'Type something...',
                    hintStyle: TextStyle(color: Colors.white54, fontSize: 28),
                  ),
                ),
              ),
            ),
          ),

          // Top and Bottom Toolbars
          Column(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [_buildTopToolbar(), _buildBottomToolbar()],
          ),
        ],
      ),
    );
  }
}
