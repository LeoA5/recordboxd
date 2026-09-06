import 'dart:async';
import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:dynamic_color/dynamic_color.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import 'firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  // Used only as a fallback on platforms/OS versions where Material You's
  // wallpaper-based dynamic color isn't available (pre-Android 12, iOS,
  // desktop, web). A deep rosewood rather than Flutter's own default
  // seed-purple, so the app has an identity even without dynamic color.
  static const _fallbackSeed = Color(0xFFB33951);

  ThemeData _buildTheme(ColorScheme colorScheme) {
    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      visualDensity: VisualDensity.adaptivePlatformDensity,
      appBarTheme: const AppBarTheme(centerTitle: false, elevation: 0),
      cardTheme: CardThemeData(
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: colorScheme.outlineVariant),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return DynamicColorBuilder(
      builder: (lightDynamic, darkDynamic) {
        return MaterialApp(
          title: 'Recordboxd',
          // Follow the device's current light/dark setting automatically,
          // rather than forcing one or the other.
          themeMode: ThemeMode.system,
          theme: _buildTheme(
            lightDynamic ?? ColorScheme.fromSeed(seedColor: _fallbackSeed),
          ),
          darkTheme: _buildTheme(
            darkDynamic ??
                ColorScheme.fromSeed(
                  seedColor: _fallbackSeed,
                  brightness: Brightness.dark,
                ),
          ),
          home: const LoginPage(),
        );
      },
    );
  }
}

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  bool _obscurePassword = true;
  bool _isLoading = false;
  bool _isSignUpMode = false; // false = Log In, true = Create Account
  String? _errorMessage;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text;

    if (email.isEmpty || password.isEmpty) {
      setState(() {
        _errorMessage = 'Please enter both an email and a password.';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      if (_isSignUpMode) {
        await FirebaseAuth.instance.createUserWithEmailAndPassword(
          email: email,
          password: password,
        );
      } else {
        await FirebaseAuth.instance.signInWithEmailAndPassword(
          email: email,
          password: password,
        );
      }

      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (context) => const HomeShell()),
      );
    } on FirebaseAuthException catch (e) {
      // Map Firebase's error codes to messages worth showing a user.
      // Full list: https://firebase.google.com/docs/auth/admin/errors
      String message;
      switch (e.code) {
        case 'invalid-email':
          message = 'That email address looks invalid.';
        case 'user-not-found':
          message = 'No account found for that email.';
        case 'wrong-password':
        case 'invalid-credential':
          message = 'Incorrect email or password.';
        case 'email-already-in-use':
          message = 'An account already exists for that email.';
        case 'weak-password':
          message = 'Password should be at least 6 characters.';
        default:
          message = 'Something went wrong (${e.code}). Please try again.';
      }
      if (!mounted) return;
      setState(() {
        _errorMessage = message;
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(_isSignUpMode ? 'Create Account' : 'Log In')),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: _emailController,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(
                labelText: 'Email',
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _passwordController,
              obscureText: _obscurePassword,
              decoration: InputDecoration(
                labelText: 'Password',
                suffixIcon: IconButton(
                  icon: Icon(
                    _obscurePassword ? Icons.visibility : Icons.visibility_off,
                  ),
                  onPressed: () {
                    setState(() {
                      _obscurePassword = !_obscurePassword;
                    });
                  },
                ),
              ),
            ),
            const SizedBox(height: 8),
            if (_errorMessage != null)
              Text(
                _errorMessage!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: _isLoading ? null : _submit,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 8.0),
                child: _isLoading
                    ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
                    : Text(
                  _isSignUpMode ? 'Create Account' : 'Log In',
                  style: TextStyle(fontSize: 17.5),
                ),
              ),
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: _isLoading
                  ? null
                  : () {
                setState(() {
                  _isSignUpMode = !_isSignUpMode;
                  _errorMessage = null;
                });
              },
              child: Text(
                _isSignUpMode
                    ? 'Already have an account? Log in'
                    : "Don't have an account? Create one",
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Signs the user out and sends them back to the login screen, clearing the
// entire navigation stack so the back button can't return to a signed-out
// session's screens.
Future<void> _signOut(BuildContext context) async {
  await FirebaseAuth.instance.signOut();
  if (!context.mounted) return;
  Navigator.of(context).pushAndRemoveUntil(
    MaterialPageRoute(builder: (context) => const LoginPage()),
        (route) => false,
  );
}

class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _selectedIndex = 0;

  static const List<Widget> _pages = [
    HomePage(),
    YourReviewsPage(),
    FeedPage(),
    TrendsPage(),
    AlbumSearchPage(title: 'Add Album Review'),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _pages[_selectedIndex],
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: (index) {
          setState(() {
            _selectedIndex = index;
          });
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home),
            label: 'Home',
          ),
          NavigationDestination(
            icon: Icon(Icons.my_library_music_outlined),
            selectedIcon: Icon(Icons.my_library_music),
            label: 'My Reviews',
          ),
          NavigationDestination(
            icon: Icon(Icons.feed_outlined),
            selectedIcon: Icon(Icons.feed),
            label: 'Feed',
          ),
          NavigationDestination(
              icon: Icon(Icons.trending_up_outlined),
              selectedIcon: Icon(Icons.trending_up),
              label: 'Trends'
          ),
          NavigationDestination(
            icon: Icon(Icons.my_library_add_outlined),
            selectedIcon: Icon(Icons.my_library_add),
            label: 'Add Album',
          ),
        ],
      ),
    );
  }
}

