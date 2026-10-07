import 'package:flutter/material.dart';
import 'package:opennutritracker/core/domain/entity/intake_entity.dart';
import 'package:opennutritracker/core/domain/entity/intake_type_entity.dart';
import 'package:opennutritracker/core/utils/locator.dart';
import 'package:opennutritracker/features/quick_log/data/quick_log_repository.dart';
import 'package:opennutritracker/features/quick_log/presentation/dev_widgets.dart';
import 'package:opennutritracker/generated/l10n.dart';

Future<void> devEntryAction(
  BuildContext context,
  IntakeEntity entry,
  String action,
) async {
  final repository = locator<QuickLogRepository>();
  try {
    if (action == 'delete') {
      await repository.delete(entry);
    } else if (action == 'again') {
      await repository.log(
        entry.meal,
        entry.amount,
        entry.type,
        DateTime.now(),
        displayUnit: entry.displayUnit,
        baseAmountPerDisplayUnit: entry.baseAmountPerDisplayUnit,
      );
    } else {
      final choice = await showDialog<(DateTime, IntakeTypeEntity)>(
        context: context,
        builder: (_) => _DestinationDialog(entry: entry),
      );
      if (choice == null) return;
      if (action == 'move') {
        await repository.move(entry, choice.$1, choice.$2);
      } else {
        await repository.log(
          entry.meal,
          entry.amount,
          choice.$2,
          choice.$1,
          displayUnit: entry.displayUnit,
          baseAmountPerDisplayUnit: entry.baseAmountPerDisplayUnit,
        );
      }
    }
    refreshNutritionScreens();
  } catch (_) {
    if (context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(S.of(context).devStorageError)));
    }
  }
}

class _DestinationDialog extends StatefulWidget {
  final IntakeEntity entry;
  const _DestinationDialog({required this.entry});
  @override
  State<_DestinationDialog> createState() => _DestinationDialogState();
}

class _DestinationDialogState extends State<_DestinationDialog> {
  late DateTime _day;
  late IntakeTypeEntity _type;
  @override
  void initState() {
    super.initState();
    _day = widget.entry.dateTime;
    _type = widget.entry.type;
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(S.of(context).devDay),
    content: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        DevButton(
          id: 'entry-destination-day',
          label: '${_day.year}-${_day.month}-${_day.day}',
          icon: Icons.calendar_month,
          onPressed: () async {
            final day = await showDatePicker(
              context: context,
              initialDate: _day,
              firstDate: DateTime(2000),
              lastDate: DateTime(2100),
            );
            if (day != null && mounted) setState(() => _day = day);
          },
        ),
        Semantics(
          identifier: 'entry-destination-meal',
          child: DropdownButtonFormField<IntakeTypeEntity>(
            initialValue: _type,
            decoration: InputDecoration(labelText: S.of(context).devType),
            items: IntakeTypeEntity.values
                .map((t) => DropdownMenuItem(value: t, child: Text(t.name)))
                .toList(),
            onChanged: (v) => setState(() => _type = v!),
          ),
        ),
      ],
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.of(context).pop(),
        child: Text(MaterialLocalizations.of(context).cancelButtonLabel),
      ),
      TextButton(
        onPressed: () => Navigator.of(
          context,
        ).pop((DateTime(_day.year, _day.month, _day.day), _type)),
        child: Text(S.of(context).devSave),
      ),
    ],
  );
}
