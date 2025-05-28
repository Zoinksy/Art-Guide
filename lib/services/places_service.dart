import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/museum.dart';
import 'dart:math' as math;

class PlacesService {
  static const String _baseUrl = 'https://maps.googleapis.com/maps/api/place';
  static const String _apiKey = 'AIzaSyBD1yxElIraPiO2VigDPh0nsSVVMWjOyaU';
  static const int _radius = 50000; // 50km radius

  Future<List<Museum>> getNearbyMuseums(double latitude, double longitude) async {
    final url = Uri.parse(
      '$_baseUrl/nearbysearch/json?'
      'location=$latitude,$longitude'
      '&radius=$_radius'
      '&keyword=museum'
      '&key=$_apiKey'
    );

    try {
      final response = await http.get(url);
      print(json.decode(response.body));

      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final results = data['results'] as List<dynamic>;
        
        return results.map((json) {
          final museum = Museum.fromJson(json);
          // Calculate distance from user
          museum.distance = _calculateDistance(
            latitude,
            longitude,
            museum.latitude ?? 0,
            museum.longitude ?? 0,
          );
          return museum;
        }).toList()
          ..sort((a, b) => (a.distance ?? 0).compareTo(b.distance ?? 0));
      } else {
        throw Exception('Failed to load museums: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Failed to load museums: $e');
    }
  }

  String getPhotoUrl(String photoReference) {
    return '$_baseUrl/photo?'
        'maxwidth=400'
        '&photo_reference=$photoReference'
        '&key=$_apiKey';
  }

  double _calculateDistance(
  double lat1,
  double lon1,
  double lat2,
  double lon2,
) {
  const p = 0.017453292519943295; // pi / 180
  final a = 0.5 -
      math.cos((lat2 - lat1) * p) / 2 +
      math.cos(lat1 * p) *
          math.cos(lat2 * p) *
          (1 - math.cos((lon2 - lon1) * p)) /
          2;
  return (12742 * math.asin(math.sqrt(a))).toDouble();
}

} 