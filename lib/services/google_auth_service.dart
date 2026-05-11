import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../firebase_options.dart';

class GoogleAuthService {
  GoogleAuthService({FirebaseAuth? auth, GoogleSignIn? googleSignIn})
    : _auth = auth ?? FirebaseAuth.instance,
      _googleSignIn = googleSignIn ?? GoogleSignIn.instance;

  final FirebaseAuth _auth;
  final GoogleSignIn _googleSignIn;
  bool _initialized = false;
  static const String _androidServerClientId =
      '301258608651-npm1c6a6cvbonm8ulv30hi2l76u9nntu.apps.googleusercontent.com';

  Future<UserCredential> signInWithGoogle() async {
    if (_isUnsupportedDesktop) {
      throw FirebaseAuthException(
        code: 'unsupported-platform',
        message:
            'Sign in with Google belum didukung di platform ini. Gunakan Android, iOS, macOS, atau Web.',
      );
    }

    if (kIsWeb) {
      final GoogleAuthProvider provider = GoogleAuthProvider();
      return _auth.signInWithPopup(provider);
    }

    if (!_initialized) {
      await _googleSignIn.initialize(
        clientId: _appleClientId,
        serverClientId: _androidServerClientId,
      );
      _initialized = true;
    }

    final GoogleSignInAccount googleUser = await _googleSignIn.authenticate();
    final GoogleSignInAuthentication googleAuth = googleUser.authentication;
    if (googleAuth.idToken == null) {
      throw FirebaseAuthException(
        code: 'missing-google-token',
        message:
            'Google Sign-In tidak mengembalikan token autentikasi. Periksa konfigurasi OAuth pada Firebase.',
      );
    }

    final OAuthCredential credential = GoogleAuthProvider.credential(
      idToken: googleAuth.idToken,
    );

    return _auth.signInWithCredential(credential);
  }

  Future<void> signOut() async {
    await _googleSignIn.signOut();
    await _auth.signOut();
  }

  String? get _appleClientId {
    if (defaultTargetPlatform == TargetPlatform.iOS ||
        defaultTargetPlatform == TargetPlatform.macOS) {
      return DefaultFirebaseOptions.currentPlatform.iosClientId;
    }
    return null;
  }

  bool get _isUnsupportedDesktop {
    return !kIsWeb &&
        (defaultTargetPlatform == TargetPlatform.windows ||
            defaultTargetPlatform == TargetPlatform.linux);
  }
}
