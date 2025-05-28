class Museum {
  final String id;
  final String name;
  final String? address;
  final double? rating;
  final int? userRatingsTotal;
  final double? latitude;
  final double? longitude;
  final String? photoReference;
  
  // Nu e final → poate fi setat după inițializare
  double? distance;

  Museum({
    required this.id,
    required this.name,
    this.address,
    this.rating,
    this.userRatingsTotal,
    this.latitude,
    this.longitude,
    this.photoReference,
    this.distance,
  });

  factory Museum.fromJson(Map<String, dynamic> json) {
    final geometry = json['geometry'] as Map<String, dynamic>?;
    final location = geometry?['location'] as Map<String, dynamic>?;
    final photos = json['photos'] as List<dynamic>?;

    return Museum(
      id: json['place_id'] as String,
      name: json['name'] as String,
      address: json['vicinity'] as String?,
      rating: (json['rating'] as num?)?.toDouble(),
      userRatingsTotal: json['user_ratings_total'] as int?,
      latitude: location?['lat'] as double?,
      longitude: location?['lng'] as double?,
      photoReference: photos?.isNotEmpty == true
          ? photos![0]['photo_reference'] as String
          : null,
      distance: null, // Poate fi setată ulterior în PlacesService
    );
  }
}