// One review document, stored in the top-level `reviews` Firestore collection
// (not nested under a user) so the Explore tab can query across everyone.
class Review {
  final String id;
  final String userId;
  final String userEmail;
  final String albumId;
  final String albumName;
  final String artistName;
  final String artworkUrl;
  final String genre;
  final double rating;
  final String reviewText;
  final DateTime createdAt;

  Review({
    required this.id,
    required this.userId,
    required this.userEmail,
    required this.albumId,
    required this.albumName,
    required this.artistName,
    required this.artworkUrl,
    required this.genre,
    required this.rating,
    required this.reviewText,
    required this.createdAt,
  });

  factory Review.fromDoc(QueryDocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data();
    return Review(
      id: doc.id,
      userId: data['userId'] as String? ?? '',
      userEmail: data['userEmail'] as String? ?? 'Unknown',
      albumId: data['albumId'] as String? ?? '',
      albumName: data['albumName'] as String? ?? 'Unknown album',
      artistName: data['artistName'] as String? ?? 'Unknown artist',
      artworkUrl: data['artworkUrl'] as String? ?? '',
      genre: data['genre'] as String? ?? 'Unknown',
      rating: (data['rating'] as num?)?.toDouble() ?? 0.0,
      reviewText: data['reviewText'] as String? ?? '',
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ??
          DateTime.fromMillisecondsSinceEpoch(0),
    );
  }
}

// A row of 5 stars supporting half-star precision. Pass `onRatingChanged` to
// make it tappable; leave it null (the default) for a read-only display, as
// used when showing an existing review's rating in a list.
class StarRatingInput extends StatelessWidget {
  const StarRatingInput({
    super.key,
    required this.rating,
    this.size = 32,
    this.onRatingChanged,
  });

  final double rating; // 0.0–5.0, in 0.5 increments
  final double size;
  final ValueChanged<double>? onRatingChanged;

  Widget _buildStar(int index) {
    // How much of this particular star should be filled: 0, 0.5, or 1.
    final fillFraction = (rating - index).clamp(0.0, 1.0);

    final star = SizedBox(
      width: size,
      height: size,
      child: Stack(
        children: [
          Icon(Icons.star_border, size: size, color: Colors.grey),
          ClipRect(
            clipper: _FractionalClipper(fraction: fillFraction),
            child: Icon(Icons.star, size: size, color: Colors.amber),
          ),
        ],
      ),
    );

    if (onRatingChanged == null) {
      return star;
    }

    // Tapping the left half of a star sets a half-star rating; the right
    // half sets a full star.
    return GestureDetector(
      onTapDown: (details) {
        final isHalf = details.localPosition.dx < size / 2;
        onRatingChanged!(index + (isHalf ? 0.5 : 1.0));
      },
      child: star,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(5, _buildStar),
    );
  }
}

