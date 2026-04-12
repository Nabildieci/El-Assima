import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _messageController = TextEditingController();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  
  String _pseudo = "";
  final TextEditingController _pseudoController = TextEditingController();
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadPseudo();
  }

  Future<void> _loadPseudo() async {
    final prefs = await SharedPreferences.getInstance();
    final savedPseudo = prefs.getString('user_pseudo');
    if (savedPseudo != null && savedPseudo.isNotEmpty) {
      setState(() {
        _pseudo = savedPseudo;
        _isLoading = false;
      });
    } else {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _savePseudo(String name) async {
    if (name.trim().isEmpty) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('user_pseudo', name.trim());
    setState(() {
      _pseudo = name.trim();
    });
  }

  Future<void> _sendMessage() async {
    if (_messageController.text.trim().isNotEmpty && _pseudo.isNotEmpty) {
      final text = _messageController.text.trim();
      _messageController.clear();
      
      await _firestore.collection('messages').add({
        'text': text,
        'sender': _pseudo,
        'timestamp': FieldValue.serverTimestamp(),
      });
    }
  }

  @override
  void dispose() {
    _messageController.dispose();
    _pseudoController.dispose();
    super.dispose();
  }

  Widget _buildPseudoSetup() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Container(
          padding: const EdgeInsets.all(24.0),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: BorderRadius.circular(16),
            boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 10)],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.account_circle, size: 80, color: Theme.of(context).colorScheme.primary),
              const SizedBox(height: 20),
              const Text('Choisissez votre nom de supporter', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold), textAlign: TextAlign.center),
              const SizedBox(height: 20),
              TextField(
                controller: _pseudoController,
                decoration: InputDecoration(
                  labelText: 'Votre Pseudo',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onSubmitted: _savePseudo,
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: () => _savePseudo(_pseudoController.text),
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 50),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text('Rejoindre le chat', style: TextStyle(fontSize: 16)),
              )
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const Center(child: CircularProgressIndicator());
    if (_pseudo.isEmpty) return _buildPseudoSetup();

    return Column(
      children: [
        // Zone des messages Firebase
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: _firestore.collection('messages').orderBy('timestamp', descending: true).snapshots(),
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return Center(child: Text('Erreur: ${snapshot.error}'));
              }
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              
              final docs = snapshot.data?.docs ?? [];
              
              if (docs.isEmpty) {
                return const Center(child: Text('Aucun message. Soyez le premier à parler !'));
              }

              return ListView.builder(
                reverse: true, // Affiche du bas vers le haut
                padding: const EdgeInsets.all(16.0),
                itemCount: docs.length,
                itemBuilder: (context, index) {
                  final data = docs[index].data() as Map<String, dynamic>;
                  final isMe = data['sender'] == _pseudo;
                  return ChatBubble(
                    text: data['text'] ?? '',
                    sender: data['sender'] ?? 'Anonyme',
                    isMe: isMe,
                  );
                },
              );
            },
          ),
        ),
        // Zone de saisie
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 10.0),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 10,
                offset: const Offset(0, -5),
              )
            ],
          ),
          child: SafeArea(
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _messageController,
                    decoration: InputDecoration(
                      hintText: 'Écrire un message...',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24.0),
                        borderSide: BorderSide.none,
                      ),
                      filled: true,
                      fillColor: Colors.grey.withOpacity(0.1),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 12.0),
                    ),
                    onSubmitted: (_) => _sendMessage(),
                  ),
                ),
                const SizedBox(width: 8),
                CircleAvatar(
                  backgroundColor: Theme.of(context).colorScheme.primary,
                  radius: 24,
                  child: IconButton(
                    icon: const Icon(Icons.send, color: Colors.white),
                    onPressed: _sendMessage,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class ChatBubble extends StatelessWidget {
  final String text;
  final String sender;
  final bool isMe;

  const ChatBubble({super.key, required this.text, required this.sender, required this.isMe});

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12.0),
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
        decoration: BoxDecoration(
          color: isMe ? Theme.of(context).colorScheme.primary : Theme.of(context).colorScheme.tertiaryContainer,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(16.0),
            topRight: const Radius.circular(16.0),
            bottomLeft: Radius.circular(isMe ? 16.0 : 0),
            bottomRight: Radius.circular(isMe ? 0 : 16.0),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (!isMe) ...[
              Text(
                sender,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                  color: Theme.of(context).colorScheme.onTertiaryContainer.withOpacity(0.7),
                ),
              ),
              const SizedBox(height: 4),
            ],
            Text(
              text,
              style: TextStyle(
                color: isMe ? Colors.white : Theme.of(context).colorScheme.onTertiaryContainer,
                fontSize: 16,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
