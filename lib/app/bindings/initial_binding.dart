import 'package:get/get.dart';

import '../../controllers/login_controller.dart';
import '../../services/google_auth_service.dart';
import '../../services/sipora_api_service.dart';

class InitialBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<SiporaApiService>(() => SiporaApiService(), fenix: true);
    Get.lazyPut<GoogleAuthService>(() => GoogleAuthService(), fenix: true);
    Get.lazyPut<LoginController>(
      () => LoginController(
        apiService: Get.find<SiporaApiService>(),
        googleAuthService: Get.find<GoogleAuthService>(),
      ),
      fenix: true,
    );
  }
}
