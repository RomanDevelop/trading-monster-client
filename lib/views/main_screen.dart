import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'signal_screen.dart';
import 'portfolio_screen_dark.dart';
import 'history_screen.dart';
import 'watchlist_screen.dart';

class MainScreen extends ConsumerStatefulWidget {
  const MainScreen({Key? key}) : super(key: key);

  @override
  ConsumerState<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends ConsumerState<MainScreen> {
  int _currentIndex = 0;
  final PageController _pageController = PageController();

  // Создаем экземпляры экранов единожды
  final List<Widget> _screens = [
    const SignalScreen(),
    const PortfolioScreen(),
    const HistoryScreen(),
    const WatchlistScreen(),
  ];

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _onPageChanged(int index) {
    setState(() {
      _currentIndex = index;
    });
  }

  void _onItemTapped(int index) {
    _pageController.animateToPage(
      index,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return RepaintBoundary(
      child: Scaffold(
        body: PageView(
          controller: _pageController,
          onPageChanged: _onPageChanged,
          physics: const NeverScrollableScrollPhysics(),
          children: _screens,
        ),
        bottomNavigationBar: RepaintBoundary(
          child: Container(
            decoration: BoxDecoration(
              color: const Color(0xFF0A0A0A),
              border: Border(
                top: BorderSide(
                  color: Colors.white.withOpacity(0.05),
                  width: 1,
                ),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.2),
                  blurRadius: 10,
                  offset: const Offset(0, -2),
                ),
              ],
            ),
            child: BottomNavigationBar(
              currentIndex: _currentIndex,
              onTap: _onItemTapped,
              backgroundColor: const Color(0xFF0A0A0A),
              selectedItemColor: const Color(0xFF3A79FF),
              unselectedItemColor: Colors.white.withOpacity(0.5),
              showSelectedLabels: true,
              showUnselectedLabels: true,
              type: BottomNavigationBarType.fixed,
              elevation: 0,
              items: [
                BottomNavigationBarItem(
                  icon: Icon(
                    Icons.bar_chart,
                    size: _currentIndex == 0 ? 24 : 22,
                  ),
                  label: 'Сигналы',
                ),
                BottomNavigationBarItem(
                  icon: Icon(
                    Icons.account_balance_wallet,
                    size: _currentIndex == 1 ? 24 : 22,
                  ),
                  label: 'Портфель',
                ),
                BottomNavigationBarItem(
                  icon: Icon(
                    Icons.history,
                    size: _currentIndex == 2 ? 24 : 22,
                  ),
                  label: 'История',
                ),
                BottomNavigationBarItem(
                  icon: Icon(
                    Icons.radar,
                    size: _currentIndex == 3 ? 24 : 22,
                  ),
                  label: 'Мониторинг',
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