class _FractionalClipper extends CustomClipper<Rect> {
  _FractionalClipper({required this.fraction});
  final double fraction;

  @override
  Rect getClip(Size size) => Rect.fromLTRB(0, 0, size.width * fraction, size.height);

  @override
  bool shouldReclip(covariant _FractionalClipper oldClipper) =>
      oldClipper.fraction != fraction;
}

// Shared row layout used by Home, Your Reviews, and Explore to display one
// review: artwork (stored on the review itself, never re-fetched from
// iTunes), album/artist, star rating, optional reviewer email, and text.
class _ReviewTile extends StatelessWidget {
  const _ReviewTile({required this.review, required this.showEmail});

  final Review review;
  final bool showEmail;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 56,
            height: 56,
            child: review.artworkUrl.isNotEmpty
                ? Image.network(
              review.artworkUrl,
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) => const Icon(Icons.album),
            )
                : const Icon(Icons.album),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  review.albumName,
                  style: Theme.of(context).textTheme.titleMedium,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  review.artistName,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: 4),
                StarRatingInput(rating: review.rating, size: 18),
                if (showEmail) ...[
                  const SizedBox(height: 4),
                  Text(
                    review.userEmail,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ],
                if (review.reviewText.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(review.reviewText),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class TrendsPage extends StatefulWidget {
  const TrendsPage({super.key});

  @override
  State<TrendsPage> createState() => _TrendsPageState();
}

// Aggregate function that sorts the top n items by the key given
List<({String label, int count, Review sample})> _aggregate(
    List<Review> reviews,
    String Function(Review) keyOf,
    ) {
  final Map<String, int>counts = <String, int>{};
  final Map<String, Review> samples = <String, Review>{};

  for (final review in reviews) {
    final key = keyOf(review);
    counts[key] = (counts[key] ?? 0) + 1;
    samples.putIfAbsent(key, () => review);
  }

  final entries = counts.entries
      .map((e) => (label: e.key, count: e.value, sample: samples[e.key]!))
      .toList();
  entries.sort((a,b) => b.count.compareTo(a.count));
  return entries;
}

class _TrendsPageState extends State<TrendsPage> {
  List<Review> _recentReviews = [];
  bool _isLoading = true;
  String? _errorMessage;

  // Record lists for top artists, albums, and users
  List<({String label, int count, Review sample})> _topArtists = [];
  List<({String label, int count, Review sample})> _topAlbums = [];
  List<({String label, int count, Review sample})> _topUsers = [];

  // Calls _loadTrends on page generation
  @override
  void initState() {
    super.initState();
    _loadTrends();
  }

  Future<void> _loadTrends() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final Timestamp cutoff = Timestamp.fromDate(
        DateTime.now().subtract(const Duration(days: 7))
    );
    try{
      QuerySnapshot<Map<String, dynamic>> snapshot = await FirebaseFirestore
          .instance
          .collection('reviews')
          .where('createdAt', isGreaterThan: cutoff)
          .get();
      if (!mounted) return;
      setState(() {
        _recentReviews = snapshot.docs.map(Review.fromDoc).toList();
        _topArtists = _aggregate(_recentReviews, (r) => r.artistName)
            .take(3).toList();
        _topAlbums = _aggregate(_recentReviews, (r) => r.albumName)
            .take(5).toList();
        _topUsers = _aggregate(_recentReviews, (r) => r.userEmail)
            .take(3).toList();
        _isLoading = false;
      });
    }
    catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = 'Unknown Error: $e';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Trends'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Log out',
            onPressed: () => _signOut(context),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage != null
          ? Center(child: Text(_errorMessage!))
          : RefreshIndicator(
        onRefresh: _loadTrends,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16.0),
          children: [
            Text(
              'Most Reviewed Artists (Last 7 Days)',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            _buildRankedSection(_topArtists),
            const Divider(height: 32),
            Text(
              'Most Reviewed Albums (Last 7 Days)',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            _buildRankedSection(_topAlbums, showArtwork: true),
            const Divider(height: 32),
            Text(
              'Most Active Users (Last 7 Days)',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            _buildRankedSection(_topUsers),
          ],
        ),
      ),
    );
  }

  // Shared row layout for all three ranked lists: a rank badge (or, when
  // showArtwork is true, a thumbnail from the entry's representative
  // review), the label (artist/album/user), and its count over 7 days.
  Widget _buildRankedSection(
      List<({String label, int count, Review sample})> entries, {
        bool showArtwork = false,
      }) {
    if (entries.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 12.0),
        child: Text('No reviews in the last 7 days yet.'),
      );
    }

    return Column(
      children: [
        for (var i = 0; i < entries.length; i++)
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: showArtwork
                ? SizedBox(
              width: 48,
              height: 48,
              child: entries[i].sample.artworkUrl.isNotEmpty
                  ? Image.network(
                entries[i].sample.artworkUrl,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) =>
                const Icon(Icons.album),
              )
                  : const Icon(Icons.album),
            )
                : CircleAvatar(child: Text('${i + 1}')),
            title: Text(
              // With artwork already conveying "this is one item in a
              // list," the rank is folded into the label text itself
              // instead of a separate badge, so the artwork stays the
              // single visual focus of the leading slot.
              showArtwork ? '${i + 1}. ${entries[i].label}' : entries[i].label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            trailing: Text(
              '${entries[i].count} review${entries[i].count == 1 ? '' : 's'}',
            ),
          ),
      ],
    );
  }
}

