import 'package:opennutritracker/features/quick_log/presentation/goals_screen.dart';
import 'package:flutter/material.dart';
import 'package:opennutritracker/core/presentation/widgets/dynamic_ont_logo.dart';
import 'package:opennutritracker/generated/l10n.dart';

class HomeAppbar extends StatelessWidget implements PreferredSizeWidget {
  const HomeAppbar({super.key});

  @override
  Widget build(BuildContext context) {
    return AppBar(
      actions: [
        Semantics(
          identifier: 'home-goals',
          child: IconButton(
            icon: const Icon(Icons.tune),
            tooltip: S.of(context).devGoals,
            onPressed: () => Navigator.of(
              context,
            ).push(MaterialPageRoute(builder: (_) => const GoalsScreen())),
          ),
        ),
      ],
      title: Row(
        children: [
          const SizedBox(width: 40, child: DynamicOntLogo()),
          Expanded(
            child: RichText(
              text: TextSpan(
                text: S.of(context).appTitle,
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);
}
