import 'package:flutter/material.dart';
import 'login_screen.dart';
import 'signup_screen.dart';

class LandingScreen extends StatefulWidget {
  const LandingScreen({super.key});

  @override
  State<LandingScreen> createState() => _LandingScreenState();
}

class _LandingScreenState extends State<LandingScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _fade;
  late final Animation<Offset> _slide;

  static const Color _bg = Color(0xFF1565C0);
  static const Color _white = Colors.white;
  static const Color _whiteMuted = Color(0xAAFFFFFF);
  static const Color _whiteSubtle = Color(0x66FFFFFF);

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _fade = CurvedAnimation(parent: _controller, curve: Curves.easeOut);
    _slide = Tween<Offset>(
      begin: const Offset(0, 0.06),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      body: SafeArea(
        child: FadeTransition(
          opacity: _fade,
          child: SlideTransition(
            position: _slide,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 28),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 48),
                  _buildLogo(),
                  const Spacer(),
                  _buildHeadline(),
                  const SizedBox(height: 16),
                  _buildDescription(),
                  const Spacer(),
                  _buildButtons(),
                  const SizedBox(height: 16),
                  _buildTerms(),
                  const SizedBox(height: 32),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLogo() {
    return Row(
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: _whiteSubtle,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: _whiteSubtle, width: 1),
          ),
          child: const Icon(Icons.local_pharmacy_outlined,
              size: 18, color: _white),
        ),
        const SizedBox(width: 10),
        const Text(
          'TRUSERVE',
          style: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w900,
            color: _white,
            letterSpacing: -0.3,
          ),
        ),
      ],
    );
  }

  Widget _buildHeadline() {
    return const Text(
      'Pharmacy\nmanagement,\nsimplified.',
      style: TextStyle(
        fontSize: 40,
        fontWeight: FontWeight.w700,
        color: _white,
        height: 1.1,
        letterSpacing: -1.2,
      ),
    );
  }

  Widget _buildDescription() {
    return const Text(
      'Track inventory, manage returns, and streamline operations — all in one place.',
      style: TextStyle(
        fontSize: 15,
        color: _whiteMuted,
        height: 1.6,
        fontWeight: FontWeight.w400,
      ),
    );
  }

  Widget _buildButtons() {
    return Column(
      children: [
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const SignUpPage()),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: _white,
              foregroundColor: Color(0xFF1565C0),
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              elevation: 0,
            ),
            child: const Text(
              'Get started',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.1,
              ),
            ),
          ),
        ),
        const SizedBox(height: 10),
        SizedBox(
          width: double.infinity,
          child: TextButton(
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const LoginPage()),
            ),
            style: TextButton.styleFrom(
              foregroundColor: _white,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text(
              'Log in',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTerms() {
    return Center(
      child: Text(
        'By continuing, you agree to our Terms & Privacy Policy.',
        style: TextStyle(
          fontSize: 11,
          color: _whiteSubtle,
        ),
        textAlign: TextAlign.center,
      ),
    );
  }
}