class YourReviewsPage extends StatefulWidget {
  const YourReviewsPage({super.key});

  @override
  State<YourReviewsPage> createState() => _YourReviewsPageState();
}

class _YourReviewsPageState extends State<YourReviewsPage> {
  List<Review> _reviews = [];
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadReviews();
  }

  Future<void> _loadReviews() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final uid = FirebaseAuth.instance.currentUser?.uid;

    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('reviews')
          .where('userId', isEqualTo: uid)
          .orderBy('createdAt', descending: true)
          .get();

      if (!mounted) return;
      setState(() {
        _reviews = snapshot.docs.map(Review.fromDoc).toList();
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = 'Could not load your reviews: $e';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('My Review Library'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Log out',
            onPressed: () => _signOut(context),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage != null
          ? Center(child: Text(_errorMessage!))
          : RefreshIndicator(
        onRefresh: _loadReviews,
        child: _reviews.isEmpty
            ? ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: const [
            Padding(
              padding: EdgeInsets.symmetric(vertical: 64.0),
              child: Center(
                child: Text(
                  'No reviews yet — search for an album to add one.',
                ),
              ),
            ),
          ],
        )
            : ListView.separated(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          itemCount: _reviews.length,
          separatorBuilder: (_, _) => const Divider(height: 1),
          itemBuilder: (context, index) => _ReviewTile(
            review: _reviews[index],
            showEmail: false,
          ),
        ),
      ),
    );
  }
}

class FeedPage extends StatefulWidget {
  const FeedPage({super.key});

  @override
  State<FeedPage> createState() => _FeedPageState();
}

