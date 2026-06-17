import 'package:coffeecore/screens/Symptom%20Analysis/coffee_symptom_checker_page.dart';
import 'package:coffeecore/screens/diseases/coffee_disease_management_page.dart';
import 'package:coffeecore/screens/pests/coffee_pest_management_page.dart';
import 'package:flutter/material.dart';

// ─── Colour tokens ────────────────────────────────────────────────
const Color _espresso    = Color(0xFF4A2C17); // deepest brown – primary
const Color _coffeeBrown = Color(0xFF7B4B2A); // mid brown – brand
const Color _cream       = Color(0xFFF5EFE6); // warm off-white – background
const Color _leafGreen   = Color(0xFF5B8A4A); // plant / disease accent
const Color _sapphire    = Color(0xFF2C6E9B); // symptom-checker accent

class PestDiseaseHomePage extends StatelessWidget {
  const PestDiseaseHomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _cream,
      appBar: AppBar(
        title: const Text(
          'Pest & Disease Management',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 17,
          ),
        ),
        backgroundColor: _espresso,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final w          = constraints.maxWidth;
            final isDesktop  = w > 900;
            final isTablet   = w > 600 && w <= 900;
            final isMobile   = w <= 600;
            final hPad       = isDesktop ? 60.0 : isTablet ? 32.0 : 20.0;
            final vPad       = isDesktop ? 40.0 : isMobile ? 16.0 : 28.0;

            return SingleChildScrollView(
              padding: EdgeInsets.symmetric(horizontal: hPad, vertical: vPad),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  _HeroHeader(isDesktop: isDesktop, isTablet: isTablet, isMobile: isMobile),
                  SizedBox(height: isMobile ? 20 : 32),
                  _ActionCardsSection(
                    context: context,
                    availableWidth: w - (hPad * 2),
                    isDesktop: isDesktop,
                    isTablet: isTablet,
                    isMobile: isMobile,
                  ),
                  SizedBox(height: isMobile ? 20 : 36),
                  const _HealthTipsSection(),
                  const SizedBox(height: 24),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

// ─── Hero header ──────────────────────────────────────────────────
class _HeroHeader extends StatelessWidget {
  final bool isDesktop;
  final bool isTablet;
  final bool isMobile;

  const _HeroHeader({
    required this.isDesktop,
    required this.isTablet,
    required this.isMobile,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(isDesktop ? 32 : isTablet ? 24 : 14),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [_espresso, _coffeeBrown],
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: _espresso.withValues(alpha: 0.28),
            blurRadius: 14,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Icon badge
          Container(
            padding: EdgeInsets.all(isMobile ? 10 : 14),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Text('🌱', style: TextStyle(fontSize: isMobile ? 24 : 32)),
          ),
          SizedBox(width: isMobile ? 12 : 18),
          // Text content
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Farm Health Centre',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: isDesktop ? 22 : isMobile ? 15 : 18,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.3,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  'Monitor, manage and protect your coffee crop',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.82),
                    fontSize: isDesktop ? 14 : isMobile ? 11.5 : 12.5,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Action card data model ───────────────────────────────────────
class _ActionData {
  final String title;
  final String subtitle;
  final String emoji;
  final Color accentColor;
  final VoidCallback onTap;

  const _ActionData({
    required this.title,
    required this.subtitle,
    required this.emoji,
    required this.accentColor,
    required this.onTap,
  });
}

// ─── Action cards section ─────────────────────────────────────────
class _ActionCardsSection extends StatelessWidget {
  final BuildContext context;
  final double availableWidth;
  final bool isDesktop;
  final bool isTablet;
  final bool isMobile;

  const _ActionCardsSection({
    required this.context,
    required this.availableWidth,
    required this.isDesktop,
    required this.isTablet,
    required this.isMobile,
  });

  @override
  Widget build(BuildContext ctx) {
    final cards = [
      _ActionData(
        title: 'Manage Pests',
        subtitle: 'Track & control coffee farm pests',
        emoji: '🐛',
        accentColor: _coffeeBrown,
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const CoffeePestManagementPage()),
        ),
      ),
      _ActionData(
        title: 'Manage Diseases',
        subtitle: 'Diagnose & treat crop diseases',
        emoji: '🍃',
        accentColor: _leafGreen,
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const CoffeeDiseaseManagementPage()),
        ),
      ),
      _ActionData(
        title: 'Symptom Checker',
        subtitle: 'Identify issues from visible signs',
        emoji: '🔍',
        accentColor: _sapphire,
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const CoffeeSymptomCheckerPage()),
        ),
      ),
    ];

