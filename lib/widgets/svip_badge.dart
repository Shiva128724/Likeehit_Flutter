import 'package:flutter/material.dart';

class SvipBadge extends StatelessWidget {
  const SvipBadge({
    super.key,
    required this.tier,
    this.compact = false,
    this.onTap,
  });

  final int tier;
  final bool compact;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    if (tier <= 0) return const SizedBox.shrink();
    final colors = _colorsForTier(tier);
    final content = Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 5 : 9,
        vertical: compact ? 1 : 4,
      ),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: colors),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white.withValues(alpha: 0.75)),
        boxShadow: [
          BoxShadow(
            color: colors.last.withValues(alpha: 0.45),
            blurRadius: compact ? 8 : 12,
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.diamond_rounded,
            color: Colors.white,
            size: compact ? 12 : 15,
          ),
          SizedBox(width: compact ? 3 : 4),
          Text(
            'SVIP$tier',
            style: TextStyle(
              color: Colors.white,
              fontSize: compact ? 8 : 12,
              fontWeight: FontWeight.w900,
              fontStyle: FontStyle.italic,
              shadows: const [
                Shadow(color: Colors.black54, blurRadius: 4),
              ],
            ),
          ),
        ],
      ),
    );
    if (onTap == null) return content;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: content,
    );
  }
}

List<Color> _colorsForTier(int tier) {
  if (tier >= 3) {
    return const [Color(0xFFFFC857), Color(0xFFFF3D84)];
  }
  if (tier == 2) {
    return const [Color(0xFF47D9FF), Color(0xFF766DFF)];
  }
  return const [Color(0xFF7D6BFF), Color(0xFF55D6FF)];
}
