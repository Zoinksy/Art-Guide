import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'models/museum.dart';
import 'services/places_service.dart';
import 'art_ui.dart';

class ExplorePage extends StatefulWidget {
  const ExplorePage({super.key});

  @override
  State<ExplorePage> createState() => _ExplorePageState();
}

class _ExplorePageState extends State<ExplorePage> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  Position? _currentPosition;
  String _errorMessage = '';
  bool _isLoading = true;
  List<Museum> _museums = [];
  final PlacesService _placesService = PlacesService();

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _controller.forward();
    _getCurrentLocation();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _getCurrentLocation() async {
    try {
      // Verifică permisiunile de localizare
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          setState(() {
            _errorMessage = 'Permisiunile de localizare au fost refuzate';
            _isLoading = false;
          });
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        setState(() {
          _errorMessage = 'Permisiunile de localizare sunt permanent refuzate';
          _isLoading = false;
        });
        return;
      }

      // Obține locația curentă
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      setState(() {
        _currentPosition = position;
      });

      await _findNearbyMuseums();

    } catch (e) {
      setState(() {
        _errorMessage = 'Eroare la obținerea locației: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _findNearbyMuseums() async {
    if (_currentPosition == null) return;

    try {
      final museums = await _placesService.getNearbyMuseums(
        _currentPosition!.latitude,
        _currentPosition!.longitude,
      );

      setState(() {
        _museums = museums;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Eroare la încărcarea muzeelor: $e';
        _isLoading = false;
      });
    }
  }

  Widget _buildMuseumCard(Museum museum) {
    return Card(
      color: Colors.black,
      elevation: 4,
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(
          color: Color(0xFFFFD700),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (museum.photoReference != null)
            ClipRRect(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
              child: Image.network(
                _placesService.getPhotoUrl(museum.photoReference!),
                height: 200,
                width: double.infinity,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) => Container(
                  height: 200,
                  color: Colors.grey[900],
                  child: const Icon(
                    Icons.image_not_supported,
                    color: Colors.grey,
                    size: 48,
                  ),
                ),
              ),
            ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  museum.name,
                  style: const TextStyle(
                    color: Color(0xFFFFD700),
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                if (museum.address != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    museum.address!,
                    style: const TextStyle(color: Colors.grey),
                  ),
                ],
                const SizedBox(height: 8),
                Row(
                  children: [
                    if (museum.rating != null) ...[
                      const Icon(
                        Icons.star,
                        color: Color(0xFFFFD700),
                        size: 20,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        museum.rating!.toStringAsFixed(1),
                        style: const TextStyle(
                          color: Color(0xFFFFD700),
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      if (museum.userRatingsTotal != null) ...[
                        const SizedBox(width: 4),
                        Text(
                          '(${museum.userRatingsTotal})',
                          style: const TextStyle(color: Colors.grey),
                        ),
                      ],
                    ],
                    const Spacer(),
                    if (museum.distance != null)
                      Text(
                        '${museum.distance!.toStringAsFixed(1)} km',
                        style: const TextStyle(color: Colors.grey),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ArtBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          title: const Text('Explorează', style: TextStyle(fontFamily: ArtFonts.title, fontWeight: FontWeight.bold, fontSize: 26)),
          backgroundColor: Colors.transparent,
          elevation: 0,
          foregroundColor: ArtColors.gold,
        ),
        body: _isLoading
            ? const Center(
                child: CircularProgressIndicator(
                  color: ArtColors.gold,
                ),
              )
            : _errorMessage.isNotEmpty
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(
                            Icons.error_outline,
                            color: Colors.red,
                            size: 48,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            _errorMessage,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: Colors.red,
                              fontSize: 16,
                            ),
                          ),
                          const SizedBox(height: 16),
                          ElevatedButton(
                            onPressed: _getCurrentLocation,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: ArtColors.gold,
                              foregroundColor: Colors.black,
                            ),
                            child: const Text('Reîncearcă'),
                          ),
                        ],
                      ),
                    ),
                  )
                : _currentPosition == null
                    ? const Center(
                        child: Text(
                          'Nu s-a putut obține locația',
                          style: TextStyle(color: Colors.grey),
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
                        itemCount: _museums.length,
                        itemBuilder: (context, index) {
                          final museum = _museums[index];
                          return AnimatedBuilder(
                            animation: _controller,
                            builder: (context, child) {
                              final delay = index * 0.06;
                              final animValue = (_controller.value - delay).clamp(0.0, 1.0);
                              return Opacity(
                                opacity: animValue,
                                child: Transform.translate(
                                  offset: Offset(0, 40 * (1 - animValue)),
                                  child: child,
                                ),
                              );
                            },
                            child: _buildMuseumCard(museum),
                          );
                        },
                      ),
      ),
    );
  }
} 