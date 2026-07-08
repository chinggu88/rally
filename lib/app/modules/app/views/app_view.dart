import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../match/views/match_view.dart';
import '../../my_info/views/my_info_view.dart';
import '../../home/views/home_view.dart';
import '../../player/views/player_view.dart';
import '../controllers/app_controller.dart';

class AppView extends GetView<AppController> {
  const AppView({super.key});

  static const List<Widget> _tabs = [
    HomeView(),
    MatchView(),
    PlayerView(),
    MyInfoView(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Obx(
        () => IndexedStack(
          index: controller.currentIndex,
          children: _tabs,
        ),
      ),
      bottomNavigationBar: Obx(
        () => BottomNavigationBar(
          currentIndex: controller.currentIndex,
          onTap: controller.changeTab,
          items: const [
            BottomNavigationBarItem(
              icon: Icon(Icons.home_outlined),
              activeIcon: Icon(Icons.home),
              label: '홈',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.sports_tennis_outlined),
              activeIcon: Icon(Icons.sports_tennis),
              label: '경기',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.person_outline),
              activeIcon: Icon(Icons.person),
              label: '선수',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.account_circle_outlined),
              activeIcon: Icon(Icons.account_circle),
              label: '내정보',
            ),
          ],
        ),
      ),
    );
  }
}
