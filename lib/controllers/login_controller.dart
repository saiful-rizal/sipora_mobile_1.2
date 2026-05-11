import 'package:get/get.dart';
import 'package:flutter/material.dart';

import '../services/app_session_service.dart';
import '../services/google_auth_service.dart';
import '../services/push_notification_service.dart';
import '../services/sipora_api_service.dart';

class LoginController extends GetxController {
  LoginController({
    SiporaApiService? apiService,
    GoogleAuthService? googleAuthService,
  }) : _apiService = apiService ?? SiporaApiService(),
       _googleAuthService = googleAuthService ?? GoogleAuthService();

  final SiporaApiService _apiService;
  final GoogleAuthService _googleAuthService;

  final RxBool isLoading = false.obs;
  final RxBool isGoogleLoading = false.obs;
  final RxString errorMessage = ''.obs;

  Future<bool> loginWithEmailPassword({
    required String email,
    required String password,
  }) async {
    isLoading.value = true;
    errorMessage.value = ''; 
    
    try {
      final response = await _apiService.login(
        email: email.trim(),
        password: password,
      );

      // DEBUG: Cetak apa yang diterima dari API
      print('====== DEBUG LOGIN RESPONSE ======');
      print(response.toString());

      final rawData = response['user'] ?? 
                      (response['data'] is Map ? response['data']['user'] : null);
      
      // DEBUG: Cetak apakah user berhasil diekstrak
      print('====== DEBUG RAW DATA USER ======');
      print(rawData.toString());

      if (rawData is Map) {
        AppSessionService.setCurrentUser(Map<String, dynamic>.from(rawData));
      } else {
        // DEBUG: Kalau gagal masuk sini
        print('====== ERROR: DATA USER TIDAK DITEMUKAN ======');
      }

      return true;
    } catch (e) {
      // ✅ HANYA MENYIMPAN ERROR. TIDAK MENAMPILKAN SNACKBAR APAPUN.
      errorMessage.value = e.toString().replaceFirst('Exception: ', '');
      
      return false;
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> signInWithGoogle() async {
    isGoogleLoading.value = true;
    try {
      final credential = await _googleAuthService.signInWithGoogle();
      final user = credential.user;
      if (user != null) {
        AppSessionService.setCurrentUser({
          'id_user': user.uid,
          'nama_lengkap': user.displayName ?? user.email ?? 'Pengguna',
          'email': user.email ?? '',
          'username': user.email?.split('@').first ?? user.uid,
          'role': 'pengguna',
          'status': 'active',
        });
        await PushNotificationService.registerCurrentDeviceToken();
      }
    } finally {
      isGoogleLoading.value = false;
    }
  }
}