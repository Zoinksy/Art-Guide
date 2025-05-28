import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:artourguide_new/home_page.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'art_ui.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  runApp(const ArtTourGuideApp());
}

class ArtTourGuideApp extends StatelessWidget {
  const ArtTourGuideApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'AR Tour Guide',
      theme: ThemeData(
        fontFamily: ArtFonts.body,
        scaffoldBackgroundColor: Colors.transparent,
        colorScheme: ColorScheme.fromSwatch().copyWith(
          primary: ArtColors.gold,
          secondary: ArtColors.accent,
          background: ArtColors.black,
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.transparent,
          elevation: 0,
          iconTheme: IconThemeData(color: ArtColors.gold),
          titleTextStyle: TextStyle(
            color: ArtColors.gold,
            fontFamily: ArtFonts.title,
            fontWeight: FontWeight.bold,
            fontSize: 26,
          ),
        ),
      ),
      home: ArtBackground(
        child: WelcomePage(),
      ),
    );
  }
}

class WelcomePage extends StatefulWidget {
  const WelcomePage({super.key});

  @override
  State<WelcomePage> createState() => _WelcomePageState();
}

class _WelcomePageState extends State<WelcomePage> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _loginEmailController = TextEditingController();
  final _loginPasswordController = TextEditingController();
  final _signupNameController = TextEditingController();
  final _signupEmailController = TextEditingController();
  final _signupPasswordController = TextEditingController();
  final _signupConfirmController = TextEditingController();
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _loginEmailController.dispose();
    _loginPasswordController.dispose();
    _signupNameController.dispose();
    _signupEmailController.dispose();
    _signupPasswordController.dispose();
    _signupConfirmController.dispose();
    super.dispose();
  }

  Future<void> _signUp() async {
    final name = _signupNameController.text.trim();
    final email = _signupEmailController.text.trim();
    final password = _signupPasswordController.text;
    final confirm = _signupConfirmController.text;
    if (name.isEmpty || email.isEmpty || password.isEmpty || confirm.isEmpty) {
      _showError('Completează toate câmpurile!');
      return;
    }
    if (password != confirm) {
      _showError('Parolele nu coincid!');
      return;
    }
    setState(() => _isLoading = true);
    try {
      final credential = await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      await credential.user?.updateDisplayName(name);
      final uid = credential.user?.uid;
      if (uid != null) {
        await FirebaseFirestore.instance.collection('users').doc(uid).set({
          'name': name,
          'email': email,
          'createdAt': FieldValue.serverTimestamp(),
        });
      }
      _showError('Cont creat cu succes!');
      _tabController.animateTo(0);
      _signupNameController.clear();
      _signupEmailController.clear();
      _signupPasswordController.clear();
      _signupConfirmController.clear();
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const HomePage()),
      );
    } on FirebaseAuthException catch (e) {
      _showError(e.message ?? 'Eroare la înregistrare');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _login() async {
    final email = _loginEmailController.text.trim();
    final password = _loginPasswordController.text;
    if (email.isEmpty || password.isEmpty) {
      _showError('Completează toate câmpurile!');
      return;
    }
    setState(() => _isLoading = true);
    try {
      await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      _showError('Autentificare reușită!');
      _loginEmailController.clear();
      _loginPasswordController.clear();
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const HomePage()),
      );
    } on FirebaseAuthException catch (e) {
      _showError(e.message ?? 'Eroare la autentificare');
    } catch (e) {
      _showError('Eroare neașteptată: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ArtBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: Center(
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 28.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Logo animat
                  TweenAnimationBuilder<double>(
                    tween: Tween(begin: 0.7, end: 1.0),
                    duration: const Duration(milliseconds: 900),
                    curve: Curves.elasticOut,
                    builder: (context, value, child) => Transform.scale(
                      scale: value,
                      child: child,
                    ),
                    child: Icon(Icons.museum, size: 72, color: ArtColors.gold.withOpacity(0.95), shadows: [
                      Shadow(color: ArtColors.gold.withOpacity(0.4), blurRadius: 24),
                    ]),
                  ),
                  const SizedBox(height: 32),
                  // Titlu artistic
                  Text(
                    'AR Tour Guide',
                    style: TextStyle(
                      color: ArtColors.gold,
                      fontSize: 38,
                      fontWeight: FontWeight.bold,
                      fontFamily: ArtFonts.title,
                      shadows: [
                        Shadow(color: ArtColors.gold.withOpacity(0.3), blurRadius: 12),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),
                  // Citat artistic
                  Text(
                    'Descoperă arta cu tehnologie și eleganță.',
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.white.withOpacity(0.85),
                      fontFamily: ArtFonts.body,
                      fontStyle: FontStyle.italic,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 32),
                  // Card login/signup cu glassmorphism
                  ArtGlassCard(
                    padding: const EdgeInsets.all(0),
                    child: Column(
                      children: [
                        TabBar(
                          controller: _tabController,
                          indicatorColor: ArtColors.gold,
                          labelColor: ArtColors.gold,
                          unselectedLabelColor: Colors.white70,
                          tabs: const [
                            Tab(text: 'Login'),
                            Tab(text: 'Sign Up'),
                          ],
                        ),
                        Container(
                          height: 270,
                          padding: const EdgeInsets.all(16),
                          child: _isLoading
                              ? const Center(child: CircularProgressIndicator(color: ArtColors.gold))
                              : TabBarView(
                                  controller: _tabController,
                                  children: [
                                    // LOGIN TAB
                                    Column(
                                      children: [
                                        _buildTextField(_loginEmailController, 'Email'),
                                        const SizedBox(height: 12),
                                        _buildTextField(_loginPasswordController, 'Password', obscure: true),
                                        const SizedBox(height: 24),
                                        _buildGoldButton('Log In', onPressed: _login),
                                      ],
                                    ),
                                    // SIGN UP TAB
                                    SingleChildScrollView(
                                      child: Column(
                                        children: [
                                          _buildTextField(_signupNameController, 'Name'),
                                          const SizedBox(height: 12),
                                          _buildTextField(_signupEmailController, 'Email'),
                                          const SizedBox(height: 12),
                                          _buildTextField(_signupPasswordController, 'Password', obscure: true),
                                          const SizedBox(height: 12),
                                          _buildTextField(_signupConfirmController, 'Confirm Password', obscure: true),
                                          const SizedBox(height: 24),
                                          _buildGoldButton('Sign Up', onPressed: _signUp),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTextField(TextEditingController controller, String hint, {bool obscure = false}) {
    return TextField(
      controller: controller,
      obscureText: obscure,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: Colors.white54),
        filled: true,
        fillColor: Colors.black.withOpacity(0.5),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: ArtColors.gold.withOpacity(0.5)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: ArtColors.gold.withOpacity(0.2)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: ArtColors.gold),
        ),
      ),
    );
  }

  Widget _buildGoldButton(String text, {required VoidCallback onPressed}) {
    return SizedBox(
      width: double.infinity,
      height: 48,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: ArtColors.gold,
          foregroundColor: Colors.black,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          elevation: 2,
        ),
        child: Text(
          text,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, fontFamily: 'Merriweather'),
        ),
      ),
    );
  }
}
