class UserLevelState {
  const UserLevelState({
    required this.totalExp,
    required this.level,
    required this.currentLevelExp,
    required this.nextLevelExp,
    required this.expInLevel,
    required this.expNeededForNextLevel,
    required this.isMaxLevel,
  });

  final int totalExp;
  final int level;
  final int currentLevelExp;
  final int nextLevelExp;
  final int expInLevel;
  final int expNeededForNextLevel;
  final bool isMaxLevel;

  double get progress {
    if (isMaxLevel || expNeededForNextLevel <= 0) return 1;
    return (expInLevel / expNeededForNextLevel).clamp(0, 1).toDouble();
  }
}

class LevelService {
  const LevelService._();

  static const int userMaxLevel = 100;

  static UserLevelState userLevelFromUserData(Map<String, dynamic> data) {
    final explicitExp = _asInt(data['userExpTotal']);
    final giftedExp = _asInt(data['totalGiftedStars']);
    final totalExp = explicitExp > 0 ? explicitExp : giftedExp;
    return userLevelFromExp(totalExp);
  }

  static UserLevelState userLevelFromExp(int totalExp) {
    final safeExp = totalExp < 0 ? 0 : totalExp;
    final level = userLevelForExp(safeExp);
    final currentLevelExp = userExpForLevel(level);
    final nextLevelExp = userExpForLevel(level + 1);
    final isMaxLevel = level >= userMaxLevel;
    final expNeeded = isMaxLevel ? 0 : nextLevelExp - currentLevelExp;
    final expInLevel = isMaxLevel
        ? 0
        : (safeExp - currentLevelExp).clamp(0, expNeeded);
    return UserLevelState(
      totalExp: safeExp,
      level: level,
      currentLevelExp: currentLevelExp,
      nextLevelExp: nextLevelExp,
      expInLevel: expInLevel,
      expNeededForNextLevel: expNeeded,
      isMaxLevel: isMaxLevel,
    );
  }

  static int userLevelForExp(int totalExp) {
    if (totalExp <= 0) return 0;
    for (var level = userMaxLevel; level >= 0; level--) {
      if (totalExp >= userExpForLevel(level)) return level;
    }
    return 0;
  }

  static int userExpForLevel(int level) {
    final safeLevel = level.clamp(0, userMaxLevel);
    var total = 0;
    for (var current = 0; current < safeLevel; current++) {
      total += userExpNeededForNextLevel(current);
    }
    return total;
  }

  static int userExpNeededForNextLevel(int currentLevel) {
    final safeLevel = currentLevel.clamp(0, userMaxLevel);
    return 50 + (safeLevel * 60);
  }

  static int _asInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }
}
