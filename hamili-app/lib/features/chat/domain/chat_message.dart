class ChatMessage {
  final String role;
  final String content;


  final bool actionDone;
  const ChatMessage(this.role, this.content, {this.actionDone = false});
}