    // Mobile: compact horizontal rows stacked full-width
    // Tablet/Desktop: vertical cards in a Wrap grid
    if (isMobile) {
      return Column(
        children: cards
            .map((c) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: _ActionCard(data: c, compact: true),
                ))
            .toList(),
      );
    }

    const double gap = 16;
    final double cardW = isDesktop
        ? ((availableWidth - gap * 2) / 3).clamp(200, 320)
        : ((availableWidth - gap) / 2).clamp(200, 320);

    return Wrap(
      spacing: gap,
      runSpacing: gap,
      alignment: WrapAlignment.center,
      children: cards
          .map((c) => SizedBox(width: cardW, child: _ActionCard(data: c)))
          .toList(),
    );
  }
}

// ─── Individual action card ───────────────────────────────────────
class _ActionCard extends StatelessWidget {
  final _ActionData data;
  // compact = true  → horizontal row (mobile)
  // compact = false → vertical column (tablet / desktop)
  final bool compact;

  const _ActionCard({required this.data, this.compact = false});

  @override
  Widget build(BuildContext context) {
    return compact ? _buildCompact() : _buildFull();
  }

  // ── Compact horizontal row — mobile ──────────────────────────────
  Widget _buildCompact() {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(14),
      elevation: 0,
      child: InkWell(
        onTap: data.onTap,
        borderRadius: BorderRadius.circular(14),
        splashColor: data.accentColor.withValues(alpha: 0.08),
        highlightColor: data.accentColor.withValues(alpha: 0.04),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: data.accentColor.withValues(alpha: 0.22),
              width: 1.5,
            ),
          ),
          child: Row(
            children: [
              // Emoji badge
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: data.accentColor.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(11),
                ),
                alignment: Alignment.center,
                child: Text(data.emoji, style: const TextStyle(fontSize: 22)),
              ),
              const SizedBox(width: 14),
              // Title + subtitle
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      data.title,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: _espresso,
                        letterSpacing: 0.1,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      data.subtitle,
                      style: TextStyle(
                        fontSize: 11.5,
                        color: _coffeeBrown.withValues(alpha: 0.68),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              // Chevron
              Icon(
                Icons.chevron_right_rounded,
                size: 22,
                color: data.accentColor,
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Full vertical card — tablet / desktop ─────────────────────────
  Widget _buildFull() {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18),
      elevation: 0,
      child: InkWell(
        onTap: data.onTap,
        borderRadius: BorderRadius.circular(18),
        splashColor: data.accentColor.withValues(alpha: 0.08),
        highlightColor: data.accentColor.withValues(alpha: 0.04),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: data.accentColor.withValues(alpha: 0.20),
              width: 1.5,
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Emoji badge
              Container(
                width: 54,
                height: 54,
                decoration: BoxDecoration(
                  color: data.accentColor.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(14),
                ),
                alignment: Alignment.center,
                child: Text(data.emoji, style: const TextStyle(fontSize: 28)),
              ),
              const SizedBox(height: 16),
              Text(
                data.title,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: _espresso,
                  letterSpacing: 0.1,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                data.subtitle,
                style: TextStyle(
                  fontSize: 12,
                  color: _coffeeBrown.withValues(alpha: 0.70),
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 18),
              // CTA chip
              Align(
                alignment: Alignment.centerRight,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                  decoration: BoxDecoration(
                    color: data.accentColor,
                    borderRadius: BorderRadius.circular(30),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text(
                        'Open',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(width: 5),
                      const Icon(
                        Icons.arrow_forward_rounded,
                        size: 13,
                        color: Colors.white,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Educative health tips (UI only — no navigation) ──────────────
class _TipData {
  final String emoji;
  final String title;
  final String body;
  const _TipData(this.emoji, this.title, this.body);
}

class _HealthTipsSection extends StatelessWidget {
  const _HealthTipsSection();

  static const _tips = [
    _TipData(
      '🔭',
      'Scout Weekly',
      'Walk your farm every week and check leaves, stems and berries for early signs of pest or disease activity — early action limits damage significantly.',
    ),
    _TipData(
      '🌦️',
      'Weather Watch',
      'High humidity and warm nights accelerate fungal disease spread. Increase monitoring after heavy rainfall or extended wet spells.',
    ),
    _TipData(
      '✂️',
      'Prune Regularly',
      'Good canopy management improves airflow and reduces moisture buildup, naturally lowering disease pressure across your farm.',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Row(
          children: [
            Text('🌿', style: TextStyle(fontSize: 17)),
            SizedBox(width: 8),
            Text(
              'Farm Health Tips',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.bold,
                color: _espresso,
                letterSpacing: 0.2,
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        ..._tips.map((tip) => _TipTile(tip: tip)),
      ],
    );
  }
}

class _TipTile extends StatelessWidget {
  final _TipData tip;
  const _TipTile({required this.tip});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE8DDD4)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(tip.emoji, style: const TextStyle(fontSize: 22)),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  tip.title,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                    color: _espresso,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  tip.body,
                  style: TextStyle(
                    fontSize: 12,
                    color: _coffeeBrown.withValues(alpha: 0.80),
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}