// Strips the structured-output envelopes the desktop AssistantPanel
// parses out at render time. On the desktop those envelopes become
// action buttons / styled blocks; on mobile (for now) we just hide
// them and surface the prose, plus a flat list of any action items
// for the screen to render as chips.
//
// Envelopes the runner emits today:
//
//   - ```json { "version": "assistant.v1", … }```  (the wrapper
//     written by appendNormalizedFinalResponse on the desktop)
//   - inline {"type":"action","actions":[…]} blocks the agent
//     emits at the tail of a turn

import 'dart:convert';

class AssistantActionItem {
  AssistantActionItem({
    required this.id,
    required this.label,
    this.spaceId,
    this.openMode,
    this.url,
  });

  final String id;
  final String label;
  final String? spaceId;
  final String? openMode;
  final String? url;
}

class ParsedAssistantAnswer {
  ParsedAssistantAnswer({required this.prose, required this.actions});
  final String prose;
  final List<AssistantActionItem> actions;
}

ParsedAssistantAnswer parseAssistantAnswer(String raw) {
  final actions = <AssistantActionItem>[];
  String text = raw;

  // 1. Strip ```json … ``` fenced blocks. Capture inner JSON so we
  // can salvage actions before discarding the rest.
  text = text.replaceAllMapped(
    RegExp(r'```json\s*([\s\S]*?)```', multiLine: true),
    (m) {
      _extractActions(m.group(1), actions);
      return '';
    },
  );

  // 2. Strip plain inline JSON envelopes that start with one of the
  // known assistant-envelope keys. Be conservative — we don't want to
  // eat unrelated curly braces in prose.
  final envelopeKeys =
      r'(?:type|version|state|provider|stop_reason|response|content|refusal)';
  text = text.replaceAllMapped(
    RegExp(
      // {"type": …} where the value can contain nested {}, balanced
      // up to one level deep (covers actions arrays).
      r'\{"' + envelopeKeys + r'":(?:[^{}]|\{[^{}]*\})*\}',
      multiLine: true,
    ),
    (m) {
      _extractActions(m.group(0), actions);
      return '';
    },
  );

  // Tidy the residue: collapse runs of blank lines, trim ends.
  text = text.replaceAll(RegExp(r'\n{3,}'), '\n\n').trim();

  return ParsedAssistantAnswer(prose: text, actions: actions);
}

void _extractActions(String? jsonStr, List<AssistantActionItem> sink) {
  if (jsonStr == null) return;
  final trimmed = jsonStr.trim();
  if (trimmed.isEmpty) return;
  try {
    final v = jsonDecode(trimmed);
    if (v is Map<String, dynamic> && v['type'] == 'action') {
      final list = (v['actions'] as List?) ?? const [];
      for (final a in list) {
        if (a is Map<String, dynamic>) {
          sink.add(AssistantActionItem(
            id: (a['id'] as String?) ?? '',
            label: (a['label'] as String?) ?? '',
            spaceId: a['spaceId'] as String?,
            openMode: a['openMode'] as String?,
            url: a['url'] as String?,
          ));
        }
      }
    }
  } catch (_) {
    // Not JSON, or not the shape we recognize — drop silently.
  }
}
