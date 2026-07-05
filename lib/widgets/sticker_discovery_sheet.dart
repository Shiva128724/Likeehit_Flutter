import 'package:flutter/material.dart';
import '../models/sticker_overlay_item.dart';

class MockStickerDatabase {
  // Generates 100% unique animated and static sticker URLs dynamically based on keywords
  static List<String> search(String query, int offset, int limit) {
    final safeQuery = query.isEmpty ? 'trending' : query.replaceAll(' ', '_');
    return List.generate(limit, (i) {
      final index = offset + i + 1; // 1-indexed to avoid 0

      // Mix animated GIFs (Pokemon sprites which are 100% reliable) and static emojis
      if (index % 4 == 0) {
        // Animated GIF
        int dexNum = (index.hashCode % 600) + 1;
        return 'https://raw.githubusercontent.com/PokeAPI/sprites/master/sprites/pokemon/versions/generation-v/black-white/animated/$dexNum.gif';
      } else if (index % 3 == 0) {
        // Real-world placeholder images to simulate varied GIPHY static categories
        return 'https://loremflickr.com/200/200/$safeQuery?lock=$index';
      } else {
        // High quality static Sticker Avatars
        return 'https://api.dicebear.com/7.x/fun-emoji/png?seed=${safeQuery}_$index';
      }
    });
  }

  static List<String> getRecentLottie() {
    return [
      'https://assets9.lottiefiles.com/packages/lf20_U16D2c.json',
      'https://assets9.lottiefiles.com/packages/lf20_h5pd0sya.json',
      'https://assets1.lottiefiles.com/packages/lf20_QpolL2.json',
      'https://assets5.lottiefiles.com/packages/lf20_yzoqyyqf.json',
    ];
  }
}

class StickerDiscoverySheet extends StatefulWidget {
  const StickerDiscoverySheet({super.key});

  @override
  State<StickerDiscoverySheet> createState() => _StickerDiscoverySheetState();
}

class _StickerDiscoverySheetState extends State<StickerDiscoverySheet> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  List<String> _popularGifs = [];
  final List<String> _recentLottie = MockStickerDatabase.getRecentLottie();

  final ScrollController _scrollController = ScrollController();
  bool _isLoadingMore = false;
  bool _isSearching = false;

  @override
  void initState() {
    super.initState();
    _populateInitialStickers();
    _scrollController.addListener(() {
      if (_scrollController.position.pixels >=
          _scrollController.position.maxScrollExtent - 200) {
        _loadMoreStickers();
      }
    });
  }

  void _populateInitialStickers() {
    _popularGifs = MockStickerDatabase.search('', 0, 40);
  }

  void _loadMoreStickers() {
    if (_isLoadingMore) return;
    setState(() {
      _isLoadingMore = true;
    });

    Future.delayed(const Duration(milliseconds: 500), () {
      if (mounted) {
        setState(() {
          // Fetch 20 unique new items based on current offset
          _popularGifs.addAll(
            MockStickerDatabase.search(_searchQuery, _popularGifs.length, 20),
          );
          _isLoadingMore = false;
        });
      }
    });
  }

  void _performSearch(String query) {
    setState(() {
      _searchQuery = query.toLowerCase();
      _isSearching = true;
    });

    // Simulate network fetch delay
    Future.delayed(const Duration(milliseconds: 300), () {
      if (mounted) {
        setState(() {
          _isSearching = false;
          _popularGifs = MockStickerDatabase.search(_searchQuery, 0, 40);
        });
      }
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _onStickerSelected(String url, bool isLottie) {
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;

    final item = StickerOverlayItem(
      assetUrl: url,
      isLottie: isLottie,
      dx: (screenWidth / 2) - 75,
      dy: (screenHeight / 2) - 75,
      scale: 1.0,
      rotation: 0.0,
    );
    Navigator.pop(context, item);
  }

  Widget _buildSearchBar() {
    return Container(
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white12,
        borderRadius: BorderRadius.circular(12),
      ),
      child: TextField(
        controller: _searchController,
        style: const TextStyle(color: Colors.white),
        onChanged: _performSearch,
        decoration: InputDecoration(
          prefixIcon: const Icon(Icons.search, color: Colors.white54),
          suffixIcon: _searchQuery.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.clear, color: Colors.white54),
                  onPressed: () {
                    _searchController.clear();
                    _performSearch('');
                  },
                )
              : null,
          hintText: 'Search GIPHY',
          hintStyle: const TextStyle(color: Colors.white54),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 14,
          ),
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      child: Text(
        title,
        style: const TextStyle(
          color: Colors.white70,
          fontSize: 14,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildLottieGrid() {
    return SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      sliver: SliverGrid(
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 4,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
        ),
        delegate: SliverChildBuilderDelegate((context, index) {
          final url = _recentLottie[index];
          return GestureDetector(
            onTap: () => _onStickerSelected(url, true),
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white10,
                borderRadius: BorderRadius.circular(8),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: const Icon(
                  Icons.auto_awesome,
                  color: Colors.white70,
                  size: 42,
                ),
              ),
            ),
          );
        }, childCount: _recentLottie.length),
      ),
    );
  }

  Widget _buildGifGrid() {
    return SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      sliver: SliverGrid(
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 4,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
        ),
        delegate: SliverChildBuilderDelegate((context, index) {
          final url = _popularGifs[index];
          return GestureDetector(
            onTap: () => _onStickerSelected(url, false),
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white10,
                borderRadius: BorderRadius.circular(8),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.network(
                  url,
                  fit: BoxFit.cover,
                  loadingBuilder: (context, child, loadingProgress) {
                    if (loadingProgress == null) return child;
                    return const Center(
                      child: CircularProgressIndicator(
                        color: Colors.white54,
                        strokeWidth: 2,
                      ),
                    );
                  },
                  errorBuilder: (context, error, stackTrace) => const Icon(
                    Icons.image_not_supported,
                    color: Colors.white24,
                    size: 36,
                  ),
                ),
              ),
            ),
          );
        }, childCount: _popularGifs.length),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF1C1C1C),
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          // Drag Handle
          Container(
            width: 40,
            height: 4,
            margin: const EdgeInsets.only(top: 12, bottom: 8),
            decoration: BoxDecoration(
              color: Colors.white30,
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          _buildSearchBar(),

          Expanded(
            child: _isSearching
                ? const Center(
                    child: CircularProgressIndicator(color: Colors.white),
                  )
                : CustomScrollView(
                    controller: _scrollController,
                    physics: const BouncingScrollPhysics(),
                    slivers: [
                      if (_searchQuery.isEmpty) ...[
                        SliverToBoxAdapter(
                          child: _buildSectionHeader('Recent'),
                        ),
                        _buildLottieGrid(),
                        const SliverToBoxAdapter(child: SizedBox(height: 24)),
                        SliverToBoxAdapter(
                          child: _buildSectionHeader('Trending on GIPHY'),
                        ),
                        _buildGifGrid(),
                        const SliverToBoxAdapter(child: SizedBox(height: 32)),
                      ] else ...[
                        SliverToBoxAdapter(
                          child: _buildSectionHeader(
                            'Search Results for "$_searchQuery"',
                          ),
                        ),
                        _buildGifGrid(),
                      ],
                      if (_isLoadingMore)
                        const SliverToBoxAdapter(
                          child: Padding(
                            padding: EdgeInsets.symmetric(vertical: 24.0),
                            child: Center(
                              child: CircularProgressIndicator(
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}
