import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
// ✅ FIX 1 — replaced deprecated 'firebase_vertexai' with the new 'firebase_ai' package
import 'package:firebase_ai/firebase_ai.dart';

// ─────────────────────────────────────────────
//  DATA MODELS
// ─────────────────────────────────────────────

enum MessageSender { user, ai }

class ChatMessage {
  final String text;
  final MessageSender sender;
  final DateTime timestamp;
  final bool isLoading;

  const ChatMessage({
    required this.text,
    required this.sender,
    required this.timestamp,
    this.isLoading = false,
  });
}

// ─────────────────────────────────────────────
//  COFFEE AI CHAT SCREEN
// ─────────────────────────────────────────────

class CoffeeAIChatScreen extends StatefulWidget {
  const CoffeeAIChatScreen({super.key});

  @override
  CoffeeAIChatScreenState createState() => CoffeeAIChatScreenState();
}

class CoffeeAIChatScreenState extends State<CoffeeAIChatScreen>
    with TickerProviderStateMixin {
  // ── State ──────────────────────────────────
  final List<ChatMessage> _messages = [];
  final TextEditingController _inputController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  bool _isTyping = false;

  // ── Gemini via Firebase AI (Google AI backend) ──────────
  late final GenerativeModel _model;
  late final ChatSession _chatSession;

  // ── Animation ─────────────────────────────
  late AnimationController _dotAnimController;

  // ── System prompt scoped to coffee farming ─
  static const String _systemInstruction = '''
You are CoffeeCore AI, an expert agricultural assistant specialised exclusively 
in coffee farming. You help farmers with planting, pest control, disease 
management, soil nutrition, harvesting, nursery management, and market advice.

Guidelines:
- Answer ONLY coffee-farming related questions.
- If asked about unrelated topics, politely redirect the user back to coffee farming.
- Use simple, practical language suitable for smallholder farmers.
- Where relevant, reference local Kenyan coffee context (CRI varieties, Kenya highlands, etc.).
- Keep responses concise but actionable — use bullet points when listing steps.
- Always be encouraging and supportive.
''';

  // ── Suggested Starter Queries ──────────────
  final List<String> _suggestions = [
    '☕ Best variety for highlands?',
    '🐛 How to control Coffee Berry Borer?',
    '🌿 Signs of Coffee Leaf Rust?',
    '💧 Irrigation tips for dry season',
    '🧪 Soil pH for Arabica?',
  ];

  // ─────────────────────────────────────────────────────────────────────────
  //  LIFECYCLE
  // ─────────────────────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    _initGemini();
    _dotAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat();
    _addWelcomeMessage();
  }

  @override
  void dispose() {
    _inputController.dispose();
    _scrollController.dispose();
    _dotAnimController.dispose();
    super.dispose();
  }

  // ─────────────────────────────────────────────────────────────────────────
  //  INIT GEMINI  (Firebase AI — Google AI / Gemini Developer API)
  // ─────────────────────────────────────────────────────────────────────────

  void _initGemini() {
    // ✅ FIX 2 — use FirebaseAI.googleAI() instead of FirebaseVertexAI.instance
    //    This uses the Gemini Developer API (free tier, no billing required).
    //    Your old code used the Vertex AI backend which needs extra project setup
    //    and a Blaze billing plan — that's why you got the "model not found" error.
    _model = FirebaseAI.googleAI().generativeModel(
      // ✅ gemini-2.5-flash — the stable, confirmed model name for Firebase AI Logic.
      //    No preview suffix or date suffix. Works on the Gemini Developer API free tier.
      //    Source: https://firebase.google.com/docs/ai-logic/models
      model: 'gemini-2.5-flash',
      systemInstruction: Content.system(_systemInstruction),
      generationConfig: GenerationConfig(
        temperature: 0.7,
        maxOutputTokens: 1024,
      ),
    );
    _chatSession = _model.startChat();
  }

  // ─────────────────────────────────────────────────────────────────────────
  //  WELCOME MESSAGE
  // ─────────────────────────────────────────────────────────────────────────

  void _addWelcomeMessage() {
    _messages.add(
      ChatMessage(
        text:
            "👋 Hello! I'm **CoffeeCore AI**, your personal coffee farming assistant.\n\n"
            "Ask me anything about growing, nurturing, or harvesting coffee — "
            "from soil prep to pest control. How can I help you today?",
        sender: MessageSender.ai,
        timestamp: DateTime.now(),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  //  SEND MESSAGE
  // ─────────────────────────────────────────────────────────────────────────

  Future<void> _sendMessage(String text) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty || _isTyping) return;

    _inputController.clear();

    // Add user bubble
    setState(() {
      _messages.add(ChatMessage(
        text: trimmed,
        sender: MessageSender.user,
        timestamp: DateTime.now(),
      ));
      _isTyping = true;
    });

    _scrollToBottom();

    // Add loading bubble
    setState(() {
      _messages.add(ChatMessage(
        text: '',
        sender: MessageSender.ai,
        timestamp: DateTime.now(),
        isLoading: true,
      ));
    });

    _scrollToBottom();

    try {
      final response = await _chatSession.sendMessage(
        Content.text(trimmed),
      );

      final aiText =
          response.text ?? "I'm sorry, I couldn't process that. Please try again.";

      setState(() {
        _messages.removeLast(); // remove loading bubble
        _messages.add(ChatMessage(
          text: aiText,
          sender: MessageSender.ai,
          timestamp: DateTime.now(),
        ));
        _isTyping = false;
      });
    } catch (e) {
      setState(() {
        _messages.removeLast(); // remove loading bubble
        _messages.add(ChatMessage(
          text:
              "⚠️ Oops! Something went wrong connecting to the AI. Please check your internet connection and try again.\n\nError: ${e.toString()}",
          sender: MessageSender.ai,
          timestamp: DateTime.now(),
        ));
        _isTyping = false;
      });
    }

    _scrollToBottom();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  // ─────────────────────────────────────────────────────────────────────────
  //  BUILD
  // ─────────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5E8C7),
      appBar: _buildAppBar(),
      body: Column(
        children: [
          Expanded(child: _buildMessageList()),
          _buildSuggestionChips(),
          _buildInputBar(),
        ],
      ),
    );
  }

  // ── AppBar ─────────────────────────────────

  AppBar _buildAppBar() {
    return AppBar(
      backgroundColor: const Color(0xFF3E2723),
      elevation: 0,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back, color: Colors.white),
        onPressed: () => Navigator.pop(context),
      ),
      title: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: const Color(0xFFFFCC80),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.smart_toy_rounded,
                color: Color(0xFF3E2723), size: 22),
          ),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'CoffeeCore AI',
                style: GoogleFonts.poppins(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                _isTyping ? 'Thinking...' : 'Coffee Farming Expert',
                style: GoogleFonts.poppins(
                  color: const Color(0xFFFFCC80),
                  fontSize: 11,
                ),
              ),
            ],
          ),
        ],
      ),
      actions: [
        IconButton(
          icon: const Icon(Icons.refresh_rounded, color: Colors.white),
          tooltip: 'New conversation',
          onPressed: () {
            setState(() {
              _messages.clear();
              _initGemini();
              _addWelcomeMessage();
            });
          },
        ),
        const SizedBox(width: 4),
      ],
    );
  }

  // ── Message List ───────────────────────────

  Widget _buildMessageList() {
    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      itemCount: _messages.length,
      itemBuilder: (context, index) {
        final msg = _messages[index];
        return _MessageBubble(
          message: msg,
          dotAnimController: _dotAnimController,
        );
      },
    );
  }

  // ── Suggestion Chips ───────────────────────

  Widget _buildSuggestionChips() {
    if (_messages.length > 2) return const SizedBox.shrink();
    return Container(
      color: const Color(0xFFF5E8C7),
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 4),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: _suggestions.map((s) {
            return GestureDetector(
              onTap: () => _sendMessage(s),
              child: Container(
                margin: const EdgeInsets.only(right: 8),
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: const Color(0xFF3E2723), width: 1.5),
                  boxShadow: const [
                    BoxShadow(
                        color: Colors.black12, blurRadius: 3, offset: Offset(0, 1)),
                  ],
                ),
                child: Text(
                  s,
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    color: const Color(0xFF3E2723),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  // ── Input Bar ──────────────────────────────

  Widget _buildInputBar() {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 16),
      decoration: const BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(color: Colors.black12, blurRadius: 8, offset: Offset(0, -2)),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: const Color(0xFFF5E8C7),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: const Color(0xFF3E2723), width: 1.5),
                ),
                child: TextField(
                  controller: _inputController,
                  maxLines: null,
                  keyboardType: TextInputType.multiline,
                  textCapitalization: TextCapitalization.sentences,
                  style: GoogleFonts.poppins(
                      fontSize: 14, color: const Color(0xFF3E2723)),
                  decoration: InputDecoration(
                    hintText: 'Ask about coffee farming...',
                    hintStyle: GoogleFonts.poppins(
                        fontSize: 14, color: Colors.brown.shade300),
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 10),
                    border: InputBorder.none,
                  ),
                  onSubmitted: (v) => _sendMessage(v),
                ),
              ),
            ),
            const SizedBox(width: 8),
            GestureDetector(
              onTap: () => _sendMessage(_inputController.text),
              child: Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: const Color(0xFF3E2723),
                  borderRadius: BorderRadius.circular(23),
                  boxShadow: const [
                    BoxShadow(
                        color: Colors.black26, blurRadius: 4, offset: Offset(0, 2)),
                  ],
                ),
                child: const Icon(Icons.send_rounded,
                    color: Colors.white, size: 20),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
