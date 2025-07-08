import 'package:flutter/material.dart';

class DrawerAppBar extends StatelessWidget implements PreferredSizeWidget {
  final Widget title;
  final GlobalKey<ScaffoldState> scaffoldKey;
  final Color backgroundColor;
  final List<Widget>? actions;

  const DrawerAppBar({
    super.key,
    required this.title,
    required this.scaffoldKey,
    this.backgroundColor = const Color(0xFFFFEB3B),
    this.actions,
  });

  @override
  Widget build(BuildContext context) {
    return AppBar(
      leading: IconButton(
        icon: const Icon(Icons.menu, color: Colors.white),
        onPressed: () => scaffoldKey.currentState?.openDrawer(),
      ),
      title: title,
      backgroundColor: backgroundColor,
      actions: actions,
    );
  }

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);
}
