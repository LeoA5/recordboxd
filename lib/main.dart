import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Album Search Demo',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
      ),
      home: const AlbumSearchPage(title: 'Add an Album'),
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
  Timer? _debounce;

  List<AlbumResult> _results = [];
  bool _isLoading = false;
  String? _errorMessage;
  AlbumResult? _selectedAlbum;

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
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
    });
    // TODO: this is where you'd save `album` to Firestore under
    // users/{uid}/albums/{album.collectionId}.
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: Text(widget.title),
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
                border: const OutlineInputBorder(),
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
}