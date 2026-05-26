import 'package:get/get.dart';

class AppController extends GetxController {
  static AppController get to => Get.find();

  final _currentIndex = 0.obs;

  int get currentIndex => _currentIndex.value;
  set currentIndex(int value) => _currentIndex.value = value;

  void changeTab(int index) {
    currentIndex = index;
  }
}
