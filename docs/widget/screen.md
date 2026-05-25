### GetView 사용
```dart
class HomeScreen extends GetView<HomeController> {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Home')),
      body: Obx(() {
        if (controller.isLoading) {
          return const Center(child: CircularProgressIndicator());
        }else{
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                //구성위젯1
                Widget1()
                //공백
                Sizedbox(hight:10),
                ElevatedButton(
                  onPressed: controller.refresh,
                  child: const Text('다시 시도'),
                ),
              ],
            ),
          );
          }
      }),
    );
  }

  Obx Widget1(){
    return Obx((){
      return Container(
        child:Text('${controller.index.toString()}')
      );
    });
  }
}
```