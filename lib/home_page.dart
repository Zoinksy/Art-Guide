import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final user = FirebaseAuth.instance.currentUser;
  static const Color gold = Color(0xFFFFD700);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        title: const Text(
          'AR Tour Guide',
          style: TextStyle(
            color: gold,
            fontFamily: 'Merriweather',
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout, color: gold),
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
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Bun venit, ${user?.displayName ?? 'Explorator'}!',
                style: const TextStyle(
                  color: gold,
                  fontSize: 24,
                  fontFamily: 'Merriweather',
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 24),
              Expanded(
                child: GridView.count(
                  crossAxisCount: 2,
                  mainAxisSpacing: 16,
                  crossAxisSpacing: 16,
                  children: [
                    _buildFeatureCard(
                      icon: Icons.camera_alt,
                      title: 'Scanare AR',
                      description: 'Scanează opere de artă pentru informații',
                      onTap: () {
                        // TODO: Implement AR scanning
                      },
                    ),
                    _buildFeatureCard(
                      icon: Icons.explore,
                      title: 'Explorează',
                      description: 'Descoperă opere de artă din jurul tău',
                      onTap: () {
                        // TODO: Implement exploration
                      },
                    ),
                    _buildFeatureCard(
                      icon: Icons.history,
                      title: 'Istoric',
                      description: 'Vezi operele scanate anterior',
                      onTap: () {
                        // TODO: Implement history
                      },
                    ),
                    _buildFeatureCard(
                      icon: Icons.favorite,
                      title: 'Favorite',
                      description: 'Operele tale favorite',
                      onTap: () {
                        // TODO: Implement favorites
                      },
                    ),
                  ],
                ),
              ),
            ],
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
    return Card(
      color: Colors.black,
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: gold, width: 1),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: gold, size: 48),
              const SizedBox(height: 12),
              Text(
                title,
                style: const TextStyle(
                  color: gold,
                  fontSize: 18,
                  fontFamily: 'Merriweather',
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                description,
                style: TextStyle(
                  color: Colors.grey[400],
                  fontSize: 14,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
} 