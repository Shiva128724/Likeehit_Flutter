import 'package:flutter/material.dart';
import 'models/effect_model.dart';

class EffectsDiscoverySheet extends StatefulWidget {
  final ValueChanged<EffectModel> onEffectSelected;

  const EffectsDiscoverySheet({super.key, required this.onEffectSelected});

  @override
  State<EffectsDiscoverySheet> createState() => _EffectsDiscoverySheetState();
}

class _EffectsDiscoverySheetState extends State<EffectsDiscoverySheet>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final ScrollController _scrollController = ScrollController();

  EffectModel? _activeEffect;

  final List<EffectModel> _effects = [];
  bool _isLoading = false;
  int _currentPage = 0;
  final int _limit = 50;
  bool _hasMore = true;

  final List<String> _tabs = [
    'Search 🔍',
    'Saved 🔖',
    'Active ✨',
    'TRENDING',
    'REELS',
    'APPEARANCE',
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _tabs.length, vsync: this);
    _tabController.addListener(_onTabChanged);
    _scrollController.addListener(_onScroll);

    // Load initial data for first tab
    _tabController.index = 3; // Default to TRENDING
    _loadEffects(refresh: true);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _onTabChanged() {
    if (_tabController.indexIsChanging) {
      _loadEffects(refresh: true);
    }
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      _loadEffects();
    }
  }

  Future<void> _loadEffects({bool refresh = false}) async {
    if (_isLoading || (!_hasMore && !refresh)) return;

    if (refresh) {
      setState(() {
        _isLoading = true;
        _currentPage = 0;
        _effects.clear();
        _hasMore = true;
      });
    } else {
      setState(() {
        _isLoading = true;
      });
    }

    try {
      final category = _tabs[_tabController.index];
      final newEffects = await EffectService.fetchEffects(
        _currentPage,
        _limit,
        category: category,
      );

      if (mounted) {
        setState(() {
          _currentPage++;
          _isLoading = false;
          if (newEffects.isEmpty) {
            _hasMore = false;
          } else {
            _effects.addAll(newEffects);
          }
        });
      }
    } catch (e) {
      debugPrint('Error loading effects: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _selectEffect(EffectModel effect) {
    setState(() {
      _activeEffect = effect;
    });
    widget.onEffectSelected(effect);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF1E1E1E), // Dark transparent-friendly background
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          // Drag Handle
          Container(
            margin: const EdgeInsets.only(top: 12, bottom: 8),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.white24,
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          // Top Section: Active Effect Info
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: 16.0,
              vertical: 8.0,
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                IconButton(
                  icon: const Icon(
                    Icons.bookmark_border,
                    color: Colors.white,
                    size: 28,
                  ),
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Effect saved!')),
                    );
                  },
                ),
                Expanded(
                  child: Column(
                    children: [
                      Text(
                        _activeEffect?.name ?? 'Select an Effect',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                        textAlign: TextAlign.center,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _activeEffect?.owner ?? 'None',
                        style: const TextStyle(
                          color: Colors.white54,
                          fontSize: 13,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(
                    Icons.info_outline,
                    color: Colors.white,
                    size: 28,
                  ),
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Effect details coming soon'),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),

          // Tabbed Navigation Bar
          TabBar(
            controller: _tabController,
            isScrollable: true,
            indicatorColor: Colors.white,
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white54,
            labelStyle: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 13,
            ),
            tabs: _tabs.map((t) => Tab(text: t)).toList(),
          ),
          const Divider(color: Colors.white12, height: 1),

          // 3x3 Grid View Layout
          Expanded(
            child: _effects.isEmpty && _isLoading
                ? const Center(
                    child: CircularProgressIndicator(color: Colors.white),
                  )
                : GridView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.all(16.0),
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 3,
                          crossAxisSpacing: 16,
                          mainAxisSpacing: 16,
                          childAspectRatio: 0.8,
                        ),
                    itemCount: _effects.length + (_hasMore ? 1 : 0),
                    itemBuilder: (context, index) {
                      if (index == _effects.length) {
                        return const Center(
                          child: CircularProgressIndicator(
                            color: Colors.white54,
                          ),
                        );
                      }

                      final effect = _effects[index];
                      final isSelected = _activeEffect?.id == effect.id;

                      return GestureDetector(
                        onTap: () => _selectEffect(effect),
                        child: Column(
                          children: [
                            Expanded(
                              child: Container(
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  border: isSelected
                                      ? Border.all(
                                          color: Colors.blueAccent,
                                          width: 3,
                                        )
                                      : Border.all(
                                          color: Colors.transparent,
                                          width: 3,
                                        ),
                                ),
                                child: ClipOval(
                                  child: Image.network(
                                    effect.thumbnailUrl,
                                    fit: BoxFit.cover,
                                    errorBuilder: (context, error, stackTrace) {
                                      return Container(
                                        color: Colors.white12,
                                        child: const Icon(
                                          Icons.auto_awesome,
                                          color: Colors.white54,
                                        ),
                                      );
                                    },
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              effect.name,
                              style: TextStyle(
                                color: isSelected
                                    ? Colors.blueAccent
                                    : Colors.white,
                                fontSize: 12,
                                fontWeight: isSelected
                                    ? FontWeight.bold
                                    : FontWeight.normal,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
