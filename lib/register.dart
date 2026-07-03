import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:math' as math;
import 'forgot_password.dart';

class RegisterPage extends StatefulWidget {
  const RegisterPage({Key? key}) : super(key: key);

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage>
    with TickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _usernameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  // FocusNodes untuk navigasi Enter
  final _nameFocus = FocusNode();
  final _usernameFocus = FocusNode();
  final _emailFocus = FocusNode();
  final _passwordFocus = FocusNode();
  final _confirmPasswordFocus = FocusNode();

  bool _isPasswordVisible = false;
  bool _isConfirmPasswordVisible = false;
  bool _isLoading = false;

  late AnimationController _cardController;
  late AnimationController _floatController;
  late AnimationController _shimmerController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _scaleAnimation;
  late Animation<double> _floatAnimation;
  late Animation<double> _rotateXAnimation;

  // ✅ DIPERBAIKI: URL hosting yang benar
  static const String _baseUrl = 'https://inventorimobilkom.my.id';
  final String apiUrl = '$_baseUrl/register.php';

  // Warna Mobilkom
  static const Color mobilkomBlue = Color(0xFF1D4861);
  static const Color mobilkomRed = Color(0xFFE74C3C);
  static const Color softWhite = Color(0xFFFAFBFC);
  static const Color cardWhite = Color(0xFFFFFFFF);
  static const Color softGrey = Color(0xFFF0F2F5);
  static const Color borderGrey = Color(0xFFE8ECF0);

