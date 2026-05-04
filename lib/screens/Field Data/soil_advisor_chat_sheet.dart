import 'package:coffeecore/screens/Field%20Data/gemini_soil_ai_service.dart';
import 'package:flutter/material.dart';

/// ⑥ Soil Advisor Chat — a DraggableScrollableSheet bottom sheet that injects
/// the farmer's current soil readings as silent context into every Gemini call.
class SoilAdvisorChatSheet extends StatefulWidget {
  final Map<String, double>? currentNutrients;
  final String? stage;
  final String? soilType;

  const SoilAdvisorChatSheet({
    this.currentNutrients,
    this.stage,
    this.soilType,
    super.key,
  });

  /// Convenience static helper — call this from any FAB.
  static Future<void> show(
    BuildContext context, {
    Map<String, double>? currentNutrients,
    String? stage,
    String? soilType,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => SoilAdvisorChatSheet(
        currentNutrients: currentNutrients,
        stage: stage,
        soilType: soilType,
      ),
    );
  }

  @override
  State<SoilAdvisorChatSheet> createState() => _SoilAdvisorChatSheetState();
}

class _SoilAdvisorChatSheetState extends State<SoilAdvisorChatSheet> {
  final _controller = TextEditingController();
  final _scrollController = ScrollController();

  /// Visible chat bubbles: [{role: 'user'|'model', text: '...'}]
  final List<Map<String, String>> _messages = [];

  /// History sent to Gemini for multi-turn context.
  final List<Map<String, String>> _history = [];

  bool _isLoading = false;

  static const _suggestions = [
    'Why does my coffee have yellow leaves even though nitrogen looks fine?',
    'Should I apply lime before or after the short rains?',
    'What does a Ca:Mg ratio of 15:1 mean for my trees?',
    'How do I know if low pH is blocking my phosphorus uptake?',
  ];

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  // ── Send ─────────────────────────────────────────────────────────────────

