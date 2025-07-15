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

class _HistoryPageState extends State<HistoryPage> with TickerProviderStateMixin {
  // Get the current user to potentially filter results
  final currentUser = FirebaseAuth.instance.currentUser;
  final Set<String> _favorites = {}; // Will store artworkName|timestamp as unique key
  late AnimationController _controller;
  late TabController _tabController;
  Map<String, dynamic>? _selectedScan;

  @override
  void initState() {
    super.initState();
    _loadFavorites();
    _tabController = TabController(length: 2, vsync: this);
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    _tabController.dispose();
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
        ArtSnackBar.show(context, 'Added to favorites', icon: Icons.favorite, color: ArtColors.gold);
      } else {
        // Remove from favorites
        await querySnapshot.docs.first.reference.delete();
        setState(() {
          _favorites.remove(favKey);
        });
        ArtSnackBar.show(context, 'Removed from favorites', icon: Icons.favorite_border, color: Colors.redAccent);
      }
    } catch (e) {
      print('Error toggling favorite: $e');
      ArtSnackBar.show(
        context, 
        'Error: $e', 
        icon: Icons.error, 
        color: Colors.red
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
            title: const Text('Scan history', style: TextStyle(fontFamily: ArtFonts.title, fontWeight: FontWeight.bold, fontSize: 26)),
            backgroundColor: Colors.transparent,
            elevation: 0,
            foregroundColor: ArtColors.gold,
            bottom: TabBar(
              controller: _tabController,
              tabs: const [
                Tab(text: 'Pictures'),
                Tab(text: 'Details'),
              ],
            ),
          ),
          body: TabBarView(
            controller: _tabController,
            children: [
              _buildScanHistoryList(currentUser),
              _buildDetailsTab(),
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
        print('DEBUG: History - snapshot data: ${snapshot.data?.docs.length} documente');
        if (snapshot.hasData) {
          snapshot.data!.docs.forEach((doc) {
            print('DEBUG: History - document: ${doc.data()}');
          });
        }
        
        if (snapshot.hasError) {
          return Center(child: Text('An error occurred: ${snapshot.error}', style: const TextStyle(color: ArtColors.gold)));
        }

        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator(color: ArtColors.gold));
        }

        // If there are no documents, display a message
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const Center(
            child: Text('No scans in history.', style: TextStyle(color: ArtColors.gold, fontFamily: ArtFonts.body, fontSize: 18)),
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

            final artworkName = data['artworkName'] ?? 'Unknown';
            final confidence = (data['confidence'] as num?)?.toDouble() ?? 0.0;
            final timestamp = data['timestamp'] as Timestamp?;
            final imageUrl = data['imageUrl'] as String?;
            final favKey = timestamp != null ? (artworkName + '|' + timestamp.millisecondsSinceEpoch.toString()) : '';

            // Format the timestamp
            String formattedTime = 'Date unavailable';
            if (timestamp != null) {
              final dateTime = timestamp.toDate();
              formattedTime = '${dateTime.toLocal().toShortDateString()} ${dateTime.toLocal().toShortTimeString()}'; // You might need a date formatting package
            }

            // Wrap Card in Dismissible for swipe-to-delete
            return Dismissible(
              key: Key(docId),
              direction: DismissDirection.startToEnd, // swipe right
              background: Container(
                color: Colors.red,
                alignment: Alignment.centerLeft,
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: const Icon(Icons.delete, color: Colors.white, size: 32),
              ),
              confirmDismiss: (direction) async {
                return await showDialog(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: const Text('Confirm deletion'),
                    content: const Text('Are you sure you want to delete this scan?'),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.of(context).pop(false),
                        child: const Text('Cancel'),
                      ),
                      TextButton(
                        onPressed: () => Navigator.of(context).pop(true),
                        child: const Text('Delete', style: TextStyle(color: Colors.red)),
                      ),
                    ],
                  ),
                );
              },
              onDismissed: (direction) async {
                // Șterge scanarea din recognition_results
                await FirebaseFirestore.instance.collection('recognition_results').doc(docId).delete();
                // Șterge favoritele asociate
                if (currentUser != null && artworkName != null && timestamp != null) {
                  final favs = await FirebaseFirestore.instance
                      .collection('favorites')
                      .where('userId', isEqualTo: currentUser.uid)
                      .where('artworkName', isEqualTo: artworkName)
                      .where('timestamp', isEqualTo: timestamp)
                      .get();
                  for (final doc in favs.docs) {
                    await doc.reference.delete();
                  }
                }
                ArtSnackBar.show(
                  context, 
                  'Scan and associated favorites deleted!', 
                  icon: Icons.delete, 
                  color: Colors.red
                );
              },
              child: AnimatedBuilder(
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
                          'Accuracy: ${(confidence * 100).toStringAsFixed(1)}%',
                          style: const TextStyle(
                            color: Colors.white,
                            fontFamily: ArtFonts.body,
                            fontSize: 14,
                          ),
                        ),
                        Text(
                          'Date: $formattedTime',
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
                          isFavorite: _favorites.contains(favKey),
                          onTap: () {
                            if (timestamp == null) return;
                            (() async {
                              await _toggleFavorite(artworkName, imageUrl, confidence, timestamp);
                              if (_favorites.contains(favKey)) {
                                ArtSnackBar.show(context, 'Added to favorites', icon: Icons.favorite, color: ArtColors.gold);
                              } else {
                                ArtSnackBar.show(context, 'Removed from favorites', icon: Icons.favorite_border, color: Colors.redAccent);
                              }
                            })();
                          },
                        ),
                        IconButton(
                          icon: const Icon(Icons.info_outline, color: ArtColors.gold),
                          tooltip: 'See details',
                          onPressed: () {
                            _showDetailsDialog(context, data);
                          },
                        ),
                      ],
                    ),
                    // Add onTap to view details later if needed
                    onTap: () {
                      setState(() {
                        _selectedScan = data;
                      });
                      _tabController.animateTo(1);
                    },
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildDetailsTab() {
    if (_selectedScan == null) {
      return const Center(
        child: Text('Select a scan from pictures to see the details.',
            style: TextStyle(color: ArtColors.gold, fontFamily: ArtFonts.body, fontSize: 18)),
      );
    }
    final details = _selectedScan!['details'] as Map<String, dynamic>?;
    final artworkName = _selectedScan!['artworkName'] ?? 'Unknown';
    final confidence = (_selectedScan!['confidence'] as num?)?.toDouble() ?? 0.0;
    final timestamp = _selectedScan!['timestamp'] as Timestamp?;
    final imageUrl = _selectedScan!['imageUrl'] as String?;
    String formattedTime = 'Date unavailable';
    if (timestamp != null) {
      final dateTime = timestamp.toDate();
      formattedTime = '${dateTime.toLocal().toShortDateString()} ${dateTime.toLocal().toShortTimeString()}';
    }
    // Folosește detaliile din Firestore dacă există, altfel fallback la datele de bază
    final title = details?['title'] ?? artworkName;
    final artist = details?['artist'] ?? '';
    final year = details?['year'] ?? '';
    final style = details?['style'] ?? '';
    final location = details?['location'] ?? '';
    final description = details?['description'] ?? '';
    final artworkImageUrl = details?['imageUrl'] ?? imageUrl ?? '';
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (artworkImageUrl.isNotEmpty)
            Center(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.network(
                  artworkImageUrl,
                  height: 220,
                  width: double.infinity,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) =>
                      const Icon(Icons.broken_image, color: Colors.grey, size: 120),
                ),
              ),
            ),
          const SizedBox(height: 18),
          Text(
            title,
            style: const TextStyle(
              color: ArtColors.gold,
              fontFamily: ArtFonts.title,
              fontWeight: FontWeight.bold,
              fontSize: 26,
            ),
          ),
          const SizedBox(height: 10),
          if (artist.isNotEmpty)
            Text.rich(
              TextSpan(
                children: [
                  TextSpan(
                    text: 'Artist: ',
                    style: TextStyle(color: ArtColors.gold, fontWeight: FontWeight.bold, fontFamily: ArtFonts.title, fontSize: 18),
                  ),
                  TextSpan(
                    text: artist,
                    style: TextStyle(color: Colors.white, fontFamily: ArtFonts.body, fontSize: 18),
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
                    style: TextStyle(color: ArtColors.gold, fontWeight: FontWeight.bold, fontFamily: ArtFonts.title, fontSize: 16),
                  ),
                  TextSpan(
                    text: year,
                    style: TextStyle(color: Colors.white, fontFamily: ArtFonts.body, fontSize: 16),
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
                    style: TextStyle(color: ArtColors.gold, fontWeight: FontWeight.bold, fontFamily: ArtFonts.title, fontSize: 16),
                  ),
                  TextSpan(
                    text: style,
                    style: TextStyle(color: Colors.white, fontFamily: ArtFonts.body, fontSize: 16),
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
                    style: TextStyle(color: ArtColors.gold, fontWeight: FontWeight.bold, fontFamily: ArtFonts.title, fontSize: 16),
                  ),
                  TextSpan(
                    text: location,
                    style: TextStyle(color: Colors.white, fontFamily: ArtFonts.body, fontSize: 16),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 10),
          Text('Accuracy: ${(confidence * 100).toStringAsFixed(1)}%', style: const TextStyle(color: Colors.white70, fontFamily: ArtFonts.body, fontSize: 14)),
          Text('Scanned at: $formattedTime', style: const TextStyle(color: Colors.white70, fontFamily: ArtFonts.body, fontSize: 14)),
          const SizedBox(height: 18),
          if (description.isNotEmpty)
            Text('Description:', style: const TextStyle(color: ArtColors.gold, fontFamily: ArtFonts.title, fontSize: 20)),
          if (description.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 8.0),
              child: Text(description, style: const TextStyle(color: Colors.white, fontFamily: ArtFonts.body, fontSize: 16)),
            ),
        ],
      ),
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

  void _showDetailsDialog(BuildContext context, Map<String, dynamic> data) {
    final details = data['details'] as Map<String, dynamic>? ?? {};
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: Colors.black87,
          title: Text(
            details['title'] ?? data['artworkName'] ?? 'Detalii operă',
            style: const TextStyle(color: ArtColors.gold, fontFamily: ArtFonts.title),
          ),
          content: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if ((details['imageUrl'] ?? data['imageUrl']) != null && (details['imageUrl'] ?? data['imageUrl']).toString().isNotEmpty)
                  Center(
                    child: Image.network(
                      details['imageUrl'] ?? data['imageUrl'],
                      height: 180,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) => const Icon(Icons.broken_image, color: Colors.grey, size: 80),
                    ),
                  ),
                const SizedBox(height: 10),
                if (details['artist'] != null && details['artist'].toString().isNotEmpty)
                  Text.rich(
                    TextSpan(
                      children: [
                        TextSpan(
                          text: 'Artist: ',
                          style: TextStyle(color: ArtColors.gold, fontWeight: FontWeight.bold, fontFamily: ArtFonts.title),
                        ),
                        TextSpan(
                          text: details['artist'],
                          style: TextStyle(color: Colors.white, fontFamily: ArtFonts.body),
                        ),
                      ],
                    ),
                  ),
                if (details['year'] != null && details['year'].toString().isNotEmpty)
                  Text.rich(
                    TextSpan(
                      children: [
                        TextSpan(
                          text: 'Year: ',
                          style: TextStyle(color: ArtColors.gold, fontWeight: FontWeight.bold, fontFamily: ArtFonts.title),
                        ),
                        TextSpan(
                          text: details['year'],
                          style: TextStyle(color: Colors.white, fontFamily: ArtFonts.body),
                        ),
                      ],
                    ),
                  ),
                if (details['style'] != null && details['style'].toString().isNotEmpty)
                  Text.rich(
                    TextSpan(
                      children: [
                        TextSpan(
                          text: 'Style: ',
                          style: TextStyle(color: ArtColors.gold, fontWeight: FontWeight.bold, fontFamily: ArtFonts.title),
                        ),
                        TextSpan(
                          text: details['style'],
                          style: TextStyle(color: Colors.white, fontFamily: ArtFonts.body),
                        ),
                      ],
                    ),
                  ),
                if (details['location'] != null && details['location'].toString().isNotEmpty)
                  Text.rich(
                    TextSpan(
                      children: [
                        TextSpan(
                          text: 'Location: ',
                          style: TextStyle(color: ArtColors.gold, fontWeight: FontWeight.bold, fontFamily: ArtFonts.title),
                        ),
                        TextSpan(
                          text: details['location'],
                          style: TextStyle(color: Colors.white, fontFamily: ArtFonts.body),
                        ),
                      ],
                    ),
                  ),
                const SizedBox(height: 10),
                if (details['description'] != null && details['description'].toString().isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 8.0),
                    child: Text(details['description'], style: const TextStyle(color: Colors.white)),
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
        );
      },
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