class _FeedPageState extends State<FeedPage> {
  List<Review> _reviews = [];
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadFeed();
  }

  Future<void> _loadFeed() async{
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      QuerySnapshot<Map<String, dynamic>> snapshot = await FirebaseFirestore
          .instance
          .collection('reviews')
          .orderBy('createdAt', descending: true)
          .limit(100)
          .get();
      if (!mounted) return;
      setState(() {
        _reviews = snapshot.docs.map(Review.fromDoc).toList();
        _isLoading = false;
      });
    }
    catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = 'Could not load the feed: $e';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Feed'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Log out',
            onPressed: () => _signOut(context),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage != null
          ? Center(child: Text(_errorMessage!))
          : RefreshIndicator(
        onRefresh: _loadFeed,
        child: _reviews.isEmpty
            ? ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: const [
            Padding(
              padding: EdgeInsets.symmetric(vertical: 64.0),
              child: Center(child: Text('No reviews yet.')),
            ),
          ],
        )
            : ListView.separated(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          itemCount: _reviews.length,
          separatorBuilder: (_, _) => const Divider(height: 1),
          itemBuilder: (context, index) =>
              _ReviewTile(review: _reviews[index], showEmail: true),
        ),
      ),
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  bool _isLoading = true;
  String? _errorMessage;
  Review? _yourLatestReview;
  List<Review> _othersRecentReviews = [];
  String? _topArtist;
  int _topArtistCount = 0;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final firestore = FirebaseFirestore.instance;

      final yourLatestSnapshot = await firestore
          .collection('reviews')
          .where('userId', isEqualTo: uid)
          .orderBy('createdAt', descending: true)
          .limit(1)
          .get();

      // All of your reviews, used only to tally counts per artist below.
      final allYourReviewsSnapshot = await firestore
          .collection('reviews')
          .where('userId', isEqualTo: uid)
          .get();

      final recentOverallSnapshot = await firestore
          .collection('reviews')
          .orderBy('createdAt', descending: true)
          .limit(10)
          .get();

      final artistCounts = <String, int>{};
      for (final doc in allYourReviewsSnapshot.docs) {
        final review = Review.fromDoc(doc);
        artistCounts[review.artistName] =
            (artistCounts[review.artistName] ?? 0) + 1;
      }

      String? topArtist;
      var topCount = 0;
      artistCounts.forEach((artist, reviewCount) {
        if (reviewCount > topCount) {
          topArtist = artist;
          topCount = reviewCount;
        }
      });

      final othersRecent = recentOverallSnapshot.docs
          .map(Review.fromDoc)
          .where((r) => r.userId != uid)
          .take(3)
          .toList();

      if (!mounted) return;
      setState(() {
        _yourLatestReview = yourLatestSnapshot.docs.isNotEmpty
            ? Review.fromDoc(yourLatestSnapshot.docs.first)
            : null;
        _othersRecentReviews = othersRecent;
        _topArtist = topArtist;
        _topArtistCount = topCount;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = 'Could not load your home screen: $e';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Home'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Log out',
            onPressed: () => _signOut(context),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage != null
          ? Center(child: Text(_errorMessage!))
          : RefreshIndicator(
        onRefresh: _loadData,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16.0),
          children: [
            Text(
              'Your Most Recent Review',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            _yourLatestReview != null
                ? _ReviewTile(
              review: _yourLatestReview!,
              showEmail: false,
            )
                : const Padding(
              padding: EdgeInsets.symmetric(vertical: 12.0),
              child: Text("You haven't reviewed any albums yet."),
            ),
            const Divider(height: 32),
            Text(
              'Your Top Artist',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            _topArtist != null
                ? Text(
              '$_topArtist ($_topArtistCount album${_topArtistCount == 1 ? '' : 's'} reviewed)',
            )
                : const Text(
              'Not enough reviews yet to determine a top artist.',
            ),
            const Divider(height: 32),
            Text(
              'Other Recent Reviews',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            if (_othersRecentReviews.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 12.0),
                child: Text('No reviews from other users yet.'),
              )
            else
              ..._othersRecentReviews.map(
                    (r) => _ReviewTile(review: r, showEmail: true),
              ),
          ],
        ),
      ),
    );
  }
}

// Simple model for one iTunes search result.
class AlbumResult {
  final String collectionId;
  final String collectionName;
  final String artistName;
  final String artworkUrl;
  final int trackCount;
  final String releaseDate;
  final String genre;

