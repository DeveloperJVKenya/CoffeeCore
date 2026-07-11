import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:coffeecore/utils/role_utils.dart';

class MessagingScreen extends StatefulWidget {
  final String cooperativeName;
  final String? initialChat;

  const MessagingScreen({
    super.key,
    required this.cooperativeName,
    this.initialChat,
  });

  @override
  State<MessagingScreen> createState() => _MessagingScreenState();
}

class _MessagingScreenState extends State<MessagingScreen> {
  String? _userId;
  String? _userRole;
  String? _selectedChat;

  @override
  void initState() {
    super.initState();
    _userId = FirebaseAuth.instance.currentUser?.uid;
    _selectedChat = widget.initialChat;
    _checkUserRole();
  }

  Future<void> _checkUserRole() async {
    if (_userId == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No authenticated user found')),
        );
      }
      return;
    }
    try {
      String role =
          await RoleUtils.getUserRole(_userId!, widget.cooperativeName);
      if (mounted) {
        setState(() {
          _userRole = role;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error checking user role: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    String formattedCoopName = widget.cooperativeName.replaceAll(' ', '_');
    final chatGroups = [
      {
        'name': '${widget.cooperativeName} Management',
        'id': '${formattedCoopName}_Management'
      },
      {
        'name': '${widget.cooperativeName} Users',
        'id': '${formattedCoopName}_Users'
      },
    ];

    return Scaffold(
      appBar: AppBar(
        title: Text(
          '${widget.cooperativeName} Messages',
          style:
              const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.brown[700],
        foregroundColor: Colors.white,
      ),
      body: _userId == null
          ? const Center(child: Text('Please sign in to view messages.'))
          : _userRole == null
              ? const Center(child: CircularProgressIndicator())
              : _userRole == 'None'
                  ? const Center(
                      child: Text(
                          'No role assigned for this cooperative. Contact admin.'))
                  : _selectedChat == null
                      ? ListView.builder(
                          itemCount: chatGroups.length,
                          itemBuilder: (context, index) {
                            final chat = chatGroups[index];
                            bool canAccess = _userRole == 'Main Admin' ||
                                _userRole == 'Coop Admin' ||
                                (_userRole == 'Market Manager' &&
                                    chat['id'] ==
                                        '${formattedCoopName}_Management') ||
                                (_userRole == 'User' &&
                                    chat['id'] == '${formattedCoopName}_Users');
                            return canAccess
                                ? ListTile(
                                    leading: Icon(Icons.group,
                                        color: Colors.brown[700]),
                                    title: Text(chat['name']!),
                                    onTap: () {
                                      setState(() {
                                        _selectedChat = chat['id'];
                                      });
                                    },
                                  )
                                : const SizedBox.shrink();
                          },
                        )
                      : ChatScreen(
                          cooperativeName: widget.cooperativeName,
                          chatId: _selectedChat!,
                          userId: _userId!,
                          userRole: _userRole!,
                        ),
    );
  }
}

class ChatScreen extends StatefulWidget {
  final String cooperativeName;
  final String chatId;
  final String userId;
  final String userRole;

  const ChatScreen({
    super.key,
    required this.cooperativeName,
    required this.chatId,
    required this.userId,
    required this.userRole,
  });

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final Set<String> _deletedForMe = {};

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _sendMessage() async {
    if (_messageController.text.trim().isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Message cannot be empty')),
        );
      }
      return;
    }
    try {
      String formattedCoopName = widget.cooperativeName.replaceAll(' ', '_');
      await FirebaseFirestore.instance
          .collection('messages')
          .doc(formattedCoopName)
          .collection(widget.chatId)
          .add({
        'senderId': widget.userId,
        'message': _messageController.text.trim(),
        'timestamp': Timestamp.now(),
        'isDeleted': false,
      });
      _messageController.clear();
      _scrollToBottom();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error sending message: $e')),
        );
      }
    }
  }

  Future<void> _deleteMessage(String messageId, bool forEveryone) async {
    String formattedCoopName = widget.cooperativeName.replaceAll(' ', '_');
    try {
      if (forEveryone) {
        await FirebaseFirestore.instance
            .collection('messages')
            .doc(formattedCoopName)
            .collection(widget.chatId)
            .doc(messageId)
            .update({'isDeleted': true});
      } else {
        setState(() {
          _deletedForMe.add(messageId);
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error deleting message: $e')),
        );
      }
    }
  }

  Future<void> _restoreMessage(String messageId) async {
    String formattedCoopName = widget.cooperativeName.replaceAll(' ', '_');
    try {
      await FirebaseFirestore.instance
          .collection('messages')
          .doc(formattedCoopName)
          .collection(widget.chatId)
          .doc(messageId)
          .update({'isDeleted': false});
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error restoring message: $e')),
        );
      }
    }
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent + 100,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    String formattedCoopName = widget.cooperativeName.replaceAll(' ', '_');
    return Column(
      children: [
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('messages')
                .doc(formattedCoopName)
                .collection(widget.chatId)
                .orderBy('timestamp', descending: false)
                .limit(50)
                .snapshots(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              if (snapshot.hasError) {
                return Center(
                    child: Text('Error loading messages: ${snapshot.error}'));
              }
              if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                return const Center(
                  child: Text(
                    'No messages yet. Start the conversation!',
                    style: TextStyle(fontSize: 16, color: Colors.grey),
                  ),
                );
              }

              final messages = snapshot.data!.docs;
              WidgetsBinding.instance
                  .addPostFrameCallback((_) => _scrollToBottom());
              return ListView.builder(
                controller: _scrollController,
                itemCount: messages.length,
                itemBuilder: (context, index) {
                  final messageDoc = messages[index];
                  final message = messageDoc.data() as Map<String, dynamic>;
                  final messageId = messageDoc.id;
                  final isMe = message['senderId'] == widget.userId;
                  final isDeleted = message['isDeleted'] == true;

                  if (_deletedForMe.contains(messageId) ||
                      (isDeleted &&
                          widget.userRole != 'Coop Admin' &&
                          widget.userRole != 'Main Admin')) {
                    return const SizedBox.shrink();
                  }

                  return FutureBuilder<String>(
                    future: RoleUtils.getUserRole(
                        message['senderId'], widget.cooperativeName),
                    builder: (context, roleSnapshot) {
                      if (roleSnapshot.connectionState ==
                          ConnectionState.waiting) {
                        return const SizedBox.shrink();
                      }
                      if (roleSnapshot.hasError) {
                        return const SizedBox.shrink();
                      }
                      final senderRole = roleSnapshot.data ?? 'User';
                      final isAdminMessage = senderRole == 'Coop Admin' &&
                          widget.chatId.contains('_Management');

                      return GestureDetector(
                        onLongPress: () {
                          if (isMe ||
                              widget.userRole == 'Coop Admin' ||
                              widget.userRole == 'Main Admin') {
                            showModalBottomSheet(
                              context: context,
                              builder: (context) => Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  if (isMe)
                                    ListTile(
                                      leading: const Icon(Icons.delete),
                                      title: const Text('Delete for Me'),
                                      onTap: () {
                                        _deleteMessage(messageId, false);
                                        Navigator.pop(context);
                                      },
                                    ),
                                  if (isMe)
                                    ListTile(
                                      leading: const Icon(Icons.delete_forever),
                                      title: const Text('Delete for Everyone'),
                                      onTap: () {
                                        _deleteMessage(messageId, true);
                                        Navigator.pop(context);
                                      },
                                    ),
                                  if ((widget.userRole == 'Coop Admin' ||
                                          widget.userRole == 'Main Admin') &&
                                      isDeleted)
                                    ListTile(
                                      leading: const Icon(Icons.restore),
                                      title: const Text('Restore Message'),
                                      onTap: () {
                                        _restoreMessage(messageId);
                                        Navigator.pop(context);
                                      },
                                    ),
                                ],
                              ),
                            );
                          }
                        },
                        child: Align(
                          alignment: isMe
                              ? Alignment.centerRight
                              : Alignment.centerLeft,
                          child: Container(
                            margin: const EdgeInsets.symmetric(
                                vertical: 4, horizontal: 8),
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: isMe
                                  ? const Color(0xFF006400)
                                  : isAdminMessage
                                      ? Colors.brown[900]
                                      : const Color(0xFF333333),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              message['message'] ?? '',
                              style: const TextStyle(color: Colors.white),
                            ),
                          ),
                        ),
                      );
                    },
                  );
                },
              );
            },
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(8.0),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _messageController,
                  decoration: InputDecoration(
                    hintText: 'Type a message...',
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12)),
                    filled: true,
                    fillColor: Colors.white,
                  ),
                ),
              ),
              IconButton(
                icon: Icon(Icons.send, color: Colors.brown[700]),
                onPressed: _sendMessage,
              ),
            ],
          ),
        ),
      ],
    );
  }
}
