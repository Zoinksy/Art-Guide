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

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> with SingleTickerProviderStateMixin {
  final user = FirebaseAuth.instance.currentUser;
  final ArtRecognition _artRecognition = ArtRecognition();
  late AnimationController _controller;

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
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);
    if (pickedFile != null) {
      showDialog(
        context: context,
        builder: (context) => const AlertDialog(
          title: Text('Funcționalitate în dezvoltare'),
          content: Text('Recunoașterea din galerie va fi implementată în curând.'),
        ),
      );
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
                'AR Tour Guide',
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
                  Navigator.pushReplacementNamed(context, '/');
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
                  'Bun venit, ${user?.displayName ?? 'Explorator'}!',
                  style: const TextStyle(
                    color: ArtColors.gold,
                    fontSize: 24,
                    fontFamily: ArtFonts.title,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 18),
                Text(
                  'Descoperă arta într-un mod nou, interactiv și elegant.',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.85),
                    fontSize: 16,
                    fontFamily: ArtFonts.body,
                  ),
                ),
                const SizedBox(height: 28),
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
                            title: 'Scanare AR',
                            description: 'Scanează opere de artă pentru informații',
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
                            title: 'Explorează',
                            description: 'Descoperă opere de artă din jurul tău',
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
                            title: 'Istoric',
                            description: 'Vezi operele scanate anterior',
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
                            description: 'Operele tale favorite',
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
                const SizedBox(height: 10),
                Center(
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: ArtColors.gold,
                      foregroundColor: ArtColors.black,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                      elevation: 6,
                    ),
                    icon: const Icon(Icons.image, size: 22),
                    label: const Text('Testează modelul cu o imagine din galerie', style: TextStyle(fontFamily: ArtFonts.body, fontWeight: FontWeight.bold)),
                    onPressed: _testModelWithImage,
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
        padding: const EdgeInsets.all(10.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: ArtColors.gold, size: 48),
            const SizedBox(height: 12),
            Text(
              title,
              style: const TextStyle(
                color: ArtColors.gold,
                fontSize: 18,
                fontFamily: ArtFonts.title,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              description,
              style: TextStyle(
                color: Colors.white.withOpacity(0.85),
                fontSize: 14,
                fontFamily: ArtFonts.body,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
} 