  @override
  void initState() {
    super.initState();

    _cardController = AnimationController(
      duration: const Duration(milliseconds: 900),
      vsync: this,
    );

    _floatController = AnimationController(
      duration: const Duration(seconds: 3),
      vsync: this,
    )..repeat(reverse: true);

    _shimmerController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    )..repeat();

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _cardController, curve: Curves.easeOut),
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.08),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _cardController,
      curve: Curves.easeOutCubic,
    ));

    _scaleAnimation = Tween<double>(begin: 0.92, end: 1.0).animate(
      CurvedAnimation(parent: _cardController, curve: Curves.easeOutBack),
    );

    _floatAnimation = Tween<double>(begin: -6.0, end: 6.0).animate(
      CurvedAnimation(parent: _floatController, curve: Curves.easeInOut),
    );

    _rotateXAnimation = Tween<double>(begin: -0.02, end: 0.02).animate(
      CurvedAnimation(parent: _floatController, curve: Curves.easeInOut),
    );

    _cardController.forward();
  }

  @override
  void dispose() {
    _cardController.dispose();
    _floatController.dispose();
    _shimmerController.dispose();
    _nameController.dispose();
    _usernameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _nameFocus.dispose();
    _usernameFocus.dispose();
    _emailFocus.dispose();
    _passwordFocus.dispose();
    _confirmPasswordFocus.dispose();
    super.dispose();
  }

  Future<void> _register() async {
    if (!_formKey.currentState!.validate()) return;

    if (_passwordController.text != _confirmPasswordController.text) {
      _showMessage('Password tidak cocok', isError: true);
      return;
    }

    setState(() => _isLoading = true);

    try {
      final response = await http.post(
        Uri.parse(apiUrl),
        headers: {'Content-Type': 'application/x-www-form-urlencoded'}, // ✅ header penting
        body: {
          'full_name': _nameController.text.trim(),
          'username': _usernameController.text.trim(),
          'email': _emailController.text.trim(),
          'password': _passwordController.text,
          'role': 'staff',
        },
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        // ✅ Bersihkan karakter BOM/spasi sebelum JSON
        final rawBody = response.body.trim();
        final jsonStart = rawBody.indexOf('{');
        final cleanBody = jsonStart >= 0 ? rawBody.substring(jsonStart) : rawBody;

        final data = json.decode(cleanBody);
        if (data['status'] == 'success') {
          _showMessage(data['message'], isError: false);
          await Future.delayed(const Duration(seconds: 2));
          if (mounted) Navigator.pop(context);
        } else {
          _showMessage(data['message'] ?? 'Registrasi gagal', isError: true);
        }
      } else {
        _showMessage('Server error: ${response.statusCode}', isError: true);
      }
    } on Exception catch (e) {
      _showMessage('Tidak dapat terhubung ke server: $e', isError: true);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showMessage(String message, {required bool isError}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              isError ? Icons.error_outline : Icons.check_circle_outline,
              color: Colors.white,
              size: 20,
            ),
            const SizedBox(width: 10),
            Expanded(child: Text(message, style: const TextStyle(fontSize: 14))),
          ],
        ),
        backgroundColor: isError ? mobilkomRed : Colors.green.shade600,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String hint,
    required String label,
    required IconData icon,
    required String? Function(String?) validator,
    required FocusNode focusNode,
    FocusNode? nextFocus,
    TextInputType? keyboardType,
    bool obscureText = false,
    Widget? suffixIcon,
    bool isLast = false,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: mobilkomBlue,
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 6),
        TextFormField(
          controller: controller,
          focusNode: focusNode,
          obscureText: obscureText,
          keyboardType: keyboardType,
          textInputAction:
              isLast ? TextInputAction.done : TextInputAction.next,
          onFieldSubmitted: (_) {
            if (isLast) {
              _register();
            } else if (nextFocus != null) {
              FocusScope.of(context).requestFocus(nextFocus);
            }
          },
          style: const TextStyle(
            fontSize: 14,
            color: Color(0xFF1A1A2E),
            fontWeight: FontWeight.w500,
          ),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(
              color: Colors.grey.shade400,
              fontSize: 14,
              fontWeight: FontWeight.w400,
            ),
            prefixIcon: Container(
              margin: const EdgeInsets.all(10),
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: mobilkomBlue.withOpacity(0.08),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: mobilkomBlue, size: 16),
            ),
            filled: true,
            fillColor: softGrey,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: borderGrey, width: 1.5),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: mobilkomBlue, width: 1.8),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: mobilkomRed, width: 1.5),
            ),
            focusedErrorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: mobilkomRed, width: 1.8),
            ),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            suffixIcon: suffixIcon,
            errorStyle: const TextStyle(
              fontSize: 11,
              color: mobilkomRed,
            ),
          ),
          validator: validator,
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 600;
    final cardPadding = isMobile ? 28.0 : 40.0;

    return Scaffold(
      backgroundColor: softWhite,
      body: Stack(
        children: [
          Positioned.fill(
            child: CustomPaint(painter: _BackgroundPainter()),
          ),

          AnimatedBuilder(
            animation: _floatAnimation,
            builder: (context, _) {
              return Stack(
                children: [
                  Positioned(
                    top: 60 + _floatAnimation.value,
                    left: -40,
                    child: _buildDecorCircle(160, mobilkomBlue.withOpacity(0.06)),
                  ),
                  Positioned(
                    bottom: 80 - _floatAnimation.value,
                    right: -30,
                    child: _buildDecorCircle(120, mobilkomRed.withOpacity(0.06)),
                  ),
                  Positioned(
                    top: 200 - _floatAnimation.value * 0.5,
                    right: 20,
                    child: _buildDecorCircle(60, mobilkomBlue.withOpacity(0.04)),
                  ),
                ],
              );
            },
          ),

          Center(
            child: SingleChildScrollView(
              padding: EdgeInsets.symmetric(
                vertical: isMobile ? 24 : 48,
                horizontal: 16,
              ),
              child: FadeTransition(
                opacity: _fadeAnimation,
                child: SlideTransition(
                  position: _slideAnimation,
                  child: ScaleTransition(
                    scale: _scaleAnimation,
                    child: AnimatedBuilder(
                      animation: _floatAnimation,
                      builder: (context, child) {
                        return Transform(
                          alignment: Alignment.center,
                          transform: Matrix4.identity()
                            ..setEntry(3, 2, 0.001)
                            ..rotateX(_rotateXAnimation.value)
                            ..translate(0.0, _floatAnimation.value * 0.3),
                          child: child,
                        );
                      },
                      child: Container(
                        width: isMobile ? screenWidth * 0.92 : 440,
                        decoration: BoxDecoration(
                          color: cardWhite,
                          borderRadius: BorderRadius.circular(24),
                          boxShadow: [
                            BoxShadow(
                              color: mobilkomBlue.withOpacity(0.12),
                              blurRadius: 40,
                              offset: const Offset(0, 16),
                              spreadRadius: -4,
                            ),
                            BoxShadow(
                              color: Colors.black.withOpacity(0.04),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(24),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              _buildHeader(isMobile),
                              Padding(
                                padding: EdgeInsets.all(cardPadding),
                                child: Form(
                                  key: _formKey,
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.stretch,
                                    children: [
                                      _buildTextField(
                                        controller: _nameController,
                                        hint: 'Masukkan nama lengkap',
                                        label: 'NAMA LENGKAP',
                                        icon: Icons.person_outline_rounded,
                                        focusNode: _nameFocus,
                                        nextFocus: _usernameFocus,
                                        validator: (v) {
                                          if (v == null || v.isEmpty)
                                            return 'Nama tidak boleh kosong';
                                          return null;
                                        },
                                      ),
                                      const SizedBox(height: 16),

                                      _buildTextField(
                                        controller: _usernameController,
                                        hint: 'Masukkan username',
                                        label: 'USERNAME',
                                        icon: Icons.alternate_email_rounded,
                                        focusNode: _usernameFocus,
                                        nextFocus: _emailFocus,
                                        validator: (v) {
                                          if (v == null || v.isEmpty)
                                            return 'Username tidak boleh kosong';
                                          if (v.length < 3)
                                            return 'Username minimal 3 karakter';
                                          return null;
                                        },
                                      ),
                                      const SizedBox(height: 16),

                                      _buildTextField(
                                        controller: _emailController,
                                        hint: 'contoh@email.com',
                                        label: 'EMAIL',
                                        icon: Icons.email_outlined,
                                        focusNode: _emailFocus,
                                        nextFocus: _passwordFocus,
                                        keyboardType:
                                            TextInputType.emailAddress,
                                        validator: (v) {
                                          if (v == null || v.isEmpty)
                                            return 'Email tidak boleh kosong';
                                          if (!RegExp(
                                                  r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$')
                                              .hasMatch(v))
                                            return 'Format email tidak valid';
                                          return null;
                                        },
                                      ),
                                      const SizedBox(height: 16),

                                      _buildTextField(
                                        controller: _passwordController,
                                        hint: 'Minimal 6 karakter',
                                        label: 'PASSWORD',
                                        icon: Icons.lock_outline_rounded,
                                        focusNode: _passwordFocus,
                                        nextFocus: _confirmPasswordFocus,
                                        obscureText: !_isPasswordVisible,
                                        validator: (v) {
                                          if (v == null || v.isEmpty)
                                            return 'Password tidak boleh kosong';
                                          if (v.length < 6)
                                            return 'Password minimal 6 karakter';
                                          return null;
                                        },
                                        suffixIcon: IconButton(
                                          icon: Icon(
                                            _isPasswordVisible
                                                ? Icons.visibility_rounded
                                                : Icons.visibility_off_rounded,
                                            color: Colors.grey.shade500,
                                            size: 20,
                                          ),
                                          onPressed: () => setState(() =>
                                              _isPasswordVisible =
                                                  !_isPasswordVisible),
                                        ),
                                      ),
                                      const SizedBox(height: 16),

                                      _buildTextField(
                                        controller: _confirmPasswordController,
                                        hint: 'Ulangi password Anda',
                                        label: 'KONFIRMASI PASSWORD',
                                        icon: Icons.lock_person_outlined,
                                        focusNode: _confirmPasswordFocus,
                                        obscureText:
                                            !_isConfirmPasswordVisible,
                                        isLast: true,
                                        validator: (v) {
                                          if (v == null || v.isEmpty)
                                            return 'Konfirmasi password tidak boleh kosong';
                                          if (v != _passwordController.text)
                                            return 'Password tidak cocok';
                                          return null;
                                        },
                                        suffixIcon: IconButton(
                                          icon: Icon(
                                            _isConfirmPasswordVisible
                                                ? Icons.visibility_rounded
                                                : Icons.visibility_off_rounded,
                                            color: Colors.grey.shade500,
                                            size: 20,
                                          ),
                                          onPressed: () => setState(() =>
                                              _isConfirmPasswordVisible =
                                                  !_isConfirmPasswordVisible),
                                        ),
                                      ),
                                      const SizedBox(height: 28),

                                      _buildRegisterButton(isMobile),
                                      const SizedBox(height: 20),

                                      Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: [
                                          Text(
                                            'Sudah punya akun? ',
                                            style: TextStyle(
                                              fontSize: 13,
                                              color: Colors.grey.shade600,
                                            ),
                                          ),
                                          GestureDetector(
                                            onTap: () =>
                                                Navigator.pop(context),
                                            child: const Text(
                                              'Masuk',
                                              style: TextStyle(
                                                fontSize: 13,
                                                color: mobilkomBlue,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(bool isMobile) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(
        vertical: isMobile ? 24 : 30,
        horizontal: 24,
      ),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [mobilkomBlue, Color(0xFF2A6585)],
        ),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.15),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Image.asset(
              'images/mobilkom.png',
              height: isMobile ? 36 : 42,
              errorBuilder: (_, __, ___) => Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'MOBIL',
                    style: TextStyle(
                      fontSize: isMobile ? 20 : 24,
                      fontWeight: FontWeight.w900,
                      color: mobilkomBlue,
                      letterSpacing: 1,
                    ),
                  ),
                  Text(
                    'KOM',
                    style: TextStyle(
                      fontSize: isMobile ? 20 : 24,
                      fontWeight: FontWeight.w900,
                      color: mobilkomRed,
                      letterSpacing: 1,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'Buat Akun Baru',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.white,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Lengkapi data di bawah untuk mendaftar',
            style: TextStyle(
              fontSize: 12,
              color: Colors.white.withOpacity(0.75),
            ),
          ),
          const SizedBox(height: 12),
          Container(
            width: 40,
            height: 3,
            decoration: BoxDecoration(
              color: mobilkomRed,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRegisterButton(bool isMobile) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      height: isMobile ? 50 : 54,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        gradient: _isLoading
            ? null
            : const LinearGradient(
                colors: [mobilkomRed, Color(0xFFFF6B5B)],
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
              ),
        color: _isLoading ? Colors.grey.shade300 : null,
        boxShadow: _isLoading
            ? []
            : [
                BoxShadow(
                  color: mobilkomRed.withOpacity(0.35),
                  blurRadius: 16,
                  offset: const Offset(0, 6),
                ),
              ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: _isLoading ? null : _register,
          borderRadius: BorderRadius.circular(12),
          splashColor: Colors.white24,
          child: Center(
            child: _isLoading
                ? const SizedBox(
                    height: 22,
                    width: 22,
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 2.5,
                    ),
                  )
                : const Text(
                    'DAFTAR SEKARANG',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      letterSpacing: 1.5,
                    ),
                  ),
          ),
        ),
      ),
    );
  }

  Widget _buildDecorCircle(double size, Color color) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color,
      ),
    );
  }
}

class _BackgroundPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFFE8ECF0).withOpacity(0.6)
      ..style = PaintingStyle.fill;

    const spacing = 28.0;
    const dotRadius = 1.2;

    for (double x = 0; x < size.width; x += spacing) {
      for (double y = 0; y < size.height; y += spacing) {
        canvas.drawCircle(Offset(x, y), dotRadius, paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}