  Future<void> _sendMessage() async {
    final text = _controller.text.trim();
    if (text.isEmpty || _isLoading) return;

    setState(() {
      _messages.add({'role': 'user', 'text': text});
      _isLoading = true;
    });
    _controller.clear();
    _scrollToBottom();

    final answer = await GeminiSoilAiService.askSoilAdvisor(
      question: text,
      currentNutrients: widget.currentNutrients,
      stage: widget.stage,
      soilType: widget.soilType,
      conversationHistory: List.from(_history),
    );

    // Update history for next turn.
    _history.add({'role': 'user', 'text': text});

    if (!mounted) return;
    setState(() {
      final reply = answer ??
          'Sorry, I couldn\'t reach the advisor right now. '
              'Please check your internet connection and try again.';
      _messages.add({'role': 'model', 'text': reply});
      if (answer != null) _history.add({'role': 'model', 'text': answer});
      _isLoading = false;
    });

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

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.75,
      minChildSize: 0.4,
      maxChildSize: 0.95,
      builder: (_, __) => Container(
        decoration: const BoxDecoration(
          color: Color(0xFFF5E8C7),
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          children: [
            _buildHandle(),
            _buildHeader(),
            if (widget.currentNutrients != null &&
                widget.currentNutrients!.isNotEmpty)
              _buildContextBanner(),
            Expanded(
              child: _messages.isEmpty
                  ? _buildEmptyState()
                  : _buildMessageList(),
            ),
            _buildInputBar(),
          ],
        ),
      ),
    );
  }

  Widget _buildHandle() => Container(
        margin: const EdgeInsets.symmetric(vertical: 8),
        width: 40,
        height: 4,
        decoration: BoxDecoration(
          color: Colors.grey[400],
          borderRadius: BorderRadius.circular(2),
        ),
      );

  Widget _buildHeader() => Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: const BoxDecoration(
          color: Color(0xFF3C2F2F),
        ),
        child: Row(
          children: [
            const CircleAvatar(
              radius: 18,
              backgroundColor: Color(0xFF3A5F0B),
              child: Icon(Icons.eco, size: 18, color: Colors.white),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Soil Advisor',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold),
                  ),
                  Text(
                    'Ask me anything about your coffee soil',
                    style: TextStyle(color: Colors.white60, fontSize: 12),
                  ),
                ],
              ),
            ),
            IconButton(
              icon: const Icon(Icons.close, color: Colors.white),
              onPressed: () => Navigator.pop(context),
            ),
          ],
        ),
      );

  Widget _buildContextBanner() => Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        color: const Color(0xFFE8D5B0),
        child: Row(
          children: [
            const Icon(Icons.info_outline,
                size: 14, color: Color(0xFF4A2C2A)),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                'Using your current soil readings as context'
                '${widget.soilType != null ? " — ${widget.soilType} soil" : ""}',
                style: const TextStyle(
                    fontSize: 12, color: Color(0xFF4A2C2A)),
              ),
            ),
          ],
        ),
      );

  Widget _buildEmptyState() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          const SizedBox(height: 16),
          const Icon(Icons.chat_bubble_outline,
              size: 52, color: Color(0xFF3A5F0B)),
          const SizedBox(height: 12),
          const Text(
            'Ask anything about your coffee soil',
            style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Color(0xFF4A2C2A)),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            'Try one of these questions:',
            style: TextStyle(fontSize: 13, color: Colors.grey[600]),
          ),
          const SizedBox(height: 16),
          ..._suggestions.map(
            (s) => GestureDetector(
              onTap: () {
                _controller.text = s;
                _sendMessage();
              },
              child: Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                      color: const Color(0xFF3A5F0B).withValues(alpha: 0.3)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.lightbulb_outline,
                        size: 16, color: Color(0xFF3A5F0B)),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        s,
                        style: const TextStyle(
                            fontSize: 13, color: Color(0xFF4A2C2A)),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMessageList() => ListView.builder(
        controller: _scrollController,
        padding: const EdgeInsets.all(16),
        itemCount: _messages.length + (_isLoading ? 1 : 0),
        itemBuilder: (_, i) {
          if (i == _messages.length) return _buildTypingIndicator();
          final msg = _messages[i];
          return _buildBubble(
              isUser: msg['role'] == 'user', text: msg['text']!);
        },
      );

  Widget _buildBubble({required bool isUser, required String text}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment:
            isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!isUser) ...[
            const CircleAvatar(
              radius: 16,
              backgroundColor: Color(0xFF3A5F0B),
              child: Icon(Icons.eco, size: 14, color: Colors.white),
            ),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: isUser ? const Color(0xFF4A2C2A) : Colors.white,
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(16),
                  topRight: const Radius.circular(16),
                  bottomLeft: Radius.circular(isUser ? 16 : 4),
                  bottomRight: Radius.circular(isUser ? 4 : 16),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.08),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              // SelectableText lets farmers long-press to copy advisor
              // responses — particularly useful now that answers are longer.
              child: SelectableText(
                text,
                style: TextStyle(
                  color: isUser ? Colors.white : const Color(0xFF3A3A3A),
                  fontSize: 14,
                  height: 1.5,
                ),
              ),
            ),
          ),
          if (isUser) const SizedBox(width: 8),
        ],
      ),
    );
  }

  Widget _buildTypingIndicator() => Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          children: [
            const CircleAvatar(
              radius: 16,
              backgroundColor: Color(0xFF3A5F0B),
              child: Icon(Icons.eco, size: 14, color: Colors.white),
            ),
            const SizedBox(width: 8),
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(16),
                  topRight: Radius.circular(16),
                  bottomRight: Radius.circular(16),
                  bottomLeft: Radius.circular(4),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.08),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _TypingDot(delay: 0),
                  const SizedBox(width: 4),
                  _TypingDot(delay: 200),
                  const SizedBox(width: 4),
                  _TypingDot(delay: 400),
                ],
              ),
            ),
          ],
        ),
      );

  Widget _buildInputBar() => Container(
        padding: EdgeInsets.only(
          left: 12,
          right: 12,
          bottom: MediaQuery.of(context).viewInsets.bottom + 12,
          top: 8,
        ),
        decoration: BoxDecoration(
          color: const Color(0xFFF0E4D7),
          border: Border(top: BorderSide(color: Colors.grey[300]!)),
        ),
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: _controller,
                decoration: InputDecoration(
                  hintText: 'Ask about your soil...',
                  hintStyle: TextStyle(color: Colors.grey[500]),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24),
                    borderSide: BorderSide(color: Colors.grey[300]!),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24),
                    borderSide: BorderSide(color: Colors.grey[300]!),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24),
                    borderSide:
                        const BorderSide(color: Color(0xFF3A5F0B)),
                  ),
                  filled: true,
                  fillColor: Colors.white,
                  contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 10),
                ),
                maxLines: 3,
                minLines: 1,
                textInputAction: TextInputAction.newline,
              ),
            ),
            const SizedBox(width: 8),
            GestureDetector(
              onTap: _isLoading ? null : _sendMessage,
              child: Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: _isLoading
                      ? Colors.grey[400]
                      : const Color(0xFF4A2C2A),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.send,
                    color: Colors.white, size: 20),
              ),
            ),
          ],
        ),
      );
}

// ── Animated typing dots ─────────────────────────────────────────────────────

/// A single pulsing dot used in the typing indicator.
/// The [delay] parameter staggers each dot's animation in milliseconds.
class _TypingDot extends StatefulWidget {
  final int delay;
  const _TypingDot({required this.delay});

  @override
  State<_TypingDot> createState() => _TypingDotState();
}

class _TypingDotState extends State<_TypingDot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _anim = Tween<double>(begin: 0.3, end: 1.0).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut),
    );
    Future.delayed(Duration(milliseconds: widget.delay), () {
      if (mounted) _ctrl.repeat(reverse: true);
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _anim,
      child: Container(
        width: 8,
        height: 8,
        decoration: const BoxDecoration(
          color: Color(0xFF3A5F0B),
          shape: BoxShape.circle,
        ),
      ),
    );
  }
}