class ChatMessage {
  final String role; // "user" | "assistant"
  final String content;
  const ChatMessage(this.role, this.content);
}