  AlbumResult({
    required this.collectionId,
    required this.collectionName,
    required this.artistName,
    required this.artworkUrl,
    required this.trackCount,
    required this.releaseDate,
    required this.genre,
  });

  factory AlbumResult.fromJson(Map<String, dynamic> json) {
    // Bump artwork resolution from 100x100 to 600x600 for a nicer image.
    final rawArt = json['artworkUrl100'] as String? ?? '';
    final hiResArt = rawArt.replaceAll('100x100bb', '600x600bb');

    return AlbumResult(
      collectionId: json['collectionId']?.toString() ?? '',
      collectionName: json['collectionName'] as String? ?? 'Unknown title',
      artistName: json['artistName'] as String? ?? 'Unknown artist',
      artworkUrl: hiResArt,
      trackCount: json['trackCount'] as int? ?? 0,
      releaseDate: json['releaseDate'] as String? ?? '',
      genre: json['primaryGenreName'] as String? ?? 'Unknown',
    );
  }
}

// Strip case, punctuation, and extra whitespace so "Guns N Roses" matches
// "Guns N' Roses", etc.
String _normalize(String s) {
  return s
      .toLowerCase()
      .trim()
      .replaceAll(RegExp(r"[^\w\s]"), '')
      .replaceAll(RegExp(r'\s+'), ' ');
}

class AlbumSearchPage extends StatefulWidget {
  const AlbumSearchPage({super.key, required this.title});

  final String title;

  @override
  State<AlbumSearchPage> createState() => _AlbumSearchPageState();
}

class _AlbumSearchPageState extends State<AlbumSearchPage> {
  final TextEditingController _controller = TextEditingController();
  final TextEditingController _reviewController = TextEditingController();
  Timer? _debounce;

