import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../controllers/news_controller.dart';

class NewsView extends GetView<NewsController> {
  const NewsView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('뉴스')),
      body: Center(
        child: Text(
          '뉴스 페이지',
          style: Theme.of(context).textTheme.headlineMedium,
        ),
      ),
    );
  }
}
