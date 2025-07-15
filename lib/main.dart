import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'home_page.dart';
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
      title: 'Art Guide',
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
      initialRoute: '/',
      routes: {
        '/': (context) => ArtBackground(child: WelcomePage()),
        '/home': (context) => const HomePage(),
      },
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
      _showError('Complete all fields!');
      return;
    }
    if (password != confirm) {
      _showError('Passwords do not match!');
      return;
    }
    setState(() => _isLoading = true);
    try {
      print('DEBUG: Starting sign up process for email: $email');
      final credential = await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      print('DEBUG: User created successfully, UID: ${credential.user?.uid}');
      
      await credential.user?.updateDisplayName(name);
      final uid = credential.user?.uid;
      if (uid != null) {
        await FirebaseFirestore.instance.collection('users').doc(uid).set({
          'name': name,
          'email': email,
          'createdAt': FieldValue.serverTimestamp(),
        });
        print('DEBUG: User data saved to Firestore');
      }
      
      print('DEBUG: Showing success message');
      _showError('Account created successfully!');
      
      print('DEBUG: Clearing form fields');
      _signupNameController.clear();
      _signupEmailController.clear();
      _signupPasswordController.clear();
      _signupConfirmController.clear();
      
      print('DEBUG: Checking if widget is mounted');
      if (mounted) {
        print('DEBUG: Widget is mounted, navigating to HomePage');
        Navigator.pushReplacementNamed(context, '/home');
        print('DEBUG: Navigation completed');
      } else {
        print('DEBUG: Widget is not mounted, cannot navigate');
      }
    } on FirebaseAuthException catch (e) {
      print('DEBUG: FirebaseAuthException: ${e.message}');
      print('DEBUG: Error code: ${e.code}');
      
      String errorMessage = 'Error at sign up';
      if (e.code == 'operation-not-allowed') {
        errorMessage = 'Email/Password authentication is not enabled. Please contact the administrator.';
      } else if (e.code == 'weak-password') {
        errorMessage = 'Password is too weak. Please use a stronger password.';
      } else if (e.code == 'email-already-in-use') {
        errorMessage = 'An account with this email already exists.';
      } else if (e.code == 'invalid-email') {
        errorMessage = 'Invalid email address.';
      } else {
        errorMessage = e.message ?? 'Error at sign up';
      }
      
      _showError(errorMessage);
    } catch (e) {
      print('DEBUG: Unexpected error: $e');
      _showError('Unexpected error: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _login() async {
    final email = _loginEmailController.text.trim();
    final password = _loginPasswordController.text;
    if (email.isEmpty || password.isEmpty) {
      _showError('Please fill in all fields!');
      return;
    }
    setState(() => _isLoading = true);
    try {
      print('DEBUG: Starting login process for email: $email');
      await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      print('DEBUG: Login successful');
      
      print('DEBUG: Showing success message');
      _showError('Login successful!');
      
      print('DEBUG: Clearing form fields');
      _loginEmailController.clear();
      _loginPasswordController.clear();
      
      print('DEBUG: Checking if widget is mounted');
      if (mounted) {
        print('DEBUG: Widget is mounted, navigating to HomePage');
        Navigator.pushReplacementNamed(context, '/home');
        print('DEBUG: Navigation completed');
      } else {
        print('DEBUG: Widget is not mounted, cannot navigate');
      }
    } on FirebaseAuthException catch (e) {
      print('DEBUG: FirebaseAuthException: ${e.message}');
      _showError(e.message ?? 'Login error');
    } catch (e) {
      print('DEBUG: Unexpected error: $e');
      _showError('Unexpected error: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _showError(String msg) {
    // Show different icons and colors for success vs error messages
    if (msg.contains('successful')) {
      ArtSnackBar.show(
        context, 
        msg, 
        icon: Icons.check_circle, 
        color: ArtColors.gold
      );
    } else {
      ArtSnackBar.show(
        context, 
        msg, 
        icon: Icons.error, 
        color: Colors.red
      );
    }
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

                  Text(
                    'Art Guide',
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

                  Text(
                    'Discover the world of art in an unigue way!',
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.white.withOpacity(0.85),
                      fontFamily: ArtFonts.body,
                      fontStyle: FontStyle.italic,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 32),

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
