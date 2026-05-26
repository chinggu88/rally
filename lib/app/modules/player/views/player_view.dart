import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../controllers/player_controller.dart';

class PlayerView extends GetView<PlayerController> {
  const PlayerView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('선수')),
      body: Center(
        child: Text(
          '선수 페이지',
          style: Theme.of(context).textTheme.headlineMedium,
        ),
      ),
    );
  }
}
