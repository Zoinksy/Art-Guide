import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'ar_scanner_page.dart';
import 'history_page.dart';
import 'explore_page.dart';
import 'favorites_page.dart';
import 'art_ui.dart';
import 'package:image_picker/image_picker.dart';
import 'ml/art_recognition.dart';
import 'dart:io';
import 'dart:typed_data';
import 'package:image/image.dart' as img;
import 'package:firebase_storage/firebase_storage.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'services/artwork_service.dart';
import 'package:path_provider/path_provider.dart';


class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> with SingleTickerProviderStateMixin {
  final user = FirebaseAuth.instance.currentUser;
  final ArtRecognition _artRecognition = ArtRecognition();
  final ArtworkService _artworkService = ArtworkService();
  late AnimationController _controller;
  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _artRecognition.loadModel();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _controller.forward();
  }

  @override
  void dispose() {
    _artRecognition.dispose();
    _controller.dispose();
    super.dispose();
  }

  Future<void> _testModelWithImage() async {
    try {
      final XFile? image = await _picker.pickImage(source: ImageSource.gallery);
      if (image == null) return;

      // Procesăm imaginea din galerie
      final result = await _artRecognition.recognizeImageFromGallery(File(image.path));
      
      if (result.isEmpty) {
        print('No results from gallery image');
        return;
      }

      final results = result['results'] as Map<String, double>;
      final imageBytes = result['imageBytes'] as Uint8List;

      // Găsim cea mai bună potrivire
      String? bestMatch;
      double? bestConfidence;
      double confidenceThreshold = 0.3;

      results.forEach((label, confidence) {
        if (confidence > confidenceThreshold && (bestConfidence == null || confidence > bestConfidence!)) {
          bestMatch = label;
          bestConfidence = confidence;
        }
      });

      if (bestMatch != null && bestConfidence != null) {
        // Obține detalii Wikipedia
        final wikiDetails = await _artworkService.getWikipediaDetails(bestMatch!);
        print('DEBUG: Upload - bestMatch: $bestMatch, confidence: $bestConfidence');
        
        // Salvăm rezultatul în Firebase
        await _saveRecognitionResult(bestMatch!, bestConfidence!, imageBytes, wikiDetails: wikiDetails);
        
        print('DEBUG: Upload - salvare completă');
        
        // Poți afișa un mesaj de succes sau să folosești direct datele salvate
        if (mounted) {
          ArtSnackBar.show(
            context, 
            'Artwork recognized and saved!', 
            icon: Icons.check_circle, 
            color: ArtColors.gold
          );
        }
      } else {
        if (mounted) {
          ArtSnackBar.show(
            context, 
            'Could not recognize artwork', 
            icon: Icons.error, 
            color: Colors.red
          );
        }
      }
    } catch (e) {
      print('Error testing model: $e');
      if (mounted) {
        ArtSnackBar.show(
          context, 
          'Error: $e', 
          icon: Icons.error, 
          color: Colors.red
        );
      }
    }
  }

  // Adăugăm funcția de salvare în Firebase
  Future<void> _saveRecognitionResult(String artworkName, double confidence, Uint8List? imageBytes, {Map<String, dynamic>? wikiDetails}) async {
    try {
      print('DEBUG: Începe salvare - artworkName: $artworkName, imageBytes: ${imageBytes != null ? "valid" : "null"}');
      
      File? imageFile;
      if (imageBytes != null) {
        final tempDir = await getTemporaryDirectory();
        imageFile = await File('${tempDir.path}/$artworkName.jpg').writeAsBytes(imageBytes);
        print('DEBUG: Fișier creat: ${imageFile.path}');
      }
      
      if (imageFile != null) {
        print('DEBUG: Apelează saveArtworkDetails');
        await _artworkService.saveArtworkDetails(
          artworkName: artworkName,
          confidence: confidence,
          imageFile: imageFile,
          modelDetails: wikiDetails,
        );
        print('DEBUG: saveArtworkDetails complet');
      } else {
        print('DEBUG: Fallback - salvare fără imagine');
        // fallback dacă nu ai imagine, poți salva doar datele minime
        await FirebaseFirestore.instance.collection('recognition_results').add({
          'artworkName': artworkName,
          'confidence': confidence,
          'timestamp': FieldValue.serverTimestamp(),
          'imageUrl': null,
          'userId': FirebaseAuth.instance.currentUser?.uid,
        });
        print('Recognition result (fără imagine) salvat.');
      }
    } catch (e) {
      print('ERROR: Error saving recognition result: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return ArtBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          title: Row(
            children: [
              const Icon(Icons.museum, color: ArtColors.gold, size: 36),
              const SizedBox(width: 12),
              const Text(
                'Art Tour',
                style: TextStyle(
                  color: ArtColors.gold,
                  fontFamily: ArtFonts.title,
                  fontWeight: FontWeight.bold,
                  fontSize: 28,
                  letterSpacing: 1.2,
                ),
              ),
            ],
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.logout, color: ArtColors.gold),
              onPressed: () async {
                await FirebaseAuth.instance.signOut();
                if (mounted) {
                  // Pop all routes and go back to the root (WelcomePage)
                  Navigator.of(context).pushNamedAndRemoveUntil('/', (route) => false);
                }
              },
            ),
          ],
        ),
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(18.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Welcome, ${user?.displayName ?? 'Explorer'}!',
                  style: const TextStyle(
                    color: ArtColors.gold,
                    fontSize: 24,
                    fontFamily: ArtFonts.title,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'Discover art in a new, interactive and interesting way!',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.85),
                    fontSize: 16,
                    fontFamily: ArtFonts.body,
                  ),
                ),
                const SizedBox(height: 28),
                Expanded(
                  child: Column(
                    children: [
                Expanded(
                  child: GridView.count(
                    crossAxisCount: 2,
                    mainAxisSpacing: 18,
                    crossAxisSpacing: 18,
                    children: List.generate(4, (i) {
                      final cards = [
                        ArtGlassCard(
                          child: _buildFeatureCard(
                            icon: Icons.camera_alt,
                            title: 'Scan',
                            description: 'Scan a picture to discover art',
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(builder: (context) => const ARScannerPage()),
                              );
                            },
                          ),
                        ),
                        ArtGlassCard(
                          child: _buildFeatureCard(
                            icon: Icons.explore,
                            title: 'Explore',
                            description: 'Discover the art all around you!',
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(builder: (context) => const ExplorePage()),
                              );
                            },
                          ),
                        ),
                        ArtGlassCard(
                          child: _buildFeatureCard(
                            icon: Icons.history,
                            title: 'History',
                            description: 'See the pieces of art scanned previously',
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(builder: (context) => const HistoryPage()),
                              );
                            },
                          ),
                        ),
                        ArtGlassCard(
                          child: _buildFeatureCard(
                            icon: Icons.favorite,
                            title: 'Favorite',
                            description: 'Favorite pieces of art',
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(builder: (context) => const FavoritesPage()),
                              );
                            },
                          ),
                        ),
                      ];
                      return AnimatedBuilder(
                        animation: _controller,
                        builder: (context, child) {
                          final delay = i * 0.08;
                          final animValue = (_controller.value - delay).clamp(0.0, 1.0);
                          return Opacity(
                            opacity: animValue,
                            child: Transform.translate(
                              offset: Offset(0, 40 * (1 - animValue)),
                              child: child,
                            ),
                          );
                        },
                        child: cards[i],
                      );
                    }),
                  ),
                ),
                      const SizedBox(height: 16),
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: ArtColors.gold,
                          foregroundColor: ArtColors.black,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                          elevation: 6,
                        ),
                        icon: const Icon(Icons.image, size: 22),
                        label: const Text('Upload from gallery', style: TextStyle(fontFamily: ArtFonts.body, fontWeight: FontWeight.bold)),
                        onPressed: _testModelWithImage,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFeatureCard({
    required IconData icon,
    required String title,
    required String description,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: ArtColors.gold, size: 40),
            const SizedBox(height: 8),
            Text(
              title,
              style: const TextStyle(
                color: ArtColors.gold,
                fontSize: 16,
                fontFamily: ArtFonts.title,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 6),
            Expanded(
              child: Text(
              description,
              style: TextStyle(
                color: Colors.white.withOpacity(0.85),
                  fontSize: 12,
                fontFamily: ArtFonts.body,
              ),
              textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
} 