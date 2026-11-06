import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../screens/boutique_screen.dart' show shopNavBarHiddenProvider;

/// Keeps each tab's navigator alive while allowing horizontal page swipes.
class SwipeBranchContainer extends ConsumerStatefulWidget {
  const SwipeBranchContainer({
    super.key,
    required this.navigationShell,
    required this.children,
  });

  final StatefulNavigationShell navigationShell;
  final List<Widget> children;

  @override
  ConsumerState<SwipeBranchContainer> createState() =>
      _SwipeBranchContainerState();
}

class _SwipeBranchContainerState extends ConsumerState<SwipeBranchContainer> {
  late final PageController _pageController =
      PageController(initialPage: widget.navigationShell.currentIndex);

  @override
  void didUpdateWidget(covariant SwipeBranchContainer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.navigationShell.currentIndex ==
        widget.navigationShell.currentIndex) {
      return;
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_pageController.hasClients) return;
      // A swipe already moves the PageView. Don't interrupt that gesture when
      // go_router reports the newly selected branch.
      if (_pageController.position.isScrollingNotifier.value) return;
      if (_pageController.page?.round() ==
          widget.navigationShell.currentIndex) {
        return;
      }
      _pageController.animateToPage(
        widget.navigationShell.currentIndex,
        duration: const Duration(milliseconds: 260),
        curve: Curves.easeOutCubic,
      );
    });
  }

  void _selectBranch(int index) {
    if (index == widget.navigationShell.currentIndex) return;
    ref.read(shopNavBarHiddenProvider.notifier).state = false;
    widget.navigationShell.goBranch(index, initialLocation: index == 3);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => PageView(
        controller: _pageController,
        onPageChanged: _selectBranch,
        children: [
          for (var index = 0; index < widget.children.length; index++)
            _KeepAliveBranch(
              key: ValueKey(index),
              child: widget.children[index],
            ),
        ],
      );
}

class _KeepAliveBranch extends StatefulWidget {
  const _KeepAliveBranch({super.key, required this.child});

  final Widget child;

  @override
  State<_KeepAliveBranch> createState() => _KeepAliveBranchState();
}

class _KeepAliveBranchState extends State<_KeepAliveBranch>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return widget.child;
  }
}
