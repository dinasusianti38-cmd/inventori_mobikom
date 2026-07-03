import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

/// ForgotPasswordPage — Lupa Kata Sandi via Email (Gmail)
/// Step 1 → Input email → Kirim OTP ke Gmail
/// Step 2 → Verifikasi kode OTP
/// Step 3 → Buat password baru

class ForgotPasswordPage extends StatefulWidget {
  const ForgotPasswordPage({Key? key}) : super(key: key);

  @override
  State<ForgotPasswordPage> createState() => _ForgotPasswordPageState();
}

class _ForgotPasswordPageState extends State<ForgotPasswordPage>
    with TickerProviderStateMixin {

  // ─── Controllers & Focus ─────────────────────────────────────────────
  final _emailController        = TextEditingController();
  final _otpController          = TextEditingController();
  final _newPasswordController  = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  final _emailFocus           = FocusNode();
  final _otpFocus             = FocusNode();
  final _newPasswordFocus     = FocusNode();
  final _confirmPasswordFocus = FocusNode();

  // ─── State ───────────────────────────────────────────────────────────
  int  _currentStep             = 1; // 1=email, 2=otp, 3=new password
  bool _isLoading               = false;
  bool _isNewPasswordVisible    = false;
  bool _isConfirmPasswordVisible = false;
  int  _resendCountdown         = 0;
  Timer? _resendTimer;

  // ─── Animation ───────────────────────────────────────────────────────
  late AnimationController _cardController;
  late AnimationController _floatController;
  late AnimationController _stepController;
  late Animation<double>   _fadeIn;
  late Animation<Offset>   _slideIn;
  late Animation<double>   _scaleIn;
  late Animation<double>   _floatAnim;
  late Animation<double>   _rotateAnim;
  late Animation<double>   _stepFade;
  late Animation<Offset>   _stepSlide;

  // ─── API URLs ─────────────────────────────────────────────────────────
  // ✅ DIPERBAIKI: Menggunakan URL hosting yang benar (bukan IP lokal)
  static const String _baseUrl          = 'https://inventorimobilkom.my.id';
  static const String _sendOtpUrl       = '$_baseUrl/forgot_password_send.php';
  static const String _verifyOtpUrl     = '$_baseUrl/forgot_password_verify.php';
  static const String _resetPasswordUrl = '$_baseUrl/forgot_password_reset.php';

  // ─── Warna Mobilkom ──────────────────────────────────────────────────
  static const Color mobilkomBlue = Color(0xFF1D4861);
  static const Color mobilkomRed  = Color(0xFFE74C3C);
  static const Color softWhite    = Color(0xFFFAFBFC);
  static const Color cardWhite    = Color(0xFFFFFFFF);
  static const Color softGrey     = Color(0xFFF0F2F5);
  static const Color borderGrey   = Color(0xFFE8ECF0);

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
    _stepController = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );

    _fadeIn  = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _cardController, curve: Curves.easeOut));
    _slideIn = Tween<Offset>(begin: const Offset(0, 0.08), end: Offset.zero)
        .animate(CurvedAnimation(parent: _cardController, curve: Curves.easeOutCubic));
    _scaleIn = Tween<double>(begin: 0.92, end: 1.0).animate(
      CurvedAnimation(parent: _cardController, curve: Curves.easeOutBack));
    _floatAnim = Tween<double>(begin: -5.0, end: 5.0).animate(
      CurvedAnimation(parent: _floatController, curve: Curves.easeInOut));
    _rotateAnim = Tween<double>(begin: -0.015, end: 0.015).animate(
      CurvedAnimation(parent: _floatController, curve: Curves.easeInOut));
    _stepFade  = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _stepController, curve: Curves.easeOut));
    _stepSlide = Tween<Offset>(begin: const Offset(0.1, 0), end: Offset.zero)
        .animate(CurvedAnimation(parent: _stepController, curve: Curves.easeOutCubic));

    _cardController.forward();
    _stepController.forward();
  }

  @override
  void dispose() {
    _resendTimer?.cancel();
    _cardController.dispose();
    _floatController.dispose();
    _stepController.dispose();
    _emailController.dispose();
    _otpController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    _emailFocus.dispose();
    _otpFocus.dispose();
    _newPasswordFocus.dispose();
    _confirmPasswordFocus.dispose();
    super.dispose();
  }

  // ─── Transisi antar step ─────────────────────────────────────────────
  void _goToStep(int step) async {
    await _stepController.reverse();
    setState(() => _currentStep = step);
    _stepController.forward();
  }

  // ─── Helper: bersihkan response JSON dari BOM/karakter aneh ──────────
  String _cleanJson(String raw) {
    final trimmed = raw.trim();
    final start = trimmed.indexOf('{');
    return start >= 0 ? trimmed.substring(start) : trimmed;
  }

  // ─── Step 1: Kirim OTP ke email ──────────────────────────────────────
  Future<void> _sendOtp() async {
    final email = _emailController.text.trim();
    if (email.isEmpty) {
      _showMessage('Masukkan alamat email Anda', isError: true);
      return;
    }
    if (!RegExp(r'^[\w\-\.]+@([\w\-]+\.)+[\w\-]{2,4}$').hasMatch(email)) {
      _showMessage('Format email tidak valid', isError: true);
      return;
    }

    setState(() => _isLoading = true);
    try {
      final response = await http.post(
        Uri.parse(_sendOtpUrl),
        headers: {'Content-Type': 'application/x-www-form-urlencoded'},
        body: {'email': email},
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final data = json.decode(_cleanJson(response.body));
        if (data['status'] == 'success') {
          _showMessage('Kode OTP dikirim ke email Anda', isError: false);
          _startResendCountdown();
          _goToStep(2);
        } else {
          _showMessage(data['message'] ?? 'Email tidak terdaftar', isError: true);
        }
      } else {
        _showMessage('Server error: ${response.statusCode}', isError: true);
      }
    } on TimeoutException {
      _showMessage('Koneksi timeout. Periksa koneksi internet Anda.', isError: true);
    } catch (e) {
      _showMessage('Tidak dapat terhubung ke server: $e', isError: true);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ─── Step 2: Verifikasi OTP ───────────────────────────────────────────
  Future<void> _verifyOtp() async {
    final otp = _otpController.text.trim();
    if (otp.length < 6) {
      _showMessage('Masukkan 6 digit kode OTP', isError: true);
      return;
    }

    setState(() => _isLoading = true);
    try {
      final response = await http.post(
        Uri.parse(_verifyOtpUrl),
        headers: {'Content-Type': 'application/x-www-form-urlencoded'},
        body: {'email': _emailController.text.trim(), 'otp': otp},
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final data = json.decode(_cleanJson(response.body));
        if (data['status'] == 'success') {
          _showMessage('Kode OTP valid!', isError: false);
          _goToStep(3);
        } else {
          _showMessage(
              data['message'] ?? 'Kode OTP salah atau sudah kadaluarsa',
              isError: true);
        }
      } else {
        _showMessage('Server error: ${response.statusCode}', isError: true);
      }
    } on TimeoutException {
      _showMessage('Koneksi timeout. Periksa koneksi internet Anda.', isError: true);
    } catch (e) {
      _showMessage('Tidak dapat terhubung ke server: $e', isError: true);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ─── Step 3: Reset password baru ─────────────────────────────────────
  Future<void> _resetPassword() async {
    final newPass     = _newPasswordController.text;
    final confirmPass = _confirmPasswordController.text;

    if (newPass.isEmpty || newPass.length < 6) {
      _showMessage('Password minimal 6 karakter', isError: true);
      return;
    }
    if (newPass != confirmPass) {
      _showMessage('Konfirmasi password tidak cocok', isError: true);
      return;
    }

    setState(() => _isLoading = true);
    try {
      final response = await http.post(
        Uri.parse(_resetPasswordUrl),
        headers: {'Content-Type': 'application/x-www-form-urlencoded'},
        body: {
          'email':        _emailController.text.trim(),
          'otp':          _otpController.text.trim(),
          'new_password': newPass,
        },
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final data = json.decode(_cleanJson(response.body));
        if (data['status'] == 'success') {
          _showMessage('Password berhasil diperbarui! Silakan login.', isError: false);
          await Future.delayed(const Duration(seconds: 2));
          if (mounted) Navigator.pop(context);
        } else {
          _showMessage(data['message'] ?? 'Gagal memperbarui password', isError: true);
        }
      } else {
        _showMessage('Server error: ${response.statusCode}', isError: true);
      }
    } on TimeoutException {
      _showMessage('Koneksi timeout. Periksa koneksi internet Anda.', isError: true);
    } catch (e) {
      _showMessage('Tidak dapat terhubung ke server: $e', isError: true);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ─── Countdown kirim ulang ────────────────────────────────────────────
  void _startResendCountdown() {
    _resendTimer?.cancel();
    setState(() => _resendCountdown = 60);
    _resendTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      setState(() {
        if (_resendCountdown > 0) {
          _resendCountdown--;
        } else {
          timer.cancel();
        }
      });
    });
  }

  // ─── Kirim ulang OTP ─────────────────────────────────────────────────
  Future<void> _resendOtp() async {
    _otpController.clear();
    await _sendOtp();
  }

  void _showMessage(String message, {required bool isError}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(children: [
          Icon(
            isError ? Icons.error_outline : Icons.check_circle_outline,
            color: Colors.white,
            size: 20,
          ),
          const SizedBox(width: 10),
          Expanded(child: Text(message, style: const TextStyle(fontSize: 13))),
        ]),
        backgroundColor: isError ? mobilkomRed : Colors.green.shade600,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  // ─── Build ────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile    = screenWidth < 600;

    return Scaffold(
      backgroundColor: softWhite,
      body: Stack(children: [
        Positioned.fill(child: CustomPaint(painter: _BgPainter())),

        AnimatedBuilder(
          animation: _floatAnim,
          builder: (_, __) => Stack(children: [
            Positioned(
              top: 50 + _floatAnim.value, left: -50,
              child: _circle(180, mobilkomBlue.withOpacity(0.05)),
            ),
            Positioned(
              bottom: 60 - _floatAnim.value, right: -40,
              child: _circle(140, mobilkomRed.withOpacity(0.05)),
            ),
            Positioned(
              top: 180 - _floatAnim.value * 0.6, right: 10,
              child: _circle(55, mobilkomBlue.withOpacity(0.04)),
            ),
          ]),
        ),

        Center(
          child: SingleChildScrollView(
            padding: EdgeInsets.symmetric(
              vertical:   isMobile ? 24 : 48,
              horizontal: 16,
            ),
            child: FadeTransition(
              opacity: _fadeIn,
              child: SlideTransition(
                position: _slideIn,
                child: ScaleTransition(
                  scale: _scaleIn,
                  child: AnimatedBuilder(
                    animation: _floatAnim,
                    builder: (_, child) => Transform(
                      alignment: Alignment.center,
                      transform: Matrix4.identity()
                        ..setEntry(3, 2, 0.001)
                        ..rotateX(_rotateAnim.value)
                        ..translate(0.0, _floatAnim.value * 0.25),
                      child: child,
                    ),
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
                              padding: EdgeInsets.all(isMobile ? 24 : 36),
                              child: FadeTransition(
                                opacity: _stepFade,
                                child: SlideTransition(
                                  position: _stepSlide,
                                  child: _buildStepContent(isMobile),
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
      ]),
    );
  }

  Widget _buildHeader(bool isMobile) {
    final stepInfo = _stepTitles[_currentStep - 1];
    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(
          vertical: isMobile ? 22 : 28, horizontal: 24),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [mobilkomBlue, Color(0xFF2A6585)],
        ),
      ),
      child: Column(children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 9),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(10),
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
            height: isMobile ? 30 : 36,
            errorBuilder: (_, __, ___) => Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('MOBIL',
                    style: TextStyle(
                        fontSize: isMobile ? 18 : 22,
                        fontWeight: FontWeight.w900,
                        color: mobilkomBlue)),
                Text('KOM',
                    style: TextStyle(
                        fontSize: isMobile ? 18 : 22,
                        fontWeight: FontWeight.w900,
                        color: mobilkomRed)),
              ],
            ),
          ),
        ),
        const SizedBox(height: 14),

        Container(
          width: 48, height: 48,
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.15),
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white.withOpacity(0.3), width: 1.5),
          ),
          child: Icon(stepInfo['icon'] as IconData, color: Colors.white, size: 24),
        ),
        const SizedBox(height: 10),

        Text(stepInfo['title'] as String,
            style: const TextStyle(
                fontSize: 17, fontWeight: FontWeight.bold,
                color: Colors.white, letterSpacing: 0.3)),
        const SizedBox(height: 4),
        Text(stepInfo['subtitle'] as String,
            style: TextStyle(fontSize: 12, color: Colors.white.withOpacity(0.75)),
            textAlign: TextAlign.center),
        const SizedBox(height: 14),

        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(3, (i) {
            final active = i + 1 == _currentStep;
            final done   = i + 1 < _currentStep;
            return AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              margin: const EdgeInsets.symmetric(horizontal: 3),
              width: active ? 24 : 8,
              height: 8,
              decoration: BoxDecoration(
                color: active
                    ? mobilkomRed
                    : done
                        ? Colors.white.withOpacity(0.6)
                        : Colors.white.withOpacity(0.3),
                borderRadius: BorderRadius.circular(4),
              ),
            );
          }),
        ),
      ]),
    );
  }

  final List<Map<String, dynamic>> _stepTitles = [
    {'icon': Icons.email_outlined,    'title': 'Lupa Kata Sandi',  'subtitle': 'Masukkan email yang terdaftar'},
    {'icon': Icons.verified_outlined, 'title': 'Verifikasi Email', 'subtitle': 'Cek Gmail Anda untuk kode OTP'},
    {'icon': Icons.lock_reset_outlined,'title': 'Buat Password Baru','subtitle': 'Masukkan password yang aman'},
  ];

  Widget _buildStepContent(bool isMobile) {
    switch (_currentStep) {
      case 1:  return _buildStep1(isMobile);
      case 2:  return _buildStep2(isMobile);
      case 3:  return _buildStep3(isMobile);
      default: return const SizedBox();
    }
  }

  Widget _buildStep1(bool isMobile) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildInfoBox(
          icon: Icons.info_outline,
          color: mobilkomBlue,
          text: 'Masukkan alamat Gmail yang terdaftar. Kami akan mengirimkan kode verifikasi ke email tersebut.',
        ),
        const SizedBox(height: 22),

        _buildLabel('ALAMAT EMAIL'),
        const SizedBox(height: 6),
        TextFormField(
          controller: _emailController,
          focusNode:  _emailFocus,
          keyboardType:    TextInputType.emailAddress,
          textInputAction: TextInputAction.done,
          onFieldSubmitted: (_) => _sendOtp(),
          style: const TextStyle(fontSize: 14, color: Color(0xFF1A1A2E)),
          decoration: _inputDecoration(
              hint: 'contoh@gmail.com', icon: Icons.email_outlined),
        ),
        const SizedBox(height: 24),

        _buildPrimaryButton(
            label: 'KIRIM KODE VERIFIKASI',
            icon: Icons.send_rounded,
            onTap: _sendOtp),
        const SizedBox(height: 16),
        _buildBackToLogin(),
      ],
    );
  }

  Widget _buildStep2(bool isMobile) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.green.shade50,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.green.shade200, width: 1),
          ),
          child: Row(children: [
            Icon(Icons.mark_email_read_outlined,
                color: Colors.green.shade700, size: 18),
            const SizedBox(width: 10),
            Expanded(
              child: RichText(
                text: TextSpan(
                  style: TextStyle(
                      fontSize: 12, color: Colors.green.shade800, height: 1.4),
                  children: [
                    const TextSpan(text: 'Kode OTP telah dikirim ke\n'),
                    TextSpan(
                      text: _emailController.text.trim(),
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
            ),
          ]),
        ),
        const SizedBox(height: 22),

        _buildLabel('KODE VERIFIKASI (OTP)'),
        const SizedBox(height: 6),
        TextFormField(
          controller:      _otpController,
          focusNode:       _otpFocus,
          keyboardType:    TextInputType.number,
          textInputAction: TextInputAction.done,
          onFieldSubmitted: (_) => _verifyOtp(),
          textAlign:  TextAlign.center,
          maxLength:  6,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          style: const TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.bold,
            letterSpacing: 10,
            color: mobilkomBlue,
          ),
          decoration: _inputDecoration(
            hint: '000000', icon: Icons.password_rounded,
          ).copyWith(
            counterText: '',
            hintStyle: const TextStyle(
                fontSize: 28, letterSpacing: 10, color: Color(0xFFCCCCCC)),
          ),
        ),
        const SizedBox(height: 8),

        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('Tidak menerima kode? ',
                style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
            _resendCountdown > 0
                ? Text('Kirim ulang dalam ${_resendCountdown}s',
                    style: const TextStyle(fontSize: 12, color: mobilkomBlue))
                : GestureDetector(
                    onTap: _resendOtp,
                    child: const Text('Kirim ulang',
                        style: TextStyle(
                            fontSize: 12,
                            color: mobilkomRed,
                            fontWeight: FontWeight.bold)),
                  ),
          ],
        ),
        const SizedBox(height: 24),

        _buildPrimaryButton(
            label: 'VERIFIKASI KODE',
            icon: Icons.verified_rounded,
            onTap: _verifyOtp),
        const SizedBox(height: 12),
        _buildSecondaryButton(label: 'Ubah Email', onTap: () => _goToStep(1)),
      ],
    );
  }

  Widget _buildStep3(bool isMobile) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildInfoBox(
          icon: Icons.security_outlined,
          color: mobilkomBlue,
          text: 'Buat password baru yang kuat. Gunakan kombinasi huruf, angka, dan simbol.',
        ),
        const SizedBox(height: 22),

        _buildLabel('PASSWORD BARU'),
        const SizedBox(height: 6),
        TextFormField(
          controller:      _newPasswordController,
          focusNode:       _newPasswordFocus,
          obscureText:     !_isNewPasswordVisible,
          textInputAction: TextInputAction.next,
          onFieldSubmitted: (_) =>
              FocusScope.of(context).requestFocus(_confirmPasswordFocus),
          style: const TextStyle(fontSize: 14, color: Color(0xFF1A1A2E)),
          decoration: _inputDecoration(
            hint: 'Minimal 6 karakter', icon: Icons.lock_outline_rounded,
          ).copyWith(
            suffixIcon: IconButton(
              icon: Icon(
                _isNewPasswordVisible
                    ? Icons.visibility_rounded
                    : Icons.visibility_off_rounded,
                color: Colors.grey.shade500, size: 20,
              ),
              onPressed: () => setState(
                  () => _isNewPasswordVisible = !_isNewPasswordVisible),
            ),
          ),
        ),
        const SizedBox(height: 16),

        _buildLabel('KONFIRMASI PASSWORD BARU'),
        const SizedBox(height: 6),
        TextFormField(
          controller:      _confirmPasswordController,
          focusNode:       _confirmPasswordFocus,
          obscureText:     !_isConfirmPasswordVisible,
          textInputAction: TextInputAction.done,
          onFieldSubmitted: (_) => _resetPassword(),
          style: const TextStyle(fontSize: 14, color: Color(0xFF1A1A2E)),
          decoration: _inputDecoration(
            hint: 'Ulangi password baru', icon: Icons.lock_person_outlined,
          ).copyWith(
            suffixIcon: IconButton(
              icon: Icon(
                _isConfirmPasswordVisible
                    ? Icons.visibility_rounded
                    : Icons.visibility_off_rounded,
                color: Colors.grey.shade500, size: 20,
              ),
              onPressed: () => setState(() =>
                  _isConfirmPasswordVisible = !_isConfirmPasswordVisible),
            ),
          ),
        ),
        const SizedBox(height: 24),

        _buildPrimaryButton(
            label: 'SIMPAN PASSWORD BARU',
            icon: Icons.save_rounded,
            onTap: _resetPassword),
      ],
    );
  }

  Widget _buildInfoBox({
    required IconData icon,
    required Color color,
    required String text,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withOpacity(0.06),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.15), width: 1),
      ),
      child: Row(children: [
        Icon(icon, color: color, size: 18),
        const SizedBox(width: 10),
        Expanded(
          child: Text(text,
              style: TextStyle(fontSize: 12, color: color, height: 1.4)),
        ),
      ]),
    );
  }

  Widget _buildLabel(String text) {
    return Text(text,
        style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: mobilkomBlue,
            letterSpacing: 0.8));
  }

  InputDecoration _inputDecoration({required String hint, required IconData icon}) {
    return InputDecoration(
      hintText:  hint,
      hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 14),
      prefixIcon: Container(
        margin:  const EdgeInsets.all(10),
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: mobilkomBlue.withOpacity(0.08),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, color: mobilkomBlue, size: 16),
      ),
      filled:    true,
      fillColor: softGrey,
      border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none),
      enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: borderGrey, width: 1.5)),
      focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: mobilkomBlue, width: 1.8)),
      errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: mobilkomRed, width: 1.5)),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    );
  }

  Widget _buildPrimaryButton({
    required String label,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      height: 52,
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
                  blurRadius: 14,
                  offset: const Offset(0, 6),
                ),
              ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: _isLoading ? null : onTap,
          borderRadius: BorderRadius.circular(12),
          splashColor: Colors.white24,
          child: Center(
            child: _isLoading
                ? const SizedBox(
                    height: 22, width: 22,
                    child: CircularProgressIndicator(
                        color: Colors.white, strokeWidth: 2.5))
                : Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(icon, color: Colors.white, size: 18),
                      const SizedBox(width: 8),
                      Text(label,
                          style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                              letterSpacing: 1.2)),
                    ],
                  ),
          ),
        ),
      ),
    );
  }

  Widget _buildSecondaryButton({required String label, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 48,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: mobilkomBlue.withOpacity(0.3), width: 1.5),
        ),
        child: Center(
          child: Text(label,
              style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: mobilkomBlue)),
        ),
      ),
    );
  }

  Widget _buildBackToLogin() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text('Ingat password? ',
            style: TextStyle(fontSize: 13, color: Colors.grey.shade600)),
        GestureDetector(
          onTap: () => Navigator.pop(context),
          child: const Text('Kembali Login',
              style: TextStyle(
                  fontSize: 13,
                  color: mobilkomBlue,
                  fontWeight: FontWeight.bold)),
        ),
      ],
    );
  }

  Widget _circle(double size, Color color) {
    return Container(
      width: size, height: size,
      decoration: BoxDecoration(shape: BoxShape.circle, color: color),
    );
  }
}

class _BgPainter extends CustomPainter {
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