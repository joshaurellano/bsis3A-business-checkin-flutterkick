import 'package:flutter/material.dart';
import 'login_screen.dart';
import 'signup_screen.dart';

class LandingScreen extends StatefulWidget {
  const LandingScreen({super.key});

  @override
  State<LandingScreen> createState() => _LandingScreenState();
}

class _LandingScreenState extends State<LandingScreen>
    with TickerProviderStateMixin {
  late final AnimationController _fadeController;
  late final AnimationController _slideController;

  late final Animation<double> _fadeAnim;
  late final Animation<Offset> _badgeSlide;
  late final Animation<Offset> _headlineSlide;
  late final Animation<Offset> _descSlide;
  late final Animation<Offset> _buttonsSlide;
  late final Animation<Offset> _featuresSlide;

  // Colors matching the project
  static const Color _primary = Color(0xFF1565C0);
  static const Color _primaryDark = Color(0xFF0D47A1);
  static const Color _primaryLight = Color(0xFFE3F0FF);
  static const Color _cream = Color(0xFFF5F8FF);
  static const Color _ink = Color(0xFF0D1B2A);
  static const Color _muted = Color(0xFF6B7A99);

  @override
  void initState() {
    super.initState();

    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );

    _slideController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    );

    _fadeAnim = CurvedAnimation(parent: _fadeController, curve: Curves.easeOut);

    _badgeSlide = Tween<Offset>(
      begin: const Offset(0, -0.4),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _slideController,
      curve: const Interval(0.0, 0.5, curve: Curves.easeOut),
    ));

    _headlineSlide = Tween<Offset>(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _slideController,
      curve: const Interval(0.1, 0.6, curve: Curves.easeOut),
    ));

    _descSlide = Tween<Offset>(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _slideController,
      curve: const Interval(0.2, 0.7, curve: Curves.easeOut),
    ));

    _buttonsSlide = Tween<Offset>(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _slideController,
      curve: const Interval(0.35, 0.85, curve: Curves.easeOut),
    ));

    _featuresSlide = Tween<Offset>(
      begin: const Offset(0, 0.4),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _slideController,
      curve: const Interval(0.5, 1.0, curve: Curves.easeOut),
    ));

    _fadeController.forward();
    _slideController.forward();
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _slideController.dispose();
    super.dispose();
  }

  void _navigateToLogin() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const LoginPage()),
    );
  }

  void _navigateToSignUp() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const SignUpPage()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _cream,
      body: FadeTransition(
        opacity: _fadeAnim,
        child: SafeArea(
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildHeroSection(),
                _buildFeaturesSection(),
                _buildSocialProof(),
                const SizedBox(height: 32),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ─── HERO ────────────────────────────────────────────────────────────────

  Widget _buildHeroSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Blue hero background with grid ──────────────────────────────
        Stack(
          children: [
            ClipPath(
              clipper: _HeroClipper(),
              child: Container(
                height: 310,
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [_primaryDark, _primary],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
              ),
            ),
            ClipPath(
              clipper: _HeroClipper(),
              child: SizedBox(
                height: 310,
                child: CustomPaint(painter: _GridPainter()),
              ),
            ),
            // Nav + badge + headline + desc live inside the blue area
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 28, 24, 40),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Top nav row
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _buildLogoMark(),
                      _buildNavLoginButton(),
                    ],
                  ),
                  const SizedBox(height: 28),
                  SlideTransition(
                    position: _badgeSlide,
                    child: _buildBadge(),
                  ),
                  const SizedBox(height: 14),
                  SlideTransition(
                    position: _headlineSlide,
                    child: _buildHeadline(),
                  ),
                  const SizedBox(height: 12),
                  SlideTransition(
                    position: _descSlide,
                    child: _buildDescription(),
                  ),
                ],
              ),
            ),
          ],
        ),

        // ── App preview card — inline, no overlap ───────────────────────
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
          child: SlideTransition(
            position: _descSlide,
            child: _buildAppPreviewCard(),
          ),
        ),

        // ── CTA buttons ─────────────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
          child: SlideTransition(
            position: _buttonsSlide,
            child: _buildCTAButtons(),
          ),
        ),

        // Terms
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 10, 24, 0),
          child: Center(
            child: Text(
              'By continuing, you agree to our Terms & Privacy Policy.',
              style: TextStyle(
                fontSize: 11,
                color: _muted.withValues(alpha:0.75),
              ),
              textAlign: TextAlign.center,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildLogoMark() {
    return Row(
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha:0.18),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: Colors.white.withValues(alpha:0.3),
              width: 1,
            ),
          ),
          child: const Icon(Icons.local_pharmacy_outlined,
              size: 20, color: Colors.white),
        ),
        const SizedBox(width: 10),
        const Text(
          'TruServe',
          style: TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.bold,
            letterSpacing: 0.3,
          ),
        ),
      ],
    );
  }

  Widget _buildNavLoginButton() {
    return GestureDetector(
      onTap: _navigateToLogin,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha:0.15),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: Colors.white.withValues(alpha:0.35),
            width: 1,
          ),
        ),
        child: const Text(
          'Log in',
          style: TextStyle(
            color: Colors.white,
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }

  Widget _buildBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha:0.18),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: Colors.white.withValues(alpha:0.3),
          width: 0.8,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 7,
            height: 7,
            decoration: const BoxDecoration(
              color: Color(0xFF4CD97B),
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 7),
          const Text(
            'Now available on iOS & Android',
            style: TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeadline() {
    return RichText(
      text: const TextSpan(
        style: TextStyle(
          color: Colors.white,
          fontSize: 34,
          fontWeight: FontWeight.bold,
          height: 1.15,
          letterSpacing: -0.8,
        ),
        children: [
          TextSpan(text: 'Pharma\n'),
          TextSpan(text: 'Management,\n'),
          TextSpan(
            text: 'Simplified.',
            style: TextStyle(
              color: Color(0xFFAAD4FF),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDescription() {
    return Text(
      'Track inventory, manage returns, and streamline\nyour pharmacy operations — all in one place.',
      style: TextStyle(
        color: Colors.white.withValues(alpha:0.78),
        fontSize: 14,
        height: 1.6,
        fontWeight: FontWeight.w300,
      ),
    );
  }

  Widget _buildAppPreviewCard() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: _primaryDark.withValues(alpha:0.15),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Today\'s Overview',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: _ink,
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFE8F5E9),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Text(
                  'Live',
                  style: TextStyle(
                    fontSize: 11,
                    color: Color(0xFF2E7D32),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              _buildStatChip('284', 'In Stock', Icons.inventory_2_outlined,
                  const Color(0xFFE3F0FF), _primary),
              const SizedBox(width: 10),
              _buildStatChip('12', 'Low Stock', Icons.warning_amber_outlined,
                  const Color(0xFFFFF8E1), const Color(0xFFF9A825)),
              const SizedBox(width: 10),
              _buildStatChip('97%', 'Accuracy', Icons.check_circle_outline,
                  const Color(0xFFE8F5E9), const Color(0xFF2E7D32)),
            ],
          ),
          const SizedBox(height: 14),
          // Mini bar chart
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              _buildBar(0.45, false),
              const SizedBox(width: 5),
              _buildBar(0.65, false),
              const SizedBox(width: 5),
              _buildBar(0.50, false),
              const SizedBox(width: 5),
              _buildBar(0.85, true),
              const SizedBox(width: 5),
              _buildBar(0.70, false),
              const SizedBox(width: 5),
              _buildBar(0.92, true),
              const SizedBox(width: 5),
              _buildBar(0.60, false),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Dispensed items this week',
            style: TextStyle(
              fontSize: 11,
              color: _muted.withValues(alpha:0.7),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatChip(String value, String label, IconData icon,
      Color bg, Color iconColor) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 16, color: iconColor),
            const SizedBox(height: 6),
            Text(
              value,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: iconColor,
              ),
            ),
            Text(
              label,
              style: const TextStyle(
                fontSize: 10,
                color: _muted,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBar(double heightFactor, bool highlight) {
    return Expanded(
      child: Container(
        height: 44 * heightFactor,
        decoration: BoxDecoration(
          color: highlight ? _primary : _primaryLight,
          borderRadius: BorderRadius.circular(4),
        ),
      ),
    );
  }

  Widget _buildCTAButtons() {
    return Column(
      children: [
        // Primary: Sign Up
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: _navigateToSignUp,
            style: ElevatedButton.styleFrom(
              backgroundColor: _primary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(30),
              ),
              elevation: 0,
            ),
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  'Get started free',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.3,
                  ),
                ),
                SizedBox(width: 8),
                Icon(Icons.arrow_forward_rounded, size: 18),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        // Secondary: Log In
        SizedBox(
          width: double.infinity,
          child: OutlinedButton(
            onPressed: _navigateToLogin,
            style: OutlinedButton.styleFrom(
              foregroundColor: _primary,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(30),
              ),
              side: const BorderSide(color: _primary, width: 1.5),
            ),
            child: const Text(
              'Log in to your account',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                letterSpacing: 0.3,
              ),
            ),
          ),
        ),
      ],
    );
  }

  // ─── FEATURES ─────────────────────────────────────────────────────────────

  Widget _buildFeaturesSection() {
    return SlideTransition(
      position: _featuresSlide,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 36, 24, 0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'WHY TEAMS CHOOSE TRUSERVE',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                letterSpacing: 1.2,
                color: _muted.withValues(alpha:0.8),
              ),
            ),
            const SizedBox(height: 20),
            _buildFeatureTile(
              icon: Icons.sync_rounded,
              iconBg: const Color(0xFFE3F0FF),
              iconColor: _primary,
              title: 'Real-time inventory sync',
              desc:
                  'Changes reflect instantly across all devices and staff members — no manual refresh needed.',
            ),
            const SizedBox(height: 14),
            _buildFeatureTile(
              icon: Icons.assignment_return_outlined,
              iconBg: const Color(0xFFFFF3E0),
              iconColor: const Color(0xFFE65100),
              title: 'Streamlined returns',
              desc:
                  'Process product returns and track their status end-to-end with full audit trails.',
            ),
            const SizedBox(height: 14),
            _buildFeatureTile(
              icon: Icons.bar_chart_rounded,
              iconBg: const Color(0xFFE8F5E9),
              iconColor: const Color(0xFF2E7D32),
              title: 'Analytics dashboard',
              desc:
                  'Visual reports on dispensing trends, stock levels, and team performance at a glance.',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFeatureTile({
    required IconData icon,
    required Color iconBg,
    required Color iconColor,
    required String title,
    required String desc,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade100, width: 1),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: iconBg,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, size: 22, color: iconColor),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: _ink,
                    letterSpacing: -0.2,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  desc,
                  style: const TextStyle(
                    fontSize: 13,
                    color: _muted,
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ─── SOCIAL PROOF ────────────────────────────────────────────────────────

  Widget _buildSocialProof() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 28, 24, 0),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [_primaryDark, _primary],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          children: [
            // Avatar stack
            SizedBox(
              width: 88,
              height: 36,
              child: Stack(
                children: [
                  _buildAvatar('JK', const Color(0xFF4CAF50), 0),
                  _buildAvatar('ML', const Color(0xFF9C27B0), 24),
                  _buildAvatar('TR', const Color(0xFFFF9800), 48),
                  _buildAvatar('SA', const Color(0xFF2196F3), 72),
                ],
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '4,200+ pharmacy teams',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    'already trust TruServe',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha:0.7),
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAvatar(String initials, Color color, double left) {
    return Positioned(
      left: left,
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          border: const Border.fromBorderSide(
            BorderSide(color: Colors.white, width: 2),
          ),
        ),
        child: Center(
          child: Text(
            initials,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 11,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ),
    );
  }
}

// ─── CUSTOM CLIPPERS & PAINTERS ──────────────────────────────────────────────

class _HeroClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    final path = Path();
    path.lineTo(0, size.height - 40);
    path.quadraticBezierTo(
      size.width / 2,
      size.height + 20,
      size.width,
      size.height - 40,
    );
    path.lineTo(size.width, 0);
    path.close();
    return path;
  }

  @override
  bool shouldReclip(_HeroClipper oldClipper) => false;
}

class _GridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withValues(alpha:0.04)
      ..strokeWidth = 1;

    const spacing = 36.0;
    for (double x = 0; x < size.width; x += spacing) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    for (double y = 0; y < size.height; y += spacing) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(_GridPainter oldDelegate) => false;
}