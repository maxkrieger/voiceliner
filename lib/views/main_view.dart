import 'package:flutter/widgets.dart';

class MainView extends StatefulWidget {
  const MainView({Key? key}) : super(key: key);

  @override
  _MainViewState createState() => _MainViewState();
}

class _MainViewState extends State<MainView> {
  final PageController _pageController = PageController(initialPage: 0);
  @override
  Widget build(BuildContext context) {
    return PageView(
        scrollDirection: Axis.vertical,
        physics: const NeverScrollableScrollPhysics(),
        controller: _pageController,
        children: <Widget>[
          Container(
              color: Color.fromRGBO(100, 0, 8, 1),
              child: Center(child: Text("first"))),
          Center(child: Text("second"))
        ]);
  }
}
