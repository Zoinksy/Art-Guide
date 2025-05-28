import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart'; // Import FirebaseAuth for potentially filtering by user
import 'package:firebase_storage/firebase_storage.dart'; // Import Firebase Storage for deletion
import 'art_ui.dart';

class HistoryPage extends StatefulWidget {
  const HistoryPage({super.key});

  @override
  State<HistoryPage> createState() => _HistoryPageState();
}

class _HistoryPageState extends State<HistoryPage> with SingleTickerProviderStateMixin {
  // Get the current user to potentially filter results
  final currentUser = FirebaseAuth.instance.currentUser;
  final Set<String> _favorites = {}; // Will store artworkName|timestamp as unique key
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _loadFavorites();
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

  Future<void> _loadFavorites() async {
    if (currentUser == null) return;
    
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('favorites')
          .where('userId', isEqualTo: currentUser!.uid)
          .get();
      
      setState(() {
        _favorites.clear();
        _favorites.addAll(snapshot.docs.map((doc) {
          final name = doc['artworkName'] as String? ?? '';
          final ts = doc['timestamp'];
          String tsString = '';
          if (ts is Timestamp) {
            tsString = ts.millisecondsSinceEpoch.toString();
          } else if (ts is DateTime) {
            tsString = ts.millisecondsSinceEpoch.toString();
          }
          return name + '|' + tsString;
        }));
      });
    } catch (e) {
      print('Error loading favorites: $e');
    }
  }

  Future<void> _toggleFavorite(String artworkName, String? imageUrl, double confidence, Timestamp timestamp) async {
    if (currentUser == null) return;
    final tsString = timestamp.millisecondsSinceEpoch.toString();
    final favKey = artworkName + '|' + tsString;
    try {
      final favoritesRef = FirebaseFirestore.instance.collection('favorites');
      final querySnapshot = await favoritesRef
          .where('userId', isEqualTo: currentUser!.uid)
          .where('artworkName', isEqualTo: artworkName)
          .where('timestamp', isEqualTo: timestamp)
          .get();

      if (querySnapshot.docs.isEmpty) {
        // Add to favorites
        await favoritesRef.add({
          'userId': currentUser!.uid,
          'artworkName': artworkName,
          'imageUrl': imageUrl,
          'confidence': confidence,
          'timestamp': timestamp,
        });
        setState(() {
          _favorites.add(favKey);
        });
        ArtSnackBar.show(context, 'Adăugat la favorite', icon: Icons.favorite, color: ArtColors.gold);
      } else {
        // Remove from favorites
        await querySnapshot.docs.first.reference.delete();
        setState(() {
          _favorites.remove(favKey);
        });
        ArtSnackBar.show(context, 'Eliminat din favorite', icon: Icons.favorite_border, color: Colors.redAccent);
      }
    } catch (e) {
      print('Error toggling favorite: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Eroare: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return ArtBackground(
      child: DefaultTabController(
        length: 2,
        child: Scaffold(
          backgroundColor: Colors.transparent,
          appBar: AppBar(
            title: const Text('Istoric Scanări', style: TextStyle(fontFamily: ArtFonts.title, fontWeight: FontWeight.bold, fontSize: 26)),
            backgroundColor: Colors.transparent,
            elevation: 0,
            foregroundColor: ArtColors.gold,
            bottom: const TabBar(
              tabs: [
                Tab(text: 'Poze'),
                Tab(text: 'Detalii'),
              ],
            ),
          ),
          body: TabBarView(
            children: [
              _buildScanHistoryList(currentUser),
              const Center(child: Text('Detalii scanare (în curând)', style: TextStyle(color: ArtColors.gold, fontFamily: ArtFonts.body, fontSize: 18))),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildScanHistoryList(User? currentUser) {
    return StreamBuilder<QuerySnapshot>(
      // Fetch recognition results from Firestore
      // Order by timestamp in descending order (most recent first)
      // You might want to filter results based on the current user (currentUser?.uid)
      stream: FirebaseFirestore.instance
          .collection('recognition_results')
          .orderBy('timestamp', descending: true)
          .where('userId', isEqualTo: currentUser?.uid) // Filter by current user ID
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(child: Text('A apărut o eroare: ${snapshot.error}', style: const TextStyle(color: ArtColors.gold)));
        }

        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator(color: ArtColors.gold));
        }

        // If there are no documents, display a message
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const Center(
            child: Text('Nu există scanări în istoric.', style: TextStyle(color: ArtColors.gold, fontFamily: ArtFonts.body, fontSize: 18)),
          );
        }

        // Display the list of scanned items
        return ListView.builder(
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
          itemCount: snapshot.data!.docs.length,
          itemBuilder: (context, index) {
            final doc = snapshot.data!.docs[index];
            final data = doc.data() as Map<String, dynamic>;
            final docId = doc.id; // Get document ID for deletion

            final artworkName = data['artworkName'] ?? 'Necunoscut';
            final confidence = (data['confidence'] as num?)?.toDouble() ?? 0.0;
            final timestamp = data['timestamp'] as Timestamp?;
            final imageUrl = data['imageUrl'] as String?;
            final favKey = timestamp != null ? (artworkName + '|' + timestamp.millisecondsSinceEpoch.toString()) : '';

            // Format the timestamp
            String formattedTime = 'Data indisponibilă';
            if (timestamp != null) {
              final dateTime = timestamp.toDate();
              formattedTime = '${dateTime.toLocal().toShortDateString()} ${dateTime.toLocal().toShortTimeString()}'; // You might need a date formatting package
            }

            // Wrap Card in Dismissible for swipe-to-delete
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
                              onTap: () => _showEnlargedImage(context, imageUrl!),
                              child: Image.network(
                                imageUrl,
                                fit: BoxFit.cover,
                                errorBuilder: (context, error, stackTrace) =>
                                    const Icon(Icons.broken_image, color: Colors.grey),
                              ),
                            ),
                          ),
                        )
                      : const Icon(Icons.image_not_supported, size: 60, color: Colors.grey), // Placeholder if no image URL with grey icon and increased size
                  title: Text(
                    artworkName,
                    style: const TextStyle(
                      color: ArtColors.gold,
                      fontFamily: ArtFonts.title,
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                    ),
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Încredere: ${(confidence * 100).toStringAsFixed(1)}%',
                        style: const TextStyle(
                          color: Colors.white,
                          fontFamily: ArtFonts.body,
                          fontSize: 14,
                        ),
                      ),
                      Text(
                        'Data: $formattedTime',
                        style: const TextStyle(
                          color: Colors.white70,
                          fontFamily: ArtFonts.body,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                  trailing: AnimatedFavoriteIcon(
                    isFavorite: _favorites.contains(favKey),
                    onTap: () {
                      if (timestamp == null) return;
                      (() async {
                        await _toggleFavorite(artworkName, imageUrl, confidence, timestamp);
                        if (_favorites.contains(favKey)) {
                          ArtSnackBar.show(context, 'Adăugat la favorite', icon: Icons.favorite, color: ArtColors.gold);
                        } else {
                          ArtSnackBar.show(context, 'Eliminat din favorite', icon: Icons.favorite_border, color: Colors.redAccent);
                        }
                      })();
                    },
                  ),
                  // Add onTap to view details later if needed
                  onTap: () {
                    // TODO: Implement navigation to a detail view or show dialog, passing docId or data
                     print('Tapped on item with ID: $docId');
                     // Example: Navigator.push(...);
                  },
                ),
              ),
            );
          },
        );
      },
    );
  }

  // Function to show enlarged image
  void _showEnlargedImage(BuildContext context, String imageUrl) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent, // Transparent background
        insetPadding: EdgeInsets.all(10), // Padding from edges
        child: GestureDetector(
          onTap: () => Navigator.of(context).pop(), // Dismiss dialog on tap
          child: Image.network(
            imageUrl,
            fit: BoxFit.contain, // Contain the image within the dialog
            errorBuilder: (context, error, stackTrace) => const Icon(Icons.broken_image, size: 50, color: Colors.white), // Error icon
          ),
        ),
      ),
    );
  }
}

// Simple Extension for Date Formatting (requires intl package for more advanced formatting)
// For now, using basic toLocal().toString()
// You might want to add the intl package and use DateFormat
// extension on DateTime { 
//   String toShortDateString() { 
//     return this.toString().split(' ')[0]; // Basic date part
//   }
//   String toShortTimeString() {
//      return this.toString().split(' ')[1].split('.')[0]; // Basic time part
//   }
// }

// Temporary basic date formatting extension if intl is not added yet
extension on DateTime {
  String toShortDateString() {
    return '${this.year}-${this.month.toString().padLeft(2, '0')}-${this.day.toString().padLeft(2, '0')}';
  }
  String toShortTimeString() {
    return '${this.hour.toString().padLeft(2, '0')}:${this.minute.toString().padLeft(2, '0')}';
  }
} 