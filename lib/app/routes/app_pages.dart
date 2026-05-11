import 'package:get/get.dart';

import '../../pages/login.dart';
import '../../pages/register.dart';
import '../../pages/screen_loading.dart';
import '../../widgets/smart_navbar.dart';
import 'app_routes.dart';

class AppPages {
  static final List<GetPage<dynamic>> pages = [
    GetPage(name: AppRoutes.loading, page: () => const LoadingScreen()),
    GetPage(name: AppRoutes.login, page: () => const LoginPage()),
    GetPage(name: AppRoutes.register, page: () => const RegisterPage()),
    GetPage(name: AppRoutes.shell, page: () => const MainShell()),
  ];
}