//  MESSAGE BUBBLE WIDGET
// ─────────────────────────────────────────────

class _MessageBubble extends StatelessWidget {
  final ChatMessage message;
  final AnimationController dotAnimController;

  const _MessageBubble({
    required this.message,
    required this.dotAnimController,
  });

  bool get _isUser => message.sender == MessageSender.user;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        mainAxisAlignment:
            _isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!_isUser) _buildAvatar(),
          const SizedBox(width: 8),
          Flexible(child: _buildBubble()),
          const SizedBox(width: 8),
          if (_isUser) _buildUserAvatar(),
        ],
      ),
    );
  }

  Widget _buildAvatar() {
    return Container(
      width: 32,
      height: 32,
      decoration: BoxDecoration(
        color: const Color(0xFF3E2723),
        borderRadius: BorderRadius.circular(8),
      ),
      child: const Icon(Icons.smart_toy_rounded, color: Color(0xFFFFCC80), size: 18),
    );
  }

  Widget _buildUserAvatar() {
    return Container(
      width: 32,
      height: 32,
      decoration: BoxDecoration(
        color: const Color(0xFFFFCC80),
        borderRadius: BorderRadius.circular(8),
      ),
      child: const Icon(Icons.person, color: Color(0xFF3E2723), size: 18),
    );
  }

  Widget _buildBubble() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      constraints: const BoxConstraints(maxWidth: 280),
      decoration: BoxDecoration(
        color: _isUser ? const Color(0xFF3E2723) : Colors.white,
        borderRadius: BorderRadius.only(
          topLeft: const Radius.circular(16),
          topRight: const Radius.circular(16),
          bottomLeft: Radius.circular(_isUser ? 16 : 4),
          bottomRight: Radius.circular(_isUser ? 4 : 16),
        ),
        boxShadow: const [
          BoxShadow(color: Colors.black12, blurRadius: 4, offset: Offset(0, 2)),
        ],
      ),
      child: message.isLoading ? _buildTypingIndicator() : _buildText(),
    );
  }

  Widget _buildText() {
    // Simple bold-text renderer: **text** → bold
    final raw = message.text;
    final spans = <TextSpan>[];
    final parts = raw.split('**');
    for (int i = 0; i < parts.length; i++) {
      spans.add(TextSpan(
        text: parts[i],
        style: TextStyle(
          fontWeight: i.isOdd ? FontWeight.bold : FontWeight.normal,
          color: _isUser ? Colors.white : const Color(0xFF3E2723),
          fontSize: 14,
          height: 1.5,
        ),
      ));
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        RichText(
          text: TextSpan(
            style: GoogleFonts.poppins(),
            children: spans,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          _formatTime(message.timestamp),
          style: GoogleFonts.poppins(
            fontSize: 10,
            color: _isUser
                ? Colors.white.withValues(alpha: 0.6)
                : Colors.brown.shade300,
          ),
        ),
      ],
    );
  }

  Widget _buildTypingIndicator() {
    return AnimatedBuilder(
      animation: dotAnimController,
      builder: (context, _) {
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(3, (i) {
            final delay = i * 0.33;
            final t = ((dotAnimController.value - delay) % 1.0).clamp(0.0, 1.0);
            final opacity = (0.3 + 0.7 * (1 - (2 * t - 1).abs())).clamp(0.0, 1.0);
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 3),
              child: Opacity(
                opacity: opacity,
                child: Container(
                  width: 8,
                  height: 8,
                  decoration: const BoxDecoration(
                    color: Color(0xFF3E2723),
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            );
          }),
        );
      },
    );
  }

  String _formatTime(DateTime dt) {
    final h = dt.hour.toString().padLeft(2, '0');
    final m = dt.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }
}

// ─────────────────────────────────────────────
//  NAVIGATION HELPER
// ─────────────────────────────────────────────

void navigateToCoffeeAIChat(BuildContext context) {
  Navigator.push(
    context,
    MaterialPageRoute(builder: (_) => const CoffeeAIChatScreen()),
  );
}