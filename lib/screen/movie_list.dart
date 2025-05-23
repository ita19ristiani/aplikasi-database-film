import 'dart:async';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_application_1/service/preferences_service.dart';
import 'package:flutter_application_1/service/user_credential.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../service/movie_service.dart';
import '../model/movie_model.dart';
import '../screen/movie_detail.dart';
import '../screen/upload_data.dart';

class MovieListScreen extends StatefulWidget {
  const MovieListScreen({super.key});

  @override
  _MovieListScreenState createState() => _MovieListScreenState();
}

class _MovieListScreenState extends State<MovieListScreen> {
  final MovieApiService _apiService = MovieApiService();
  late Future<List<Movie>> _futureMovies;
  final List<Movie> _movies = [];
  final List<Movie> _suggestions = [];
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  Timer? _debounce;
  Credentials? _credentials;

  @override
  void initState() {
    super.initState();
    _getCredentials();
    _loadMovies();
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _searchController.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  void performSearch(String query) async {
    if (query.isEmpty) {
      setState(() {
        _suggestions.clear(); // Kosongkan suggestion jika query kosong
      });
      return;
    }

    try {
      final movies = await _apiService.searchMovies(query);
      setState(() {
        _suggestions
          ..clear()
          ..addAll(movies); // Perbarui daftar suggestion
      });
      print('Hasil pencarian: ${movies.length} film ditemukan');
    } catch (e) {
      print('Error saat mencari film: $e');
    }
  }

  Future _getCredentials() async {
    final prefs = PreferencesService.getCredentials();
    print(prefs);
    if (prefs != null) {
      setState(() {
        _credentials = prefs;
      });
    }
  }

  Future<void> _loadMovies() async {
    try {
      final movies = await _apiService.getMovies(query: '');
      setState(() {
        _movies
          ..clear()
          ..addAll(movies);
      });
    } catch (e) {
      print('Error saat memuat film: $e');
    }
  }

  void _onSearchChanged() {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 500), () {
      final query = _searchController.text.trim();
      if (query.isNotEmpty) {
        performSearch(query); // Panggil pencarian
      } else {
        setState(() {
          _suggestions.clear(); // Kosongkan suggestion jika input kosong
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: TextField(
          controller: _searchController,
          onChanged: (value) {
            if (value.isNotEmpty) {
              performSearch(value); // Panggil pencarian
            } else {
              setState(() {
                _suggestions.clear(); // Kosongkan suggestion jika input kosong
              });
            }
          },
          onSubmitted: (value) async {
            // Tampilkan semua hasil pencarian saat tombol Enter ditekan
            final movies = await _apiService.searchMovies(value);
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => SearchResultScreen(searchResults: movies),
              ),
            );
          },
          decoration: InputDecoration(
            hintText: 'Cari Anime...',
            border: InputBorder.none,
            prefixIcon: const Icon(Icons.search),
            suffixIcon: _searchController.text.isNotEmpty
                ? IconButton(
                    icon: const Icon(Icons.clear),
                    onPressed: () {
                      setState(() {
                        _searchController.clear();
                        _suggestions.clear(); // Kosongkan suggestion
                      });
                      _loadMovies(); // Muat ulang daftar utama
                    },
                  )
                : null,
            filled: true,
            fillColor: Colors.white.withOpacity(0.2),
          ),
        ),
      ),
      body: Stack(
        children: [
          // Daftar utama
          RefreshIndicator(
            onRefresh: _loadMovies,
            child: _movies.isEmpty
                ? Center(
                    child: Text(
                      _searchController.text.isEmpty
                          ? 'Tidak ada film tersedia'
                          : 'Tidak ada hasil ditemukan',
                      style: TextStyle(fontSize: 16, color: Colors.grey[600]),
                    ),
                  )
                : GridView.builder(
                    padding: const EdgeInsets.all(8),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      childAspectRatio: 0.6,
                      crossAxisSpacing: 8,
                      mainAxisSpacing: 8,
                    ),
                    itemCount: _movies.length,
                    itemBuilder: (context, index) =>
                        _buildMovieCard(_movies[index]),
                  ),
          ),
          // Layer suggestion
          if (_suggestions.isNotEmpty)
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: Container(
                height: MediaQuery.of(context).size.height * 0.25, // 1/4 layar
                color: Colors.white,
                child: ListView.builder(
                  itemCount: _suggestions.length,
                  itemBuilder: (context, index) {
                    final movie = _suggestions[index];
                    return ListTile(
                      leading: ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: CachedNetworkImage(
                          imageUrl: movie.coverUrl ?? '',
                          width: 50,
                          height: 75,
                          fit: BoxFit.cover,
                          placeholder: (context, url) =>
                              Container(color: Colors.grey[200]),
                          errorWidget: (context, url, error) =>
                              const Icon(Icons.error),
                        ),
                      ),
                      title: Text(
                        movie.judul,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      subtitle: Text(
                        '${movie.tahunRilis} • ${movie.type}',
                        style: TextStyle(color: Colors.grey[600], fontSize: 12),
                      ),
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) =>
                                MovieDetailScreen(movie: movie),
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
            ),
        ],
      ),
      floatingActionButton:
          _credentials!.role == "customer"
              ? const SizedBox.shrink()
              : Padding(
                padding: const EdgeInsets.only(bottom: 80),
                child: FloatingActionButton(
                  onPressed: () async {
                    final result = await Navigator.push<bool>(
                      context,
                      MaterialPageRoute(builder: (context) => AdminMenuPage()),
                    );

                    if (result == true) {
                      await _loadMovies();
                    }
                  },
                  tooltip: 'Tambah Anime Baru',
                  child: const Icon(Icons.add),
                ),
              ),
    );
  }

  Widget _buildMovieCard(Movie movie) {
    return InkWell(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => MovieDetailScreen(movie: movie),
          ),
        );
      },
      child: Card(
        elevation: 4,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: CachedNetworkImage(
                  imageUrl: movie.coverUrl ?? '',
                  fit: BoxFit.cover,
                  placeholder:
                      (context, url) => Container(color: Colors.grey[200]),
                  errorWidget: (context, url, error) => const Icon(Icons.error),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    movie.judul,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${movie.tahunRilis} • ${movie.type}',
                    style: TextStyle(color: Colors.grey[600], fontSize: 12),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Icon(Icons.star, color: Colors.amber, size: 16),
                      const SizedBox(width: 4),
                      Text(movie.rating ?? 'N/A', style: const TextStyle(fontSize: 12)),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class SearchResultScreen extends StatelessWidget {
  final List<Movie> searchResults;

  const SearchResultScreen({Key? key, required this.searchResults})
      : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Hasil Pencarian'),
      ),
      body: searchResults.isEmpty
          ? Center(
              child: Text(
                'Tidak ada hasil ditemukan',
                style: TextStyle(fontSize: 16, color: Colors.grey[600]),
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(8),
              itemCount: searchResults.length,
              itemBuilder: (context, index) {
                final movie = searchResults[index];
                return Card(
                  elevation: 4,
                  margin: const EdgeInsets.symmetric(vertical: 8),
                  child: ListTile(
                    leading: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: CachedNetworkImage(
                        imageUrl: movie.coverUrl ?? '',
                        width: 50,
                        height: 75,
                        fit: BoxFit.cover,
                        placeholder: (context, url) =>
                            Container(color: Colors.grey[200]),
                        errorWidget: (context, url, error) =>
                            const Icon(Icons.error),
                      ),
                    ),
                    title: Text(
                      movie.judul,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    subtitle: Text(
                      '${movie.tahunRilis} • ${movie.type}',
                      style: TextStyle(color: Colors.grey[600], fontSize: 12),
                    ),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) =>
                              MovieDetailScreen(movie: movie),
                        ),
                      );
                    },
                  ),
                );
              },
            ),
    );
  }
}
