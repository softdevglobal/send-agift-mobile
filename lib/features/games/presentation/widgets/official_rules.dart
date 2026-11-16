import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/sheet_header.dart';

/// One part of a rules text: an optional heading and its rules in order.
class RuleSection {
  RuleSection({this.title}) : clauses = [];

  final String? title;
  final List<String> clauses;
}

/// A rules text split into a title, sections and numbered rules.
class ParsedRules {
  const ParsedRules({this.title, required this.sections, required this.words});

  final String? title;
  final List<RuleSection> sections;
  final int words;

  int get count => sections.fold(0, (n, s) => n + s.clauses.length);

  /// Minutes to read, at about 200 words a minute.
  int get minutes => (words / 200).round().clamp(1, 999);
}

final _marker = RegExp(
  r'^(?:#{1,6}\s+|\d+(?:\.\d+)*[.)]\s+|\(?[a-zA-Z]\)\s+|[-•*]\s+)',
);
final _endsSentence = RegExp(r'[.!?;,]$');

bool _isHeading(String line, String raw) {
  if (RegExp(r'^#{1,6}\s').hasMatch(raw)) return true;
  if (line.endsWith(':') && line.length <= 60) return true;
  if (RegExp('[A-Z]').hasMatch(line) &&
      line == line.toUpperCase() &&
      line.length <= 60) {
    return true;
  }
  return line.length <= 48 &&
      !_endsSentence.hasMatch(line) &&
      line.split(RegExp(r'\s+')).length <= 6;
}

/// Splits plain-text rules as admins write them. The numbers and bullets
/// they typed are dropped, because every rule is numbered again in order;
/// a line that carries on a numbered rule joins it.
@visibleForTesting
ParsedRules parseOfficialRules(String text) {
  final blocks = <List<String>>[[]];
  for (final l in text.replaceAll('\r\n', '\n').split('\n')) {
    final t = l.trim();
    if (t.isEmpty) {
      if (blocks.last.isNotEmpty) blocks.add([]);
    } else {
      blocks.last.add(t);
    }
  }
  if (blocks.last.isEmpty) blocks.removeLast();

  final all = blocks.expand((b) => b).toList();
  final words = text.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).length;
  String? title;
  final sections = <RuleSection>[RuleSection()];
  var seen = 0;

  for (final block in blocks) {
    final numbered = block.any(
      (raw) => _marker.hasMatch(raw) && !raw.startsWith('#'),
    );
    for (final raw in block) {
      seen++;
      final marked = _marker.hasMatch(raw) && !raw.startsWith('#');
      final line = raw.replaceFirst(_marker, '').trim();
      if (line.isEmpty) continue;
      final last = seen == all.length;

      if (seen == 1 &&
          !marked &&
          !last &&
          line.length <= 80 &&
          !_endsSentence.hasMatch(line)) {
        title = line.replaceFirst(RegExp(r':$'), '');
        continue;
      }
      if (!marked && !last && _isHeading(line, raw)) {
        sections.add(RuleSection(title: line.replaceFirst(RegExp(r':$'), '')));
        continue;
      }
      final cur = sections.last;
      if (!marked && numbered && cur.clauses.isNotEmpty) {
        cur.clauses[cur.clauses.length - 1] = '${cur.clauses.last} $line';
      } else {
        cur.clauses.add(line);
      }
    }
  }

  return ParsedRules(
    title: title,
    sections: sections.where((s) => s.clauses.isNotEmpty).toList(),
    words: words,
  );
}

/// A compact card that opens the full rules in a sheet.
class OfficialRulesCard extends StatelessWidget {
  const OfficialRulesCard({super.key, required this.rules, this.label});

  final String rules;

  /// Small line above the title, such as where the rules apply.
  final String? label;

  @override
  Widget build(BuildContext context) {
    final parsed = parseOfficialRules(rules);
    final n = parsed.count;
    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => showOfficialRules(context, rules),
        child: Container(
          padding: const EdgeInsets.fromLTRB(14, 14, 12, 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.border),
          ),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: AppColors.cream,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.gavel_rounded, color: AppColors.purple),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (label != null) ...[
                      Text(
                        label!.toUpperCase(),
                        style: AppTypography.tag(
                          size: 9.5,
                          color: AppColors.mutedForeground,
                        ),
                      ),
                      const SizedBox(height: 3),
                    ],
                    Text(
                      parsed.title ?? 'Official rules',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        height: 1.25,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '$n ${n == 1 ? 'rule' : 'rules'} · about '
                      '${parsed.minutes} min read',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              const Icon(
                Icons.chevron_right_rounded,
                color: AppColors.mutedForeground,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Opens the rules in a tall sheet. [footer] goes under the rules.
void showOfficialRules(
  BuildContext context,
  String rules, {
  List<Widget> footer = const [],
}) {
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (context) => DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.8,
      maxChildSize: 0.94,
      builder: (context, controller) => ListView(
        controller: controller,
        padding: const EdgeInsets.fromLTRB(
          AppTheme.gutter,
          0,
          AppTheme.gutter,
          32,
        ),
        children: [
          SheetHeader(
            title: 'Official rules',
            titleStyle: AppTypography.display(24),
            showHandle: false,
          ),
          const SizedBox(height: 12),
          OfficialRulesList(rules: rules),
          if (footer.isNotEmpty) ...[const SizedBox(height: 20), ...footer],
        ],
      ),
    ),
  );
}

/// The rules laid out: title, how many there are, then each section with
/// its numbered rules.
class OfficialRulesList extends StatelessWidget {
  const OfficialRulesList({super.key, required this.rules});

  final String rules;

  @override
  Widget build(BuildContext context) {
    final parsed = parseOfficialRules(rules);
    final body = Theme.of(
      context,
    ).textTheme.bodyMedium?.copyWith(color: AppColors.foreground, height: 1.5);
    var n = 0;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (parsed.title != null) ...[
          Text(
            parsed.title!,
            style: AppTypography.display(18).copyWith(height: 1.25),
          ),
          const SizedBox(height: 8),
        ],
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            _Chip(
              '${parsed.count} ${parsed.count == 1 ? 'rule' : 'rules'}',
              strong: true,
            ),
            _Chip('About ${parsed.minutes} min read'),
          ],
        ),
        for (final s in parsed.sections) ...[
          const SizedBox(height: 18),
          if (s.title != null) ...[
            Row(
              children: [
                Flexible(
                  child: Text(
                    s.title!.toUpperCase(),
                    style: AppTypography.tag(color: AppColors.primary),
                  ),
                ),
                const SizedBox(width: 10),
                const Expanded(child: Divider(color: AppColors.border)),
              ],
            ),
            const SizedBox(height: 10),
          ],
          for (final c in s.clauses)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Container(
                padding: const EdgeInsets.fromLTRB(10, 12, 14, 12),
                decoration: BoxDecoration(
                  color: AppColors.background,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppColors.border),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 26,
                      height: 26,
                      alignment: Alignment.center,
                      decoration: const BoxDecoration(
                        color: AppColors.primary,
                        shape: BoxShape.circle,
                      ),
                      child: Text(
                        '${++n}',
                        style: const TextStyle(
                          color: AppColors.primaryForeground,
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Text(c, style: body),
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ],
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip(this.text, {this.strong = false});

  final String text;
  final bool strong;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: strong ? AppColors.cream : AppColors.muted,
        borderRadius: BorderRadius.circular(99),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: strong ? AppColors.purple : AppColors.mutedForeground,
        ),
      ),
    );
  }
}
