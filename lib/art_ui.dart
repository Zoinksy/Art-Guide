import 'package:flutter/material.dart';

// Paletă de culori premium
class ArtColors {
  static const Color gold = Color(0xFFFFD700);
  static const Color black = Color(0xFF181818);
  static const Color white = Color(0xFFF5F5F5);
  static const Color glass = Color(0xAA222222);
  static const Color accent = Color(0xFFB2A4FF); // pastel mov
}

// Fonturi premium (asigură-te că ai fonturile în pubspec.yaml)
class ArtFonts {
  static const String title = 'PlayfairDisplay';
  static const String body = 'Merriweather';
}

// SnackBar artistic cu iconiță și colțuri rotunjite
class ArtSnackBar {
  static void show(BuildContext context, String message, {IconData? icon, Color? color}) {
    final snackBar = SnackBar(
      content: Row(
        children: [
          if (icon != null) ...[
            Icon(icon, color: color ?? ArtColors.gold, size: 28),
            const SizedBox(width: 12),
          ],
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                color: color ?? ArtColors.gold,
                fontWeight: FontWeight.bold,
                fontFamily: ArtFonts.body,
                fontSize: 16,
              ),
            ),
          ),
        ],
      ),
      backgroundColor: ArtColors.glass,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
      ),
      elevation: 10,
      margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      duration: const Duration(seconds: 2),
    );
    ScaffoldMessenger.of(context).showSnackBar(snackBar);
  }
}

// Card cu efect de glassmorphism
class ArtGlassCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? margin;
  final EdgeInsetsGeometry? padding;
  final double borderRadius;
  final double elevation;
  const ArtGlassCard({
    super.key,
    required this.child,
    this.margin,
    this.padding,
    this.borderRadius = 18,
    this.elevation = 8,
  });
  @override
  Widget build(BuildContext context) {
    return Container(
      margin: margin,
      child: Material(
        color: ArtColors.glass,
        elevation: elevation,
        borderRadius: BorderRadius.circular(borderRadius),
        child: Container(
          padding: padding ?? const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(borderRadius),
            border: Border.all(color: ArtColors.gold.withOpacity(0.3), width: 1.5),
            boxShadow: [
              BoxShadow(
                color: ArtColors.gold.withOpacity(0.08),
                blurRadius: 16,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: child,
        ),
      ),
    );
  }
}

// Inimioară animată pentru favorite
class AnimatedFavoriteIcon extends StatefulWidget {
  final bool isFavorite;
  final VoidCallback onTap;
  const AnimatedFavoriteIcon({super.key, required this.isFavorite, required this.onTap});
  @override
  State<AnimatedFavoriteIcon> createState() => _AnimatedFavoriteIconState();
}

class _AnimatedFavoriteIconState extends State<AnimatedFavoriteIcon> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnim;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350),
      lowerBound: 0.8,
      upperBound: 1.2,
    );
    _scaleAnim = CurvedAnimation(parent: _controller, curve: Curves.elasticOut);
  }

  @override
  void didUpdateWidget(covariant AnimatedFavoriteIcon oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.isFavorite != widget.isFavorite) {
      _controller.forward(from: 0.8);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.onTap,
      child: ScaleTransition(
        scale: _scaleAnim,
        child: Icon(
          widget.isFavorite ? Icons.favorite : Icons.favorite_border,
          color: widget.isFavorite ? ArtColors.gold : Colors.grey[400],
          size: 32,
        ),
      ),
    );
  }
}

// Background artistic cu gradient și overlay opțional
class ArtBackground extends StatelessWidget {
  final Widget child;
  final bool withOverlay;
  const ArtBackground({super.key, required this.child, this.withOverlay = true});

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                ArtColors.black,
                Color(0xFF3A2C5A), // mov pastel
                ArtColors.gold,
              ],
              stops: [0.0, 0.7, 1.0],
            ),
          ),
        ),
        if (withOverlay)
          Positioned.fill(
            child: IgnorePointer(
              child: Opacity(
                opacity: 0.08,
                child: Image.asset(
                  'assets/brush_strokes.png',
                  fit: BoxFit.cover,
                  alignment: Alignment.center,
                  errorBuilder: (context, error, stackTrace) => const SizedBox.shrink(),
                ),
              ),
            ),
          ),
        child,
      ],
    );
  }
} 