  List<AlbumResult> _results = [];
  bool _isLoading = false;
  bool _isSubmitting = false;
  String? _errorMessage;
  AlbumResult? _selectedAlbum;
  double _rating = 0;

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    _reviewController.dispose();
    super.dispose();
  }

  void _onQueryChanged(String query) {
    // Reset debounce timer on every keystroke; only fire after 450ms of
    // silence so we don't hit the API on every character typed.
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 450), () {
      _search(query);
    });
  }

  Future<void> _search(String query) async {
    final trimmed = query.trim();
    if (trimmed.isEmpty) {
      setState(() {
        _results = [];
        _errorMessage = null;
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      // Uri.https handles encoding of spaces, apostrophes, accents, etc.
      final uri = Uri.https('itunes.apple.com', '/search', {
        'term': trimmed,
        'entity': 'album',
        'limit': '25',
      });

      final response = await http.get(uri);

      if (response.statusCode != 200) {
        throw Exception('Search failed (${response.statusCode})');
      }

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final rawResults = (data['results'] as List<dynamic>? ?? []);

      var albums = rawResults
          .map((r) => AlbumResult.fromJson(r as Map<String, dynamic>))
          .toList();

      // Sort exact (normalized) title matches first, then by track count
      // descending as a rough proxy for "real album" vs single/remix.
      final normalizedQuery = _normalize(trimmed);
      albums.sort((a, b) {
        final aExact = _normalize(a.collectionName) == normalizedQuery;
        final bExact = _normalize(b.collectionName) == normalizedQuery;
        if (aExact != bExact) return aExact ? -1 : 1;
        return b.trackCount.compareTo(a.trackCount);
      });

      if (!mounted) return;
      setState(() {
        _results = albums;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = 'Something went wrong. Check your connection.';
        _isLoading = false;
      });
    }
  }

  void _selectAlbum(AlbumResult album) {
    setState(() {
      _selectedAlbum = album;
      _results = [];
      _controller.text = '${album.artistName} — ${album.collectionName}';
      _rating = 0;
      _reviewController.clear();
    });
  }

  Future<void> _submitReview() async {
    final album = _selectedAlbum;
    final user = FirebaseAuth.instance.currentUser;
    if (album == null || user == null || _rating == 0) return;

    setState(() {
      _isSubmitting = true;
    });

    try {
      await FirebaseFirestore.instance.collection('reviews').add({
        'userId': user.uid,
        'userEmail': user.email ?? 'Unknown',
        'albumId': album.collectionId,
        'albumName': album.collectionName,
        'artistName': album.artistName,
        'artworkUrl': album.artworkUrl,
        'genre': album.genre,
        'rating': _rating,
        'reviewText': _reviewController.text.trim(),
        'createdAt': FieldValue.serverTimestamp(),
      });

      if (!mounted) return;
      setState(() {
        _selectedAlbum = null;
        _rating = 0;
        _controller.clear();
        _reviewController.clear();
        _isSubmitting = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Review saved!')),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isSubmitting = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to save review: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: Text(widget.title),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Log out',
            onPressed: () => _signOut(context),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: _controller,
              decoration: InputDecoration(
                labelText: 'Artist or album name',
                hintText: 'e.g. artist name, or artist + album',
                suffixIcon: _isLoading
                    ? const Padding(
                  padding: EdgeInsets.all(12.0),
                  child: SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                )
                    : (_controller.text.isNotEmpty
                    ? IconButton(
                  icon: const Icon(Icons.clear),
                  onPressed: () {
                    _controller.clear();
                    setState(() {
                      _results = [];
                      _selectedAlbum = null;
                    });
                  },
                )
                    : null),
              ),
              onChanged: _onQueryChanged,
            ),
            const SizedBox(height: 8),
            if (_errorMessage != null)
              Text(
                _errorMessage!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            if (_selectedAlbum != null) _buildSelectedCard(_selectedAlbum!),
            _buildReviewSection(),
            const SizedBox(height: 8),
            Expanded(
              child: _results.isEmpty
                  ? const SizedBox.shrink()
                  : ListView.separated(
                itemCount: _results.length,
                separatorBuilder: (_, _) => const Divider(height: 1),
                itemBuilder: (context, index) {
                  final album = _results[index];
                  return _buildResultTile(album);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildResultTile(AlbumResult album) {
    final year = album.releaseDate.length >= 4
        ? album.releaseDate.substring(0, 4)
        : '';

    return ListTile(
      leading: SizedBox(
        width: 48,
        height: 48,
        child: album.artworkUrl.isNotEmpty
            ? Image.network(
          album.artworkUrl,
          fit: BoxFit.cover,
          errorBuilder: (_, _, _) => const Icon(Icons.album),
        )
            : const Icon(Icons.album),
      ),
      title: Text(
        album.collectionName,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: Text(
        '${album.artistName} · $year · ${album.trackCount} tracks · ${album.genre}',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      onTap: () => _selectAlbum(album),
    );
  }

  Widget _buildSelectedCard(AlbumResult album) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: SizedBox(
          width: 48,
          height: 48,
          child: album.artworkUrl.isNotEmpty
              ? Image.network(album.artworkUrl, fit: BoxFit.cover)
              : const Icon(Icons.album),
        ),
        title: Text(album.collectionName),
        subtitle: Text('${album.artistName} · ${album.genre}'),
        trailing: const Icon(Icons.check_circle, color: Colors.green),
      ),
    );
  }

  Widget _buildReviewSection() {
    final hasAlbum = _selectedAlbum != null;

    return Opacity(
      opacity: hasAlbum ? 1.0 : 0.4,
      child: IgnorePointer(
        // Blocks all taps (stars included) until an album is selected —
        // this is what makes the section actually disabled, not just dim.
        ignoring: !hasAlbum,
        child: Card(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: StarRatingInput(
                    rating: _rating,
                    size: 36,
                    onRatingChanged: (value) => setState(() => _rating = value),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _reviewController,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    labelText: 'Write a review',
                  ),
                ),
                const SizedBox(height: 12),
                FilledButton(
                  onPressed: (hasAlbum && _rating > 0 && !_isSubmitting)
                      ? _submitReview
                      : null,
                  child: _isSubmitting
                      ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                      : const Text('Save Review'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}