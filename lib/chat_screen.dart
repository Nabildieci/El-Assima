import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'package:record/record.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _messageController = TextEditingController();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;
  
  String _pseudo = "";
  final TextEditingController _pseudoController = TextEditingController();
  bool _isLoading = true;
  bool _isUploading = false;

  // Media
  final ImagePicker _picker = ImagePicker();
  
  // Audio
  late final AudioRecorder _audioRecorder;
  bool _isRecording = false;
  String? _recordingPath;

  @override
  void initState() {
    super.initState();
    _audioRecorder = AudioRecorder();
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

  Future<String?> _uploadFile(File file, String folder) async {
    try {
      final fileName = DateTime.now().millisecondsSinceEpoch.toString() + '_' + file.path.split('/').last;
      final ref = _storage.ref().child('chat/$folder/$fileName');
      final uploadTask = await ref.putFile(file);
      return await uploadTask.ref.getDownloadURL();
    } catch (e) {
      print('Erreur upload: $e');
      return null;
    }
  }

  Future<void> _sendMessage({String? text, String? mediaUrl, String type = 'text', String? localPath}) async {
    if ((text == null || text.trim().isEmpty) && mediaUrl == null && localPath == null) return;
    
    if (text != null && text.trim().isNotEmpty) {
        _messageController.clear();
    }

    // if local path, upload first
    if (localPath != null) {
      setState(() => _isUploading = true);
      mediaUrl = await _uploadFile(File(localPath), type);
      setState(() => _isUploading = false);
      if (mediaUrl == null) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Erreur envoi fichier')));
          return;
      }
    }

    await _firestore.collection('messages').add({
      'text': text ?? '',
      'type': type, // 'text', 'image', 'video', 'audio'
      'mediaUrl': mediaUrl ?? '',
      'sender': _pseudo,
      'timestamp': FieldValue.serverTimestamp(),
    });
  }

  // --- IMAGE & VIDEO ---
  Future<void> _pickMedia() async {
    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.photo),
              title: const Text('Galerie (Image/Video)'),
              onTap: () async {
                Navigator.pop(context);
                final XFile? file = await _picker.pickMedia();
                if (file != null) {
                  final String type = file.path.toLowerCase().endsWith('.mp4') || file.path.toLowerCase().endsWith('.mov') ? 'video' : 'image';
                  _sendMessage(localPath: file.path, type: type);
                }
              },
            ),
            ListTile(
              leading: const Icon(Icons.camera_alt),
              title: const Text('Appareil Photo'),
              onTap: () async {
                Navigator.pop(context);
                final XFile? file = await _picker.pickImage(source: ImageSource.camera);
                if (file != null) {
                  _sendMessage(localPath: file.path, type: 'image');
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  // --- AUDIO ---
  Future<void> _startRecording() async {
    try {
      if (await Permission.microphone.request().isGranted) {
        final Directory tempDir = await getTemporaryDirectory();
        _recordingPath = '${tempDir.path}/audio_${DateTime.now().millisecondsSinceEpoch}.m4a';
        
        await _audioRecorder.start(
          const RecordConfig(encoder: AudioEncoder.aacLc, bitRate: 128000, sampleRate: 44100),
          path: _recordingPath!,
        );
        setState(() => _isRecording = true);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Permission micro refusee')));
      }
    } catch (e) {
      print('Erreur record: $e');
    }
  }

  Future<void> _stopRecording() async {
    try {
      final path = await _audioRecorder.stop();
      setState(() => _isRecording = false);
      if (path != null) {
        _sendMessage(localPath: path, type: 'audio');
      }
    } catch (e) {
      print('Erreur stop record: $e');
    }
  }

  @override
  void dispose() {
    _messageController.dispose();
    _pseudoController.dispose();
    _audioRecorder.dispose();
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
        if (_isUploading)
          const LinearProgressIndicator(),
          
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: _firestore.collection('messages').orderBy('timestamp', descending: true).snapshots(),
            builder: (context, snapshot) {
              if (snapshot.hasError) return Center(child: Text('Erreur: ${snapshot.error}'));
              if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
              
              final docs = snapshot.data?.docs ?? [];
              if (docs.isEmpty) return const Center(child: Text('Aucun message. Soyez le premier a parler !'));

              return ListView.builder(
                reverse: true,
                padding: const EdgeInsets.all(16.0),
                itemCount: docs.length,
                itemBuilder: (context, index) {
                  final data = docs[index].data() as Map<String, dynamic>;
                  final isMe = data['sender'] == _pseudo;
                  return ChatBubble(
                    text: data['text'] ?? '',
                    type: data['type'] ?? 'text',
                    mediaUrl: data['mediaUrl'] ?? '',
                    sender: data['sender'] ?? 'Anonyme',
                    isMe: isMe,
                  );
                },
              );
            },
          ),
        ),
        
        // Input Area
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 10.0),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            boxShadow: [
              BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, -5))
            ],
          ),
          child: SafeArea(
            child: Row(
              children: [
                IconButton(
                  icon: Icon(Icons.camera_alt, color: Theme.of(context).colorScheme.primary),
                  onPressed: _pickMedia,
                ),
                Expanded(
                  child: TextField(
                    controller: _messageController,
                    onChanged: (val) {
                        // Force rebuild to toggle mic/send icon
                        setState((){});
                    },
                    decoration: InputDecoration(
                      hintText: _isRecording ? 'Enregistrement en cours...' : 'Ecrire un message...',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24.0),
                        borderSide: BorderSide.none,
                      ),
                      filled: true,
                      fillColor: _isRecording ? Colors.red.withOpacity(0.1) : Colors.grey.withOpacity(0.1),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 12.0),
                    ),
                    onSubmitted: (val) => _sendMessage(text: val),
                  ),
                ),
                const SizedBox(width: 8),
                GestureDetector(
                  onLongPressStart: (_) {
                      if (_messageController.text.trim().isEmpty) {
                          _startRecording();
                      }
                  },
                  onLongPressEnd: (_) {
                      if (_isRecording) {
                          _stopRecording();
                      }
                  },
                  onTap: () {
                      if (_messageController.text.trim().isNotEmpty) {
                          _sendMessage(text: _messageController.text.trim());
                      }
                  },
                  child: CircleAvatar(
                    backgroundColor: _isRecording ? Colors.red : Theme.of(context).colorScheme.primary,
                    radius: 24,
                    child: Icon(
                      _messageController.text.trim().isEmpty ? Icons.mic : Icons.send,
                      color: Colors.white,
                    ),
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

class ChatBubble extends StatefulWidget {
  final String text;
  final String type;
  final String mediaUrl;
  final String sender;
  final bool isMe;

  const ChatBubble({super.key, required this.text, required this.type, required this.mediaUrl, required this.sender, required this.isMe});

  @override
  State<ChatBubble> createState() => _ChatBubbleState();
}

class _ChatBubbleState extends State<ChatBubble> {
  // Audio
  final AudioPlayer _audioPlayer = AudioPlayer();
  bool _isPlaying = false;
  Duration _duration = Duration.zero;
  Duration _position = Duration.zero;

  @override
  void initState() {
    super.initState();
    if (widget.type == 'audio' && widget.mediaUrl.isNotEmpty) {
        _setupAudio();
    }
  }

  void _setupAudio() {
    _audioPlayer.setSourceUrl(widget.mediaUrl);
    _audioPlayer.onPlayerStateChanged.listen((state) {
      if(mounted) setState(() => _isPlaying = state == PlayerState.playing);
    });
    _audioPlayer.onDurationChanged.listen((newDuration) {
      if(mounted) setState(() => _duration = newDuration);
    });
    _audioPlayer.onPositionChanged.listen((newPosition) {
      if(mounted) setState(() => _position = newPosition);
    });
    _audioPlayer.onPlayerComplete.listen((event) {
        if(mounted) setState(() { _isPlaying = false; _position = Duration.zero; });
    });
  }

  @override
  void dispose() {
    _audioPlayer.dispose();
    super.dispose();
  }

  Widget _buildMediaContent(BuildContext context) {
      if (widget.type == 'text') {
          return Text(
            widget.text,
            style: TextStyle(
              color: widget.isMe ? Colors.white : Theme.of(context).colorScheme.onSurface,
              fontSize: 16,
            ),
          );
      } else if (widget.type == 'image') {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 8.0),
            child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.network(widget.mediaUrl, width: 200, height: 200, fit: BoxFit.cover,
                  loadingBuilder: (context, child, loadingProgress) {
                      if (loadingProgress == null) return child;
                      return const SizedBox(width: 200, height: 200, child: Center(child: CircularProgressIndicator()));
                  },
                ),
            ),
          );
      } else if (widget.type == 'audio') {
          return Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                  IconButton(
                      icon: Icon(_isPlaying ? Icons.pause : Icons.play_arrow, color: widget.isMe ? Colors.white : Theme.of(context).colorScheme.primary),
                      onPressed: () {
                          if (_isPlaying) {
                              _audioPlayer.pause();
                          } else {
                              _audioPlayer.play(UrlSource(widget.mediaUrl));
                          }
                      },
                  ),
                  Slider(
                    activeColor: widget.isMe ? Colors.white : Theme.of(context).colorScheme.primary,
                    inactiveColor: widget.isMe ? Colors.white54 : Colors.grey.withOpacity(0.3),
                    min: 0,
                    max: _duration.inSeconds.toDouble() > 0 ? _duration.inSeconds.toDouble() : 1.0,
                    value: _position.inSeconds.toDouble() <= (_duration.inSeconds.toDouble()>0?_duration.inSeconds.toDouble():1.0) ? _position.inSeconds.toDouble() : 0.0,
                    onChanged: (value) {
                      final position = Duration(seconds: value.toInt());
                      _audioPlayer.seek(position);
                    },
                  ),
                  Text(
                      "${_position.inMinutes}:${(_position.inSeconds % 60).toString().padLeft(2, '0')}",
                      style: TextStyle(color: widget.isMe ? Colors.white : Theme.of(context).colorScheme.onTertiaryContainer, fontSize: 12)
                  ),
              ],
          );
      } else if (widget.type == 'video') {
         return Container(
             padding: const EdgeInsets.all(16),
             color: Colors.black12,
             child: const Row(
                 mainAxisSize: MainAxisSize.min,
                 children: [
                     Icon(Icons.videocam, size: 30),
                     SizedBox(width: 10),
                     Text("Video (telechargez ou ouvrez)"),
                 ]
             )
         );
      }
      return const SizedBox();
  }

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: widget.isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12.0),
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
        decoration: BoxDecoration(
          color: widget.isMe ? Theme.of(context).colorScheme.primary : (Theme.of(context).brightness == Brightness.dark ? Colors.grey[850] : Colors.grey[200]),
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(16.0),
            topRight: const Radius.circular(16.0),
            bottomLeft: Radius.circular(widget.isMe ? 16.0 : 0),
            bottomRight: Radius.circular(widget.isMe ? 0 : 16.0),
          ),
          boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 4, offset: Offset(0, 2))],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (!widget.isMe) ...[
              Text(
                widget.sender,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                  color: Theme.of(context).brightness == Brightness.dark ? Colors.grey[400] : Colors.grey[600],
                ),
              ),
              const SizedBox(height: 4),
            ],
            
            _buildMediaContent(context),
            
            if (widget.text.isNotEmpty && widget.type != 'text') ...[
                const SizedBox(height: 8),
                Text(
                  widget.text,
                  style: TextStyle(
                    color: widget.isMe ? Colors.white : Theme.of(context).colorScheme.onSurface,
                    fontSize: 16,
                  ),
                ),
            ]
          ],
        ),
      ),
    );
  }
}
