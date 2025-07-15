import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'art_ui.dart';

class FavoritesPage extends StatefulWidget {
  const FavoritesPage({super.key});

  @override
  State<FavoritesPage> createState() => _FavoritesPageState();
}

class _FavoritesPageState extends State<FavoritesPage> with SingleTickerProviderStateMixin {
  final currentUser = FirebaseAuth.instance.currentUser;
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ArtBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          title: const Text('Favorite', style: TextStyle(fontFamily: ArtFonts.title, fontWeight: FontWeight.bold, fontSize: 26)),
          backgroundColor: Colors.transparent,
          elevation: 0,
          foregroundColor: ArtColors.gold,
        ),
        body: StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection('favorites')
              .where('userId', isEqualTo: currentUser?.uid)
              .orderBy('timestamp', descending: true)
              .snapshots(),
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return Center(child: Text('A apărut o eroare: ${snapshot.error}', style: const TextStyle(color: ArtColors.gold)));
            }
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator(color: ArtColors.gold));
            }
            if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
              return const Center(
                child: Text(
                  'No picture added to favourites yet.',
                  style: TextStyle(color: ArtColors.gold, fontFamily: ArtFonts.body, fontSize: 18),
                ),
              );
            }
            return ListView.builder(
              padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
              itemCount: snapshot.data!.docs.length,
              itemBuilder: (context, index) {
                final doc = snapshot.data!.docs[index];
                final data = doc.data() as Map<String, dynamic>;
                final docId = doc.id;
                final artworkName = data['artworkName'] as String? ?? 'Unknown';
                final imageUrl = data['imageUrl'] as String?;
                final timestamp = data['timestamp'] as Timestamp?;
                final confidence = (data['confidence'] as num?)?.toDouble() ?? 0.0;
                final favKey = timestamp != null ? (artworkName + '|' + timestamp.millisecondsSinceEpoch.toString()) : '';
                String formattedTime = 'Date unavailable';
                if (timestamp != null) {
                  final dateTime = timestamp.toDate();
                  formattedTime = '${dateTime.toLocal().toShortDateString()} ${dateTime.toLocal().toShortTimeString()}';
                }
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
                  child: ArtGlassCard(
                    margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
                    child: ListTile(
                      contentPadding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                      leading: imageUrl != null && imageUrl.isNotEmpty
                          ? ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: SizedBox(
                                width: 60,
                                height: 60,
                                child: GestureDetector(
                                  onTap: () => _showEnlargedImage(context, imageUrl),
                                  child: Image.network(
                                    imageUrl,
                                    fit: BoxFit.cover,
                                    errorBuilder: (context, error, stackTrace) =>
                                        const Icon(Icons.broken_image, color: Colors.grey),
                                  ),
                                ),
                              ),
                            )
                          : const Icon(Icons.image_not_supported, size: 60, color: Colors.grey),
                      title: Flexible(
                        child: Text(
                          artworkName,
                          style: const TextStyle(
                            color: ArtColors.gold,
                            fontFamily: ArtFonts.title,
                            fontWeight: FontWeight.bold,
                            fontSize: 18,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Confidence: ${(confidence * 100).toStringAsFixed(1)}%',
                            style: const TextStyle(
                              color: Colors.white,
                              fontFamily: ArtFonts.body,
                              fontSize: 14,
                            ),
                          ),
                          Text(
                            'Added at: $formattedTime',
                            style: const TextStyle(
                              color: Colors.white70,
                              fontFamily: ArtFonts.body,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          AnimatedFavoriteIcon(
                            isFavorite: true,
                            onTap: () async {
                              final confirm = await showDialog<bool>(
                                context: context,
                                builder: (context) => AlertDialog(
                                  backgroundColor: ArtColors.black,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                                  title: const Text('Confirm deletion', style: TextStyle(color: ArtColors.gold, fontFamily: ArtFonts.title)),
                                  content: const Text('Are you sure you want to remove this artwork from favorites?', style: TextStyle(color: Colors.white)),
                                  actions: [
                                    TextButton(
                                      onPressed: () => Navigator.of(context).pop(false),
                                      child: const Text('Cancel', style: TextStyle(color: ArtColors.accent)),
                                    ),
                                    TextButton(
                                      onPressed: () => Navigator.of(context).pop(true),
                                      child: const Text('Delete', style: TextStyle(color: ArtColors.gold)),
                                    ),
                                  ],
                                ),
                              );
                              if (confirm == true) {
                                try {
                                  await FirebaseFirestore.instance
                                      .collection('favorites')
                                      .doc(docId)
                                      .delete();
                                  ArtSnackBar.show(context, 'Artwork removed from favorites', icon: Icons.favorite_border, color: Colors.redAccent);
                                } catch (e) {
                                  ArtSnackBar.show(context, 'Error deleting: $e', icon: Icons.error, color: Colors.redAccent);
                                }
                              }
                            },
                          ),
                          IconButton(
                            icon: const Icon(Icons.info_outline, color: ArtColors.gold),
                            tooltip: 'See details',
                            onPressed: () async {
                              Map<String, dynamic>? detailsData;
                              if (timestamp != null) {
                                final results = await FirebaseFirestore.instance
                                    .collection('recognition_results')
                                    .where('userId', isEqualTo: currentUser?.uid)
                                    .where('artworkName', isEqualTo: artworkName)
                                    .where('timestamp', isEqualTo: timestamp)
                                    .get();
                                if (results.docs.isNotEmpty) {
                                  detailsData = results.docs.first.data();
                                }
                              }
                              _showDetailsDialog(context, data, detailsData);
                            },
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }

  void _showEnlargedImage(BuildContext context, String imageUrl) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(10),
        child: GestureDetector(
          onTap: () => Navigator.of(context).pop(),
          child: Image.network(
            imageUrl,
            fit: BoxFit.contain,
            errorBuilder: (context, error, stackTrace) =>
                const Icon(Icons.broken_image, size: 50, color: Colors.white),
          ),
        ),
      ),
    );
  }

  void _showDetailsDialog(BuildContext context, Map<String, dynamic> favData, Map<String, dynamic>? scanData) {
    final details = scanData != null ? (scanData['details'] as Map<String, dynamic>? ?? {}) : {};
    final artworkName = favData['artworkName'] ?? 'Unknown';
    final confidence = (favData['confidence'] as num?)?.toDouble() ?? 0.0;
    final timestamp = favData['timestamp'] as Timestamp?;
    final imageUrl = favData['imageUrl'] as String?;
    String formattedTime = 'Date unavailable';
    if (timestamp != null) {
      final dateTime = timestamp.toDate();
      formattedTime = '${dateTime.toLocal().toShortDateString()} ${dateTime.toLocal().toShortTimeString()}';
    }
    final title = details['title'] ?? artworkName;
    final artist = details['artist'] ?? '';
    final year = details['year'] ?? '';
    final style = details['style'] ?? '';
    final location = details['location'] ?? '';
    final description = details['description'] ?? '';
    final artworkImageUrl = details['imageUrl'] ?? imageUrl ?? '';
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.black87,
        title: Text(
          title,
          style: const TextStyle(color: ArtColors.gold, fontFamily: ArtFonts.title),
        ),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (artworkImageUrl.isNotEmpty)
                Center(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.network(
                      artworkImageUrl,
                      height: 180,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) => const Icon(Icons.broken_image, color: Colors.grey, size: 80),
                    ),
                  ),
                ),
              const SizedBox(height: 10),
              if (artist.isNotEmpty)
                Text.rich(
                  TextSpan(
                    children: [
                      TextSpan(
                        text: 'Artist: ',
                        style: TextStyle(color: ArtColors.gold, fontWeight: FontWeight.bold, fontFamily: ArtFonts.title),
                      ),
                      TextSpan(
                        text: artist,
                        style: TextStyle(color: Colors.white, fontFamily: ArtFonts.body),
                      ),
                    ],
                  ),
                ),
              if (year.isNotEmpty)
                Text.rich(
                  TextSpan(
                    children: [
                      TextSpan(
                        text: 'Year: ',
                        style: TextStyle(color: ArtColors.gold, fontWeight: FontWeight.bold, fontFamily: ArtFonts.title),
                      ),
                      TextSpan(
                        text: year,
                        style: TextStyle(color: Colors.white, fontFamily: ArtFonts.body),
                      ),
                    ],
                  ),
                ),
              if (style.isNotEmpty)
                Text.rich(
                  TextSpan(
                    children: [
                      TextSpan(
                        text: 'Style: ',
                        style: TextStyle(color: ArtColors.gold, fontWeight: FontWeight.bold, fontFamily: ArtFonts.title),
                      ),
                      TextSpan(
                        text: style,
                        style: TextStyle(color: Colors.white, fontFamily: ArtFonts.body),
                      ),
                    ],
                  ),
                ),
              if (location.isNotEmpty)
                Text.rich(
                  TextSpan(
                    children: [
                      TextSpan(
                        text: 'Location: ',
                        style: TextStyle(color: ArtColors.gold, fontWeight: FontWeight.bold, fontFamily: ArtFonts.title),
                      ),
                      TextSpan(
                        text: location,
                        style: TextStyle(color: Colors.white, fontFamily: ArtFonts.body),
                      ),
                    ],
                  ),
                ),
              const SizedBox(height: 10),
              Text('Confidence: ${(confidence * 100).toStringAsFixed(1)}%', style: const TextStyle(color: Colors.white70, fontFamily: ArtFonts.body, fontSize: 14)),
              Text('Added at: $formattedTime', style: const TextStyle(color: Colors.white70, fontFamily: ArtFonts.body, fontSize: 14)),
              const SizedBox(height: 10),
              if (description.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 8.0),
                  child: Text(description, style: const TextStyle(color: Colors.white)),
                ),
            ],
          ),
        ),
        actions: [
          TextButton(
            child: const Text('Close', style: TextStyle(color: ArtColors.gold)),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ],
      ),
    );
  }
}

extension on DateTime {
  String toShortDateString() {
    return '${this.year}-${this.month.toString().padLeft(2, '0')}-${this.day.toString().padLeft(2, '0')}';
  }
  String toShortTimeString() {
    return '${this.hour.toString().padLeft(2, '0')}:${this.minute.toString().padLeft(2, '0')}';
  }
}