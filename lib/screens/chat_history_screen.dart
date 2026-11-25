import 'package:flutter/material.dart';

import '../engine/format.dart';
import '../state/app_state.dart';
import '../theme.dart';
import 'talk_screen.dart';

/// Past conversations, newest first. Tap to continue, swipe to delete.
class ChatHistoryScreen extends StatelessWidget {
  const ChatHistoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = AppState.instance;
    return ListenableBuilder(
      listenable: state,
      builder: (context, _) {
        final now = DateTime.now();
        final chats = state.conversations.where((c) => c.hasUserMessage).toList();
        return Scaffold(
          backgroundColor: C.bg,
          appBar: AppBar(title: Text('Chat history', style: heading(20))),
          body: chats.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Text('No past chats yet. Every time you open CLUTCH chat, a new one starts here.',
                        textAlign: TextAlign.center, style: TextStyle(color: C.muted, height: 1.5)),
                  ),
                )
              : ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                  itemCount: chats.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (context, i) {
                    final c = chats[i];
                    final last = c.messages.lastWhere((m) => m.role != ChatRole.system,
                        orElse: () => c.messages.last);
                    return Dismissible(
                      key: ValueKey(c.id),
                      direction: DismissDirection.endToStart,
                      background: Container(
                        alignment: Alignment.centerRight,
                        padding: const EdgeInsets.only(right: 20),
                        decoration: BoxDecoration(
                            color: C.red.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(16)),
                        child: const Icon(Icons.delete_outline, color: C.red),
                      ),
                      onDismissed: (_) => state.deleteConversation(c.id),
                      child: Panel(
                        onTap: () {
                          final nav = Navigator.of(context);
                          nav.pop(); // close history
                          nav.pushReplacement(MaterialPageRoute(
                            builder: (_) => TalkScreen(conversationId: c.id),
                          ));
                        },
                        child: Row(children: [
                          CircleAvatar(
                            radius: 18,
                            backgroundColor: C.accent.withValues(alpha: 0.15),
                            child: Icon(Icons.chat_bubble_outline, color: C.accent, size: 18),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                              Text(c.title,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(color: C.text, fontWeight: FontWeight.w600)),
                              const SizedBox(height: 2),
                              Text(last.text,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(color: C.muted, fontSize: 13)),
                            ]),
                          ),
                          const SizedBox(width: 8),
                          Text('${dayLabel(c.updatedAt, now)}\n${hm(c.updatedAt)}',
                              textAlign: TextAlign.right, style: TextStyle(color: C.muted, fontSize: 11)),
                        ]),
                      ),
                    );
                  },
                ),
        );
      },
    );
  }
}
