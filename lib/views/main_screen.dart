import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'signal_screen.dart';
import 'portfolio_screen_dark.dart';
import 'watchlist_screen.dart';
import '../viewmodels/signal_view_model.dart';

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
    const Color(0xFF9C69F8), // Monitoring - Purple
  ];

  // Create screen instances once
  final List<Widget> _screens = [
    const SignalScreen(),
    const PortfolioScreen(),
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

    // Если пользователь перешел на вкладку сигналов, сбрасываем счетчик
    if (index == 0) {
      ref.read(signalViewModelProvider.notifier).resetUnreadSignalsCount();
    }
  }

  void _onItemTapped(int index) {
    // Сначала останавливаем текущую анимацию, если она есть
    if (_animationController.isAnimating) {
      _animationController.stop();
    }

    // Сбрасываем анимацию
    _animationController.reset();

    // Если пользователь переходит на вкладку сигналов, сбрасываем счетчик
    if (index == 0) {
      ref.read(signalViewModelProvider.notifier).resetUnreadSignalsCount();
    }

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
    // Получаем количество непрочитанных сигналов
    final unreadCount = ref.watch(unreadSignalsCountProvider);

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
                      icon: _buildNavIconWithBadge(
                          Icons.bar_chart, 0, unreadCount),
                      label: 'Signals',
                    ),
                    BottomNavigationBarItem(
                      icon: _buildNavIcon(Icons.account_balance_wallet, 1),
                      label: 'Portfolio',
                    ),
                    BottomNavigationBarItem(
                      icon: _buildNavIcon(Icons.radar, 2),
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

  // Виджет для создания иконки с индикатором непрочитанных сигналов
  Widget _buildNavIconWithBadge(IconData icon, int index, int badgeCount) {
    final bool isSelected = _currentIndex == index;

    return Stack(
      clipBehavior: Clip.none,
      children: [
        // Основная иконка
        AnimatedContainer(
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
        ),

        // Бейдж с количеством непрочитанных сигналов
        if (badgeCount > 0)
          Positioned(
            top: -5,
            right: -5,
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: _tabColors[0], // Синий цвет для сигналов
                shape: badgeCount < 10 ? BoxShape.circle : BoxShape.rectangle,
                borderRadius:
                    badgeCount < 10 ? null : BorderRadius.circular(10),
                border: Border.all(
                  color: const Color(0xFF0A0A0A),
                  width: 1.5,
                ),
              ),
              constraints: const BoxConstraints(
                minWidth: 16,
                minHeight: 16,
              ),
              child: Center(
                child: Text(
                  badgeCount.toString(),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
