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

class _MainScreenState extends ConsumerState<MainScreen>
    with SingleTickerProviderStateMixin {
  int _currentIndex = 0;
  final PageController _pageController = PageController();
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  // Цвета для индикаторов вкладок
  final List<Color> _tabColors = [
    const Color(0xFF3A79FF), // Signals - Blue
    const Color(0xFF44C97C), // Portfolio - Green
    const Color(0xFFE6A537), // History - Amber
    const Color(0xFF9C69F8), // Monitoring - Purple
  ];

  // Create screen instances once
  final List<Widget> _screens = [
    const SignalScreen(),
    const PortfolioScreen(),
    const HistoryScreen(),
    const WatchlistScreen(),
  ];

  @override
  void initState() {
    super.initState();

    // Анимация для плавных переходов
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: Curves.easeInOut,
      ),
    );

    _animationController.forward();
  }

  @override
  void dispose() {
    _pageController.dispose();
    _animationController.dispose();
    super.dispose();
  }

  void _onPageChanged(int index) {
    setState(() {
      _currentIndex = index;
    });
  }

  void _onItemTapped(int index) {
    // Сначала останавливаем текущую анимацию, если она есть
    if (_animationController.isAnimating) {
      _animationController.stop();
    }

    // Сбрасываем анимацию
    _animationController.reset();

    // Меняем страницу через PageController
    _pageController.animateToPage(
      index,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );

    // Запускаем анимацию для плавного появления нового контента
    _animationController.forward();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    // Чтобы поддержать Hero-анимацию с акулой со сплеш-экрана,
    // добавляем невидимый Hero-виджет
    return Stack(
      children: [
        // Невидимый Hero для передачи акулы
        Positioned(
          left: -100, // За пределами экрана
          top: -100,
          child: Hero(
            tag: 'splash_shark',
            child: Opacity(
              opacity: 0.0,
              child: Image.asset(
                'assets/images/shark.png',
                width: 10,
                height: 10,
              ),
            ),
          ),
        ),

        // Основной контент
        RepaintBoundary(
          child: Scaffold(
            // Используем FadeTransition для плавного перехода между экранами
            body: FadeTransition(
              opacity: _fadeAnimation,
              child: PageView(
                controller: _pageController,
                onPageChanged: _onPageChanged,
                physics: const NeverScrollableScrollPhysics(),
                children: _screens.map((screen) {
                  // Оборачиваем каждый экран в RepaintBoundary для оптимизации
                  return RepaintBoundary(child: screen);
                }).toList(),
              ),
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
                  selectedItemColor: _tabColors[_currentIndex],
                  unselectedItemColor: Colors.white.withOpacity(0.5),
                  showSelectedLabels: true,
                  showUnselectedLabels: true,
                  type: BottomNavigationBarType.fixed,
                  elevation: 0,
                  items: [
                    BottomNavigationBarItem(
                      icon: _buildNavIcon(Icons.bar_chart, 0),
                      label: 'Signals',
                    ),
                    BottomNavigationBarItem(
                      icon: _buildNavIcon(Icons.account_balance_wallet, 1),
                      label: 'Portfolio',
                    ),
                    BottomNavigationBarItem(
                      icon: _buildNavIcon(Icons.history, 2),
                      label: 'History',
                    ),
                    BottomNavigationBarItem(
                      icon: _buildNavIcon(Icons.radar, 3),
                      label: 'Monitoring',
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  // Виджет для создания иконки навигации с эффектом масштабирования
  Widget _buildNavIcon(IconData icon, int index) {
    final bool isSelected = _currentIndex == index;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      padding: EdgeInsets.all(isSelected ? 2.0 : 0.0),
      decoration: BoxDecoration(
        color: isSelected
            ? _tabColors[index].withOpacity(0.1)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Icon(
        icon,
        size: isSelected ? 24 : 22,
      ),
    );
  }
}
