import 'package:flutter/material.dart';
import '../service/login_helper.dart';
import '../admin/admin_layout.dart';
import '../user/user_layout.dart';
import '../register.dart';
import '../forgot_password.dart'; 

class LoginPage extends StatefulWidget {
  @override
  _LoginPageState createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> with TickerProviderStateMixin {
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final FocusNode _usernameFocus = FocusNode();
  final FocusNode _passwordFocus = FocusNode();
  bool _isLoading = false;
  bool _obscurePassword = true;

  late AnimationController _cardController;
  late AnimationController _floatController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _scaleAnimation;
  late Animation<double> _floatAnimation;
  late Animation<double> _rotateAnimation;

  // ─── Warna Mobilkom ───────────────────────────────────────────────────
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

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _cardController, curve: Curves.easeOut),
    );

    _slideAnimation =
        Tween<Offset>(begin: const Offset(0, 0.08), end: Offset.zero).animate(
      CurvedAnimation(parent: _cardController, curve: Curves.easeOutCubic),
    );

    _scaleAnimation = Tween<double>(begin: 0.92, end: 1.0).animate(
      CurvedAnimation(parent: _cardController, curve: Curves.easeOutBack),
    );

    _floatAnimation = Tween<double>(begin: -6.0, end: 6.0).animate(
      CurvedAnimation(parent: _floatController, curve: Curves.easeInOut),
    );

    _rotateAnimation = Tween<double>(begin: -0.018, end: 0.018).animate(
      CurvedAnimation(parent: _floatController, curve: Curves.easeInOut),
    );

    _cardController.forward();
  }

  @override
  void dispose() {
    _cardController.dispose();
    _floatController.dispose();
    _usernameController.dispose();
    _passwordController.dispose();
    _usernameFocus.dispose();
    _passwordFocus.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    if (_usernameController.text.isEmpty || _passwordController.text.isEmpty) {
      _showMessage('Username dan password harus diisi', isError: true);
      return;
    }

    setState(() => _isLoading = true);

    try {
      final result = await LoginHelper.login(
        _usernameController.text.trim(),
        _passwordController.text.trim(),
      );

      setState(() => _isLoading = false);

      if (result['status'] == 'success') {
      final userData = result['data'] as Map<String, dynamic>?;

        if (userData != null) {
          final userRole = userData['role']?.toString(); 
          PageRouteBuilder transition(Widget page) {
            return PageRouteBuilder(
              pageBuilder: (_, __, ___) => page,
              transitionsBuilder: (_, anim, __, child) {
                return SlideTransition(
                  position: Tween<Offset>(
                    begin: const Offset(0, 1),
                    end: Offset.zero,
                  ).animate(anim),
                  child: child,
                );
              },
            );
          }
          if (!mounted) return;

          if (userRole == 'admin') {
            Navigator.pushReplacement(context, transition(AdminLayout()));
          } else if (userRole == 'staff') {
            Navigator.pushReplacement(context, transition(UserLayout()));
          } else {
            _showMessage('Role pengguna tidak dikenali: $userRole', isError: true);
          }
        } else {
          _showMessage('Data pengguna kosong.', isError: true);
        }
      }
    } catch (e) {
      setState(() => _isLoading = false);
      _showMessage('Terjadi kesalahan: $e', isError: true);
    }
  }

  void _showMessage(String message, {required bool isError}) {
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
            Expanded(
                child: Text(message, style: const TextStyle(fontSize: 13))),
          ],
        ),
        backgroundColor: isError ? mobilkomRed : Colors.green.shade600,
        behavior: SnackBarBehavior.floating,
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 600;

    return Scaffold(
      backgroundColor: softWhite,
      body: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        child: Stack(
          children: [
            // Background dot-grid
            Positioned.fill(
              child: CustomPaint(painter: _BgDotPainter()),
            ),

            // Dekorasi lingkaran floating
            AnimatedBuilder(
              animation: _floatAnimation,
              builder: (_, __) => Stack(children: [
                Positioned(
                  top: 50 + _floatAnimation.value,
                  left: -50,
                  child: _decorCircle(180, mobilkomBlue.withOpacity(0.06)),
                ),
                Positioned(
                  bottom: 60 - _floatAnimation.value,
                  right: -40,
                  child: _decorCircle(140, mobilkomRed.withOpacity(0.06)),
                ),
                Positioned(
                  top: 200 - _floatAnimation.value * 0.5,
                  right: 10,
                  child: _decorCircle(55, mobilkomBlue.withOpacity(0.04)),
                ),
                Positioned(
                  bottom: 200 + _floatAnimation.value * 0.4,
                  left: 30,
                  child: _decorCircle(40, mobilkomRed.withOpacity(0.04)),
                ),
              ]),
            ),

            // Kartu utama
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
                        builder: (_, child) => Transform(
                          alignment: Alignment.center,
                          transform: Matrix4.identity()
                            ..setEntry(3, 2, 0.001)
                            ..rotateX(_rotateAnimation.value)
                            ..translate(0.0, _floatAnimation.value * 0.3),
                          child: child,
                        ),
                        child: Container(
                          width: isMobile ? screenWidth * 0.92 : 430,
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
                                // ── Header banner biru ─────────────────
                                _buildHeader(isMobile),

                                // ── Form ───────────────────────────────
                                Padding(
                                  padding: EdgeInsets.all(
                                      isMobile ? 24 : 36),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.stretch,
                                    children: [
                                      // Username field
                                      _buildLabel('USERNAME'),
                                      const SizedBox(height: 6),
                                      _buildTextField(
                                        controller: _usernameController,
                                        focusNode: _usernameFocus,
                                        hint: 'Masukkan username Anda',
                                        icon: Icons.alternate_email_rounded,
                                        textInputAction:
                                            TextInputAction.next,
                                        onSubmitted: (_) =>
                                            FocusScope.of(context)
                                                .requestFocus(
                                                    _passwordFocus),
                                      ),
                                      const SizedBox(height: 18),

                                      // Password field
                                      _buildLabel('PASSWORD'),
                                      const SizedBox(height: 6),
                                      _buildTextField(
                                        controller: _passwordController,
                                        focusNode: _passwordFocus,
                                        hint: 'Masukkan password Anda',
                                        icon: Icons.lock_outline_rounded,
                                        obscureText: _obscurePassword,
                                        textInputAction:
                                            TextInputAction.done,
                                        onSubmitted: (_) => _login(),
                                        suffixIcon: IconButton(
                                          icon: Icon(
                                            _obscurePassword
                                                ? Icons.visibility_off_rounded
                                                : Icons.visibility_rounded,
                                            color: Colors.grey.shade500,
                                            size: 20,
                                          ),
                                          onPressed: () => setState(() =>
                                              _obscurePassword =
                                                  !_obscurePassword),
                                        ),
                                      ),

                                      // ── Lupa Kata Sandi ────────────────
                                      Align(
                                        alignment: Alignment.centerRight,
                                        child: TextButton(
                                          onPressed: () {
                                            Navigator.push(
                                              context,
                                              PageRouteBuilder(
                                                pageBuilder:
                                                    (_, __, ___) =>
                                                        const ForgotPasswordPage(),
                                                transitionsBuilder:
                                                    (_, anim, __, child) {
                                                  return FadeTransition(
                                                    opacity: anim,
                                                    child: SlideTransition(
                                                      position: Tween<
                                                              Offset>(
                                                        begin: const Offset(
                                                            0.05, 0),
                                                        end: Offset.zero,
                                                      ).animate(anim),
                                                      child: child,
                                                    ),
                                                  );
                                                },
                                              ),
                                            );
                                          },
                                          style: TextButton.styleFrom(
                                            padding:
                                                const EdgeInsets.symmetric(
                                                    horizontal: 0,
                                                    vertical: 4),
                                            minimumSize: Size.zero,
                                            tapTargetSize:
                                                MaterialTapTargetSize
                                                    .shrinkWrap,
                                          ),
                                          child: const Text(
                                            'Lupa Kata Sandi?',
                                            style: TextStyle(
                                              fontSize: 13,
                                              color: mobilkomRed,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ),
                                      ),

                                      const SizedBox(height: 8),

                                      // ── Tombol Masuk ──────────────────
                                      _buildLoginButton(isMobile),
                                      const SizedBox(height: 20),

                                      // ── Divider ───────────────────────
                                      Row(children: [
                                        Expanded(
                                            child: Divider(
                                                color: Colors.grey.shade200,
                                                thickness: 1)),
                                        Padding(
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 12),
                                          child: Text(
                                            'atau',
                                            style: TextStyle(
                                                fontSize: 12,
                                                color:
                                                    Colors.grey.shade500),
                                          ),
                                        ),
                                        Expanded(
                                            child: Divider(
                                                color: Colors.grey.shade200,
                                                thickness: 1)),
                                      ]),
                                      const SizedBox(height: 16),

                                      // ── Tombol Register ───────────────
                                      _buildRegisterButton(),
                                    ],
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
      ),
    );
  }

  // ─── Header ───────────────────────────────────────────────────────────
  Widget _buildHeader(bool isMobile) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(
          vertical: isMobile ? 24 : 30, horizontal: 24),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [mobilkomBlue, Color(0xFF2A6585)],
        ),
      ),
      child: Column(
        children: [
          // Logo
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
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
                  Text('MOBIL',
                      style: TextStyle(
                          fontSize: isMobile ? 20 : 24,
                          fontWeight: FontWeight.w900,
                          color: mobilkomBlue)),
                  Text('KOM',
                      style: TextStyle(
                          fontSize: isMobile ? 20 : 24,
                          fontWeight: FontWeight.w900,
                          color: mobilkomRed)),
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),
          const Text(
            'Selamat Datang',
            style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.white,
                letterSpacing: 0.5),
          ),
          const SizedBox(height: 4),
          Text(
            'Masuk untuk melanjutkan ke sistem inventori',
            style: TextStyle(
                fontSize: 12, color: Colors.white.withOpacity(0.75)),
            textAlign: TextAlign.center,
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

  // ─── Label field ──────────────────────────────────────────────────────
  Widget _buildLabel(String text) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w700,
        color: mobilkomBlue,
        letterSpacing: 0.8,
      ),
    );
  }

  // ─── TextField reusable ───────────────────────────────────────────────
  Widget _buildTextField({
    required TextEditingController controller,
    required FocusNode focusNode,
    required String hint,
    required IconData icon,
    bool obscureText = false,
    Widget? suffixIcon,
    TextInputAction? textInputAction,
    Function(String)? onSubmitted,
  }) {
    return TextField(
      controller: controller,
      focusNode: focusNode,
      obscureText: obscureText,
      textInputAction: textInputAction,
      onSubmitted: onSubmitted,
      style: const TextStyle(
          fontSize: 14,
          color: Color(0xFF1A1A2E),
          fontWeight: FontWeight.w500),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle:
            TextStyle(color: Colors.grey.shade400, fontSize: 14),
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
          borderSide:
              const BorderSide(color: borderGrey, width: 1.5),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide:
              const BorderSide(color: mobilkomBlue, width: 1.8),
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        suffixIcon: suffixIcon,
      ),
    );
  }

  // ─── Tombol Masuk (gradient merah) ────────────────────────────────────
  Widget _buildLoginButton(bool isMobile) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      height: isMobile ? 50 : 54,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        gradient: _isLoading
            ? null
            : const LinearGradient(
                colors: [mobilkomBlue, Color(0xFF2A6585)],
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
              ),
        color: _isLoading ? Colors.grey.shade300 : null,
        boxShadow: _isLoading
            ? []
            : [
                BoxShadow(
                  color: mobilkomBlue.withOpacity(0.35),
                  blurRadius: 16,
                  offset: const Offset(0, 6),
                ),
              ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: _isLoading ? null : _login,
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
                : Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: const [
                      Icon(Icons.login_rounded,
                          color: Colors.white, size: 18),
                      SizedBox(width: 8),
                      Text(
                        'MASUK',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                          letterSpacing: 1.5,
                        ),
                      ),
                    ],
                  ),
          ),
        ),
      ),
    );
  }

  // ─── Tombol Register (outline) ────────────────────────────────────────
  Widget _buildRegisterButton() {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          PageRouteBuilder(
            pageBuilder: (_, __, ___) => const RegisterPage(),
            transitionsBuilder: (_, anim, __, child) {
              return FadeTransition(
                opacity: anim,
                child: SlideTransition(
                  position: Tween<Offset>(
                    begin: const Offset(0.05, 0),
                    end: Offset.zero,
                  ).animate(anim),
                  child: child,
                ),
              );
            },
          ),
        );
      },
      child: Container(
        height: 50,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
              color: mobilkomRed.withOpacity(0.4), width: 1.5),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: const [
            Icon(Icons.person_add_outlined,
                color: mobilkomRed, size: 18),
            SizedBox(width: 8),
            Text(
              'BUAT AKUN BARU',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: mobilkomRed,
                letterSpacing: 1.2,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _decorCircle(double size, Color color) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(shape: BoxShape.circle, color: color),
    );
  }
}

// Background dot-grid painter
class _BgDotPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFFE8ECF0).withOpacity(0.6)
      ..style = PaintingStyle.fill;
    const spacing = 28.0;
    for (double x = 0; x < size.width; x += spacing) {
      for (double y = 0; y < size.height; y += spacing) {
        canvas.drawCircle(Offset(x, y), 1.2, paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}