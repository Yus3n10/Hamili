class ChatMessage {
  final String role; // "user" | "assistant"
  final String content;
  // True when this assistant reply performed an action (e.g. added a goal),
  // so the UI can show a "✓ Done" chip.
  final bool actionDone;
  const ChatMessage(this.role, this.content, {this.actionDone = false});
}
