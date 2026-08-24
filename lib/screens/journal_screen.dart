import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

// ============================================================================
// SCHOLARLY JOURNAL & RESEARCH REPOSITORY SCREEN
// For CoffeeCore - Coffee Farming Mobile Application
// ============================================================================

// ─── Color Palette (Coffee-inspired, Academic, Accessible) ─────────────────
class AppColors {
  static const Color primary = Color(0xFF3E2723); // Deep espresso
  static const Color primaryLight = Color(0xFF6D4C41); // Medium roast
  static const Color primaryDark = Color(0xFF1B0000); // French roast
  static const Color accent = Color(0xFF8D6E63); // Warm taupe
  static const Color accentLight = Color(0xFFD7CCC8); // Latte foam
  static const Color surface = Color(0xFFF5F5F5); // Parchment
  static const Color surfaceElevated = Color(0xFFFFFFFF); // White
  static const Color textPrimary = Color(0xFF212121); // Charcoal
  static const Color textSecondary = Color(0xFF616161); // Ash
  static const Color textTertiary = Color(0xFF9E9E9E); // Steam
  static const Color success = Color(0xFF2E7D32); // Leaf green
  static const Color warning = Color(0xFFF57C00); // Amber
  static const Color error = Color(0xFFC62828); // Berry red
  static const Color divider = Color(0xFFE0E0E0); // Crema
}

// ─── Research Article Model ────────────────────────────────────────────────
class ResearchArticle {
  final String id;
  final String title;
  final List<String> authors;
  final List<String> affiliations;
  final String journalName;
  final DateTime publicationDate;
  final String doi;
  final String abstractPreview;
  final String fullAbstract;
  final int citationCount;
  final int downloadCount;
  final String pdfUrl;
  final ResearchDomain domain;
  final CoffeeSpecies species;
  final bool isOpenAccess;
  bool isBookmarked;
  bool isExpanded;

  ResearchArticle({
    required this.id,
    required this.title,
    required this.authors,
    required this.affiliations,
    required this.journalName,
    required this.publicationDate,
    required this.doi,
    required this.abstractPreview,
    required this.fullAbstract,
    required this.citationCount,
    required this.downloadCount,
    required this.pdfUrl,
    required this.domain,
    required this.species,
    this.isOpenAccess = true,
    this.isBookmarked = false,
    this.isExpanded = false,
  });
}

enum ResearchDomain {
  entomology,
  soilMicrobiology,
  genetics,
  agroforestry,
  climateScience,
  pathology,
  postHarvest,
  economics,
  all;

  String get label {
    switch (this) {
      case ResearchDomain.entomology:
        return 'Entomology';
      case ResearchDomain.soilMicrobiology:
        return 'Soil Microbiology';
      case ResearchDomain.genetics:
        return 'Genetics & Breeding';
      case ResearchDomain.agroforestry:
        return 'Agroforestry';
      case ResearchDomain.climateScience:
        return 'Climate Science';
      case ResearchDomain.pathology:
        return 'Plant Pathology';
      case ResearchDomain.postHarvest:
        return 'Post-Harvest';
      case ResearchDomain.economics:
        return 'Agricultural Economics';
      case ResearchDomain.all:
        return 'All Domains';
    }
  }
}

enum CoffeeSpecies {
  arabica,
  robusta,
  liberica,
  excelsa,
  all;

  String get label {
    switch (this) {
      case CoffeeSpecies.arabica:
        return 'C. arabica';
      case CoffeeSpecies.robusta:
        return 'C. canephora';
      case CoffeeSpecies.liberica:
        return 'C. liberica';
      case CoffeeSpecies.excelsa:
        return 'C. excelsa';
      case CoffeeSpecies.all:
        return 'All Species';
    }
  }
}

// ─── Mock Data Generator ───────────────────────────────────────────────────
List<ResearchArticle> getMockArticles() {
  return [
    ResearchArticle(
      id: '1',
      title:
          'Climate-Resilient Arabica Coffee Cultivars: Genomic Selection for Drought Tolerance in Highland East African Regions',
      authors: ['Dr. Amina Osei', 'Prof. James K. Mwangi', 'Dr. Elena Rossi'],
      affiliations: [
        'Institute of Coffee Research, Kenya',
        'University of Florence, Italy'
      ],
      journalName: 'Journal of Agricultural Genomics',
      publicationDate: DateTime(2025, 3, 15),
      doi: '10.1016/j.jag.2025.03.014',
      abstractPreview:
          'This study evaluates genomic selection strategies for identifying drought-tolerant Arabica coffee cultivars suitable for highland East African regions experiencing increasing aridity...',
      fullAbstract:
          'This study evaluates genomic selection strategies for identifying drought-tolerant Arabica coffee cultivars suitable for highland East African regions experiencing increasing aridity. Through genome-wide association studies (GWAS) on 450 F1 progeny from crosses between drought-sensitive and drought-tolerant parental lines, we identified 12 significant quantitative trait loci (QTLs) associated with root architecture, stomatal conductance, and osmotic adjustment. Marker-assisted selection models achieved 78% prediction accuracy for drought tolerance phenotypes, offering a viable pathway for accelerated breeding programs in climate-vulnerable coffee zones.',
      citationCount: 142,
      downloadCount: 3847,
      pdfUrl: 'https://doi.org/10.1016/j.jag.2025.03.014',
      domain: ResearchDomain.genetics,
      species: CoffeeSpecies.arabica,
      isOpenAccess: true,
    ),
    ResearchArticle(
      id: '2',
      title:
          'Soil Microbiome Composition and Coffee Wilt Disease Suppression: A Metagenomic Analysis of Rhizosphere Communities in Ugandan Robusta Plantations',
      authors: [
        'Dr. Patrick Nkurunziza',
        'Dr. Sarah Chen',
        'Prof. Hans Müller'
      ],
      affiliations: [
        'National Coffee Research Institute, Uganda',
        'ETH Zürich, Switzerland'
      ],
      journalName: 'Soil Biology and Biochemistry',
      publicationDate: DateTime(2025, 1, 22),
      doi: '10.1016/j.soilbio.2025.01.018',
      abstractPreview:
          'A comprehensive metagenomic survey of rhizosphere microbiomes in Ugandan Robusta plantations reveals distinct bacterial and fungal community structures associated with coffee wilt disease (Gibberella xylarioides) suppression...',
      fullAbstract:
          'A comprehensive metagenomic survey of rhizosphere microbiomes in Ugandan Robusta plantations reveals distinct bacterial and fungal community structures associated with coffee wilt disease (Gibberella xylarioides) suppression. Soils from disease-suppressive fields exhibited significantly higher relative abundances of Pseudomonas fluorescens, Trichoderma harzianum, and Bacillus subtilis. Functional gene analysis indicated enhanced expression of chitinase, glucanase, and siderophore biosynthesis pathways. These findings suggest targeted microbiome modulation as a sustainable biocontrol strategy for managing vascular wilt pathogens in Coffea canephora systems.',
      citationCount: 89,
      downloadCount: 2156,
      pdfUrl: 'https://doi.org/10.1016/j.soilbio.2025.01.018',
      domain: ResearchDomain.soilMicrobiology,
      species: CoffeeSpecies.robusta,
      isOpenAccess: true,
    ),
    ResearchArticle(
      id: '3',
      title:
          'Integrated Pest Management for the Coffee Berry Borer (Hypothenemus hampei): Efficacy of Beauveria bassiana and Cultural Controls in Colombian Smallholder Systems',
      authors: ['Dr. Maria Fernanda López', 'Dr. Robert A. Smith'],
      affiliations: [
        'Cenicafé, Colombia',
        'University of California, Davis, USA'
      ],
      journalName: 'Crop Protection',
      publicationDate: DateTime(2024, 11, 8),
      doi: '10.1016/j.cropro.2024.11.003',
      abstractPreview:
          'Field trials across 24 Colombian smallholder farms demonstrate that integrating Beauveria bassiana fungal applications with shade management and synchronous harvesting reduces coffee berry borer infestation by 62%...',
      fullAbstract:
          'Field trials across 24 Colombian smallholder farms demonstrate that integrating Beauveria bassiana fungal applications with shade management and synchronous harvesting reduces coffee berry borer infestation by 62% compared to conventional insecticide-only regimes. Economic analysis indicates a 34% reduction in pest management costs and a 21% increase in net farm income over a three-year monitoring period. These results support the scaling of biocontrol-based IPM strategies in resource-limited coffee production contexts.',
      citationCount: 234,
      downloadCount: 5621,
      pdfUrl: 'https://doi.org/10.1016/j.cropro.2024.11.003',
      domain: ResearchDomain.entomology,
      species: CoffeeSpecies.arabica,
      isOpenAccess: true,
    ),
    ResearchArticle(
      id: '4',
      title:
          'Agroforestry Shade Systems and Microclimate Regulation: Effects on Arabica Coffee Yield Stability Under Increasing Temperature Extremes in Central America',
      authors: [
        'Dr. Carlos Mendez',
        'Dr. Lisa Thompson',
        'Dr. Yuki Tanaka',
        'Prof. David Brown'
      ],
      affiliations: [
        'CATIE, Costa Rica',
        'World Agroforestry Centre, Kenya',
        'Kyoto University, Japan'
      ],
      journalName: 'Agriculture, Ecosystems & Environment',
      publicationDate: DateTime(2024, 9, 30),
      doi: '10.1016/j.agee.2024.09.028',
      abstractPreview:
          'Long-term observational data from 18 shade-tree coffee systems across Guatemala, Honduras, and Costa Rica reveal that diversified agroforestry canopies buffer daily temperature extremes by 2.4–4.1°C...',
      fullAbstract:
          'Long-term observational data from 18 shade-tree coffee systems across Guatemala, Honduras, and Costa Rica reveal that diversified agroforestry canopies buffer daily temperature extremes by 2.4–4.1°C compared to full-sun monocultures. Shade systems with Inga spp. and Erythrina spp. maintained optimal coffee growth temperatures (>80% of days within 18–24°C range) even during the 2023 El Niño event. Yield stability coefficients were 1.7× higher in shaded systems, highlighting agroforestry as a critical climate adaptation strategy for Central American coffee producers.',
      citationCount: 312,
      downloadCount: 8912,
      pdfUrl: 'https://doi.org/10.1016/j.agee.2024.09.028',
      domain: ResearchDomain.agroforestry,
      species: CoffeeSpecies.arabica,
      isOpenAccess: true,
    ),
    ResearchArticle(
      id: '5',
      title:
          'Leaf Rust (Hemileia vastatrix) Epidemiology in Robusta Coffee: Spore Dispersal Modeling and Climate-Driven Risk Projections for Southeast Asia',
      authors: ['Dr. Nguyen Van Thanh', 'Dr. Priya Sharma', 'Dr. Klaus Weber'],
      affiliations: [
        'Vietnam National University of Agriculture',
        'Indian Institute of Spice Research',
        'Leibniz University Hannover, Germany'
      ],
      journalName: 'Phytopathology',
      publicationDate: DateTime(2024, 7, 12),
      doi: '10.1094/PHYTO-07-24-0123',
      abstractPreview:
          'A coupled epidemiological-climate model predicts significant northward expansion of coffee leaf rust suitable zones into previously non-endemic Robusta-growing regions of Vietnam and southern China by 2035...',
      fullAbstract:
          'A coupled epidemiological-climate model predicts significant northward expansion of coffee leaf rust suitable zones into previously non-endemic Robusta-growing regions of Vietnam and southern China by 2035. Spore dispersal kernel analysis indicates that wind-driven urediniospore transport exceeds 150 km under favorable humidity conditions. The model projects a 40% increase in annual rust epidemic severity in the Central Highlands of Vietnam, necessitating proactive deployment of resistant germplasm and revised fungicide application calendars.',
      citationCount: 178,
      downloadCount: 4453,
      pdfUrl: 'https://doi.org/10.1094/PHYTO-07-24-0123',
      domain: ResearchDomain.pathology,
      species: CoffeeSpecies.robusta,
      isOpenAccess: false,
    ),
    ResearchArticle(
      id: '6',
      title:
          'Carbon Sequestration Potential of Shade-Grown Coffee Systems: A 15-Year Chronosequence Study in the Ethiopian Highlands',
      authors: ['Dr. Abebe Kebede', 'Dr. Rachel Green', 'Prof. Thomas White'],
      affiliations: [
        'Jimma Agricultural Research Center, Ethiopia',
        'University of Queensland, Australia'
      ],
      journalName: 'Global Change Biology',
      publicationDate: DateTime(2025, 2, 5),
      doi: '10.1111/gcb.17234',
      abstractPreview:
          'This 15-year chronosequence study quantifies above- and below-ground carbon stocks in shade-grown coffee systems across elevation gradients (1,400–2,200 m) in the Ethiopian highlands...',
      fullAbstract:
          'This 15-year chronosequence study quantifies above- and below-ground carbon stocks in shade-grown coffee systems across elevation gradients (1,400–2,200 m) in the Ethiopian highlands. Mature shade-coffee systems (age >12 years) stored 187 ± 23 Mg C ha⁻¹, representing 2.3× the carbon stock of full-sun monocultures. Soil organic carbon accounted for 64% of total ecosystem carbon, with highest concentrations in systems utilizing native forest shade trees. These results position shade-grown coffee as a viable nature-based climate solution eligible for carbon credit frameworks.',
      citationCount: 95,
      downloadCount: 3201,
      pdfUrl: 'https://doi.org/10.1111/gcb.17234',
      domain: ResearchDomain.climateScience,
      species: CoffeeSpecies.arabica,
      isOpenAccess: true,
    ),
    ResearchArticle(
      id: '7',
      title:
          'Post-Harvest Fermentation Protocols and Specialty Coffee Cup Quality: A Comparative Analysis of Anaerobic vs. Traditional Wet Processing in Rwandan Washing Stations',
      authors: ['Dr. Jean-Pierre Ndayisaba', 'Dr. Laura Martinez'],
      affiliations: [
        'Rwanda Agriculture Board',
        'University of California, Davis, USA'
      ],
      journalName: 'Food Chemistry',
      publicationDate: DateTime(2024, 12, 18),
      doi: '10.1016/j.foodchem.2024.12.089',
      abstractPreview:
          'Controlled anaerobic fermentation at Rwandan washing stations produced coffees with significantly higher SCA cup scores (87.4 vs. 84.1) and distinct volatile compound profiles dominated by esters and terpenes...',
      fullAbstract:
          'Controlled anaerobic fermentation at Rwandan washing stations produced coffees with significantly higher SCA cup scores (87.4 vs. 84.1) and distinct volatile compound profiles dominated by esters and terpenes. Metabolomic analysis revealed enhanced production of 2-furanmethanethiol and β-damascenone in anaerobically fermented lots. However, extended fermentation (>96 h) increased risk of off-flavor formation. Optimal parameters of 72 h anaerobic fermentation at 18–20°C are recommended for maximizing cup quality while maintaining process consistency.',
      citationCount: 67,
      downloadCount: 1894,
      pdfUrl: 'https://doi.org/10.1016/j.foodchem.2024.12.089',
      domain: ResearchDomain.postHarvest,
      species: CoffeeSpecies.arabica,
      isOpenAccess: true,
    ),
    ResearchArticle(
      id: '8',
      title:
          'Economic Viability of Organic Coffee Certification: A Panel Data Analysis of Smallholder Income Effects in Indonesia and Peru',
      authors: [
        'Dr. Siti Rahayu',
        'Dr. Miguel Ángel Torres',
        'Prof. John Davis'
      ],
      affiliations: [
        'Bogor Agricultural University, Indonesia',
        'Universidad Nacional Agraria La Molina, Peru',
        'University of Cambridge, UK'
      ],
      journalName: 'Ecological Economics',
      publicationDate: DateTime(2024, 10, 3),
      doi: '10.1016/j.ecolecon.2024.10.015',
      abstractPreview:
          'Panel data from 1,200 smallholder households across Indonesia and Peru reveal a 23% premium for organically certified coffee, though net income gains are offset by 18% higher production costs and certification compliance burdens...',
      fullAbstract:
          'Panel data from 1,200 smallholder households across Indonesia and Peru reveal a 23% premium for organically certified coffee, though net income gains are offset by 18% higher production costs and certification compliance burdens. Dynamic panel estimators show that organic certification increases household income by 12% after 4 years of continuous compliance, but initial transition periods (years 1–2) experience income reductions of 8–15%. Targeted subsidy programs for organic input acquisition during transition phases are recommended to improve adoption rates among risk-averse smallholders.',
      citationCount: 156,
      downloadCount: 4102,
      pdfUrl: 'https://doi.org/10.1016/j.ecolecon.2024.10.015',
      domain: ResearchDomain.economics,
      species: CoffeeSpecies.all,
      isOpenAccess: true,
    ),
  ];
}

// ─── Main Screen ────────────────────────────────────────────────────────────
class JournalScreen extends StatefulWidget {
  const JournalScreen({super.key});

  @override
  State<JournalScreen> createState() => _JournalScreenState();
}

class _JournalScreenState extends State<JournalScreen>
    with TickerProviderStateMixin {
  late final List<ResearchArticle> _allArticles;
  late List<ResearchArticle> _filteredArticles;
  late final TextEditingController _searchController;
  late final AnimationController _filterPanelController;
  late final Animation<double> _filterPanelAnimation;
  late final AnimationController _listEntranceController;

  bool _isFilterPanelOpen = false;
  ResearchDomain _selectedDomain = ResearchDomain.all;
  CoffeeSpecies _selectedSpecies = CoffeeSpecies.all;
  int? _selectedYear;
  final List<int> _availableYears = [2025, 2024, 2023, 2022, 2021];
  bool _showBookmarksOnly = false;

  @override
  void initState() {
    super.initState();
    _allArticles = getMockArticles();
    _filteredArticles = List.from(_allArticles);
    _searchController = TextEditingController();
    _searchController.addListener(_onSearchChanged);

    _filterPanelController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350),
    );
    _filterPanelAnimation = CurvedAnimation(
      parent: _filterPanelController,
      curve: Curves.easeInOutCubic,
    );

    _listEntranceController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _listEntranceController.forward();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _filterPanelController.dispose();
    _listEntranceController.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    _applyFilters();
  }

  void _applyFilters() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      _filteredArticles = _allArticles.where((article) {
        // Text search
        final matchesQuery = query.isEmpty ||
            article.title.toLowerCase().contains(query) ||
            article.authors.any((a) => a.toLowerCase().contains(query)) ||
            article.journalName.toLowerCase().contains(query);

        // Domain filter
        final matchesDomain = _selectedDomain == ResearchDomain.all ||
            article.domain == _selectedDomain;

        // Species filter
        final matchesSpecies = _selectedSpecies == CoffeeSpecies.all ||
            article.species == _selectedSpecies ||
            article.species == CoffeeSpecies.all;

        // Year filter
        final matchesYear = _selectedYear == null ||
            article.publicationDate.year == _selectedYear;

        // Bookmarks filter
        final matchesBookmark = !_showBookmarksOnly || article.isBookmarked;

        return matchesQuery &&
            matchesDomain &&
            matchesSpecies &&
            matchesYear &&
            matchesBookmark;
      }).toList();
    });
  }

  void _toggleFilterPanel() {
    setState(() {
      _isFilterPanelOpen = !_isFilterPanelOpen;
      if (_isFilterPanelOpen) {
        _filterPanelController.forward();
      } else {
        _filterPanelController.reverse();
      }
    });
  }

  void _toggleBookmark(String articleId) {
    setState(() {
      final article = _allArticles.firstWhere((a) => a.id == articleId);
      article.isBookmarked = !article.isBookmarked;
      if (_showBookmarksOnly) {
        _applyFilters();
      }
    });
    HapticFeedback.lightImpact();
  }

  void _toggleExpand(String articleId) {
    setState(() {
      final article = _allArticles.firstWhere((a) => a.id == articleId);
      article.isExpanded = !article.isExpanded;
    });
  }

  void _clearFilters() {
    setState(() {
      _selectedDomain = ResearchDomain.all;
      _selectedSpecies = CoffeeSpecies.all;
      _selectedYear = null;
      _showBookmarksOnly = false;
      _searchController.clear();
    });
    _applyFilters();
  }

  int get _activeFilterCount {
    int count = 0;
    if (_selectedDomain != ResearchDomain.all) count++;
    if (_selectedSpecies != CoffeeSpecies.all) count++;
    if (_selectedYear != null) count++;
    if (_showBookmarksOnly) count++;
    return count;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      body: CustomScrollView(
        slivers: [
          // ─── App Bar ─────────────────────────────────────────────────────
          SliverAppBar(
            expandedHeight: 140,
            floating: true,
            pinned: true,
            elevation: 0,
            backgroundColor: AppColors.primary,
            automaticallyImplyLeading: false,
            iconTheme: const IconThemeData(color: Colors.white),
            leading: InkResponse(
              onTap: () => Navigator.pop(context),
              radius: 20,
              child: const Padding(
                padding: EdgeInsets.only(right: 10),
                child: Icon(Icons.arrow_back, color: Colors.white, size: 22),
              ),
            ),
            flexibleSpace: FlexibleSpaceBar(
              titlePadding:
                  const EdgeInsets.only(left: 45, right: 20, bottom: 16),
              title: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.menu_book_rounded,
                    color: Colors.white,
                    size: 22,
                  ),
                  const SizedBox(width: 10),
                  const Text(
                    'Research Repository',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                      letterSpacing: 0.3,
                    ),
                  ),
                ],
              ),
              background: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      AppColors.primary,
                      AppColors.primaryLight,
                    ],
                  ),
                ),
                child: Stack(
                  children: [
                    Positioned(
                      right: -30,
                      top: -20,
                      child: Opacity(
                        opacity: 0.08,
                        child: Icon(
                          Icons.biotech_outlined,
                          size: 180,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    Positioned(
                      left: 45,
                      bottom: 60,
                      child: Text(
                        'Peer-Reviewed Coffee Science',
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.white.withValues(alpha: 0.7),
                          fontWeight: FontWeight.w400,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // ─── Search & Filter Bar ───────────────────────────────────────
          SliverToBoxAdapter(
            child: Container(
              color: AppColors.surfaceElevated,
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Column(
                children: [
                  // Search field
                  TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      hintText: 'Search papers, authors, journals...',
                      hintStyle: TextStyle(
                        color: AppColors.textTertiary,
                        fontSize: 14,
                      ),
                      prefixIcon: Icon(
                        Icons.search_rounded,
                        color: AppColors.textTertiary,
                      ),
                      suffixIcon: _searchController.text.isNotEmpty
                          ? IconButton(
                              icon: Icon(
                                Icons.clear_rounded,
                                color: AppColors.textTertiary,
                                size: 18,
                              ),
                              onPressed: () {
                                _searchController.clear();
                              },
                            )
                          : null,
                      filled: true,
                      fillColor: AppColors.surface,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 14,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Filter toggle row
                  Row(
                    children: [
                      _FilterChipButton(
                        label: 'Filters',
                        icon: Icons.tune_rounded,
                        isActive: _isFilterPanelOpen,
                        badgeCount: _activeFilterCount,
                        onTap: _toggleFilterPanel,
                      ),
                      const SizedBox(width: 8),
                      _FilterChipButton(
                        label: 'Saved',
                        icon: Icons.bookmark_rounded,
                        isActive: _showBookmarksOnly,
                        onTap: () {
                          setState(() {
                            _showBookmarksOnly = !_showBookmarksOnly;
                          });
                          _applyFilters();
                        },
                      ),
                      const Spacer(),
                      Text(
                        '${_filteredArticles.length} result${_filteredArticles.length != 1 ? 's' : ''}',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.textTertiary,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          // ─── Expandable Filter Panel ────────────────────────────────────
          SliverToBoxAdapter(
            child: SizeTransition(
              sizeFactor: _filterPanelAnimation,
              child: Container(
                color: AppColors.surfaceElevated,
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                child: _FilterPanel(
                  selectedDomain: _selectedDomain,
                  selectedSpecies: _selectedSpecies,
                  selectedYear: _selectedYear,
                  availableYears: _availableYears,
                  onDomainChanged: (domain) {
                    setState(() => _selectedDomain = domain);
                    _applyFilters();
                  },
                  onSpeciesChanged: (species) {
                    setState(() => _selectedSpecies = species);
                    _applyFilters();
                  },
                  onYearChanged: (year) {
                    setState(() => _selectedYear = year);
                    _applyFilters();
                  },
                  onClear: _clearFilters,
                ),
              ),
            ),
          ),

          // ─── Divider ────────────────────────────────────────────────────
          SliverToBoxAdapter(
            child: Container(
              height: 1,
              color: AppColors.divider,
            ),
          ),

          // ─── Article List ───────────────────────────────────────────────
          SliverPadding(
            padding: const EdgeInsets.all(16),
            sliver: _filteredArticles.isEmpty
                ? SliverToBoxAdapter(
                    child: _EmptyState(onClear: _clearFilters),
                  )
                : SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        final article = _filteredArticles[index];
                        return AnimatedBuilder(
                          animation: _listEntranceController,
                          builder: (context, child) {
                            final delay = index * 0.08;
                            final value =
                                (_listEntranceController.value - delay)
                                    .clamp(0.0, 1.0);
                            final curveValue = Curves.easeOutCubic.transform(
                                value / (1 - delay).clamp(0.01, 1.0));
                            return Transform.translate(
                              offset: Offset(0, 30 * (1 - curveValue)),
                              child: Opacity(
                                opacity: curveValue,
                                child: child,
                              ),
                            );
                          },
                          child: _ArticleCard(
                            article: article,
                            onBookmarkToggle: () => _toggleBookmark(article.id),
                            onExpandToggle: () => _toggleExpand(article.id),
                          ),
                        );
                      },
                      childCount: _filteredArticles.length,
                    ),
                  ),
          ),

          // ─── Bottom padding for safe area ───────────────────────────────
          const SliverToBoxAdapter(
            child: SizedBox(height: 32),
          ),
        ],
      ),
    );
  }
}

// ─── Filter Panel Widget ───────────────────────────────────────────────────
class _FilterPanel extends StatelessWidget {
  final ResearchDomain selectedDomain;
  final CoffeeSpecies selectedSpecies;
  final int? selectedYear;
  final List<int> availableYears;
  final ValueChanged<ResearchDomain> onDomainChanged;
  final ValueChanged<CoffeeSpecies> onSpeciesChanged;
  final ValueChanged<int?> onYearChanged;
  final VoidCallback onClear;

  const _FilterPanel({
    required this.selectedDomain,
    required this.selectedSpecies,
    required this.selectedYear,
    required this.availableYears,
    required this.onDomainChanged,
    required this.onSpeciesChanged,
    required this.onYearChanged,
    required this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Research Domain
        _FilterSectionTitle(
            title: 'Research Domain', icon: Icons.science_rounded),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: ResearchDomain.values.map((domain) {
            final isSelected = selectedDomain == domain;
            return _ChoiceChip(
              label: domain.label,
              isSelected: isSelected,
              onTap: () => onDomainChanged(domain),
            );
          }).toList(),
        ),
        const SizedBox(height: 20),

        // Coffee Species
        _FilterSectionTitle(title: 'Coffee Species', icon: Icons.eco_rounded),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: CoffeeSpecies.values.map((species) {
            final isSelected = selectedSpecies == species;
            return _ChoiceChip(
              label: species.label,
              isSelected: isSelected,
              onTap: () => onSpeciesChanged(species),
            );
          }).toList(),
        ),
        const SizedBox(height: 20),

        // Publication Year
        _FilterSectionTitle(
            title: 'Publication Year', icon: Icons.calendar_today_rounded),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _ChoiceChip(
              label: 'All Years',
              isSelected: selectedYear == null,
              onTap: () => onYearChanged(null),
            ),
            ...availableYears.map((year) {
              final isSelected = selectedYear == year;
              return _ChoiceChip(
                label: year.toString(),
                isSelected: isSelected,
                onTap: () => onYearChanged(year),
              );
            }),
          ],
        ),
        const SizedBox(height: 16),

        // Clear button
        Align(
          alignment: Alignment.centerRight,
          child: TextButton.icon(
            onPressed: onClear,
            icon: const Icon(Icons.refresh_rounded, size: 16),
            label: const Text('Reset All Filters'),
            style: TextButton.styleFrom(
              foregroundColor: AppColors.primaryLight,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              textStyle: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _FilterSectionTitle extends StatelessWidget {
  final String title;
  final IconData icon;

  const _FilterSectionTitle({required this.title, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 14, color: AppColors.textSecondary),
        const SizedBox(width: 6),
        Text(
          title,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: AppColors.textSecondary,
            letterSpacing: 0.5,
          ),
        ),
      ],
    );
  }
}

class _ChoiceChip extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _ChoiceChip({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeInOut,
      child: Material(
        color: isSelected ? AppColors.primary : AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(20),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: isSelected ? AppColors.primary : AppColors.divider,
                width: 1,
              ),
            ),
            child: Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: isSelected ? Colors.white : AppColors.textSecondary,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Filter Chip Button ──────────────────────────────────────────────────────
class _FilterChipButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool isActive;
  final int? badgeCount;
  final VoidCallback onTap;

  const _FilterChipButton({
    required this.label,
    required this.icon,
    required this.isActive,
    this.badgeCount,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: isActive ? AppColors.primary : Colors.transparent,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isActive ? AppColors.primary : AppColors.divider,
              width: 1.5,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 14,
                color: isActive ? Colors.white : AppColors.textSecondary,
              ),
              const SizedBox(width: 5),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: isActive ? Colors.white : AppColors.textSecondary,
                ),
              ),
              if (badgeCount != null && badgeCount! > 0) ...[
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.all(3),
                  decoration: BoxDecoration(
                    color: isActive ? Colors.white : AppColors.error,
                    shape: BoxShape.circle,
                  ),
                  constraints: const BoxConstraints(
                    minWidth: 16,
                    minHeight: 16,
                  ),
                  child: Center(
                    child: Text(
                      badgeCount.toString(),
                      style: TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.w700,
                        color: isActive ? AppColors.primary : Colors.white,
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Article Card ────────────────────────────────────────────────────────────
class _ArticleCard extends StatelessWidget {
  final ResearchArticle article;
  final VoidCallback onBookmarkToggle;
  final VoidCallback onExpandToggle;

  const _ArticleCard({
    required this.article,
    required this.onBookmarkToggle,
    required this.onExpandToggle,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: AppColors.surfaceElevated,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
        border: Border.all(
          color: AppColors.divider.withValues(alpha: 0.5),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ─── Card Header ────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Domain & Species badges
                Row(
                  children: [
                    _DomainBadge(domain: article.domain),
                    const SizedBox(width: 8),
                    _SpeciesBadge(species: article.species),
                    const Spacer(),
                    if (!article.isOpenAccess)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.warning.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.lock_outline,
                              size: 10,
                              color: AppColors.warning,
                            ),
                            const SizedBox(width: 3),
                            Text(
                              'Paywall',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                                color: AppColors.warning,
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 12),

                // Title
                Text(
                  article.title,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                    height: 1.4,
                    letterSpacing: -0.2,
                  ),
                ),
                const SizedBox(height: 10),

                // Authors
                Text(
                  article.authors.join(', '),
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: AppColors.textSecondary,
                    height: 1.35,
                  ),
                ),
                const SizedBox(height: 4),

                // Affiliations
                Text(
                  article.affiliations.join(' · '),
                  style: TextStyle(
                    fontSize: 11,
                    color: AppColors.textTertiary,
                    height: 1.35,
                  ),
                ),
                const SizedBox(height: 12),

                // Journal & Date
                Row(
                  children: [
                    Icon(
                      Icons.article_outlined,
                      size: 13,
                      color: AppColors.accent,
                    ),
                    const SizedBox(width: 5),
                    Expanded(
                      child: Text(
                        article.journalName,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: AppColors.accent,
                          fontStyle: FontStyle.italic,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Icon(
                      Icons.calendar_month_outlined,
                      size: 12,
                      color: AppColors.textTertiary,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      _formatDate(article.publicationDate),
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.textTertiary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),

                // DOI
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.link_rounded,
                        size: 12,
                        color: AppColors.primaryLight,
                      ),
                      const SizedBox(width: 5),
                      Text(
                        'DOI: ${article.doi}',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                          color: AppColors.primaryLight,
                          fontFamily: 'monospace',
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 12),
          const Divider(height: 1, color: AppColors.divider),
          const SizedBox(height: 12),

          // ─── Abstract Preview ─────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: AnimatedCrossFade(
              firstChild: _buildAbstractPreview(article.abstractPreview, true),
              secondChild: _buildAbstractPreview(article.fullAbstract, false),
              crossFadeState: article.isExpanded
                  ? CrossFadeState.showSecond
                  : CrossFadeState.showFirst,
              duration: const Duration(milliseconds: 300),
            ),
          ),

          const SizedBox(height: 12),

          // ─── Metrics & Actions Bar ──────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
            child: Row(
              children: [
                // Citations
                _MetricPill(
                  icon: Icons.format_quote_rounded,
                  value: _formatNumber(article.citationCount),
                  label: 'Cited',
                  color: AppColors.success,
                ),
                const SizedBox(width: 8),

                // Downloads
                _MetricPill(
                  icon: Icons.download_rounded,
                  value: _formatNumber(article.downloadCount),
                  label: 'Downloads',
                  color: AppColors.primaryLight,
                ),
                const Spacer(),

                // Bookmark
                _IconActionButton(
                  icon: article.isBookmarked
                      ? Icons.bookmark_rounded
                      : Icons.bookmark_border_rounded,
                  color: article.isBookmarked
                      ? AppColors.warning
                      : AppColors.textTertiary,
                  onTap: onBookmarkToggle,
                  tooltip:
                      article.isBookmarked ? 'Remove bookmark' : 'Save paper',
                ),
                const SizedBox(width: 4),

                // Expand abstract
                _IconActionButton(
                  icon: article.isExpanded
                      ? Icons.expand_less_rounded
                      : Icons.expand_more_rounded,
                  color: AppColors.textTertiary,
                  onTap: onExpandToggle,
                  tooltip: article.isExpanded ? 'Collapse' : 'Read abstract',
                ),
                const SizedBox(width: 8),

                // Download PDF
                _DownloadButton(
                  isOpenAccess: article.isOpenAccess,
                  onTap: () {
                    HapticFeedback.mediumImpact();
                    // Implement PDF download / open DOI
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAbstractPreview(String text, bool isTruncated) {
    return Text(
      text,
      style: TextStyle(
        fontSize: 13,
        color: AppColors.textSecondary,
        height: 1.5,
      ),
      maxLines: isTruncated ? 3 : null,
      overflow: isTruncated ? TextOverflow.ellipsis : null,
    );
  }
}

// ─── Domain Badge ────────────────────────────────────────────────────────────
class _DomainBadge extends StatelessWidget {
  final ResearchDomain domain;

  const _DomainBadge({required this.domain});

  @override
  Widget build(BuildContext context) {
    final (color, bgColor) = _getDomainColors(domain);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        domain.label,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          color: color,
          letterSpacing: 0.3,
        ),
      ),
    );
  }

  (Color, Color) _getDomainColors(ResearchDomain domain) {
    switch (domain) {
      case ResearchDomain.entomology:
        return (const Color(0xFF5D4037), const Color(0xFFEFEBE9));
      case ResearchDomain.soilMicrobiology:
        return (const Color(0xFF33691E), const Color(0xFFF1F8E9));
      case ResearchDomain.genetics:
        return (const Color(0xFF1565C0), const Color(0xFFE3F2FD));
      case ResearchDomain.agroforestry:
        return (const Color(0xFF00695C), const Color(0xFFE0F2F1));
      case ResearchDomain.climateScience:
        return (const Color(0xFF6A1B9A), const Color(0xFFF3E5F5));
      case ResearchDomain.pathology:
        return (const Color(0xFFC62828), const Color(0xFFFFEBEE));
      case ResearchDomain.postHarvest:
        return (const Color(0xFFEF6C00), const Color(0xFFFFF3E0));
      case ResearchDomain.economics:
        return (const Color(0xFF455A64), const Color(0xFFECEFF1));
      case ResearchDomain.all:
        return (AppColors.textSecondary, AppColors.surface);
    }
  }
}

// ─── Species Badge ───────────────────────────────────────────────────────────
class _SpeciesBadge extends StatelessWidget {
  final CoffeeSpecies species;

  const _SpeciesBadge({required this.species});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: AppColors.primary.withValues(alpha: 0.15),
          width: 1,
        ),
      ),
      child: Text(
        species.label,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          color: AppColors.primary,
          letterSpacing: 0.3,
          fontFamily: 'serif',
        ),
      ),
    );
  }
}

// ─── Metric Pill ───────────────────────────────────────────────────────────
class _MetricPill extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;
  final Color color;

  const _MetricPill({
    required this.icon,
    required this.value,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
          const SizedBox(width: 3),
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              color: color.withValues(alpha: 0.7),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Icon Action Button ────────────────────────────────────────────────────
class _IconActionButton extends StatelessWidget {
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  final String tooltip;

  const _IconActionButton({
    required this.icon,
    required this.color,
    required this.onTap,
    required this.tooltip,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(8),
          child: Container(
            padding: const EdgeInsets.all(8),
            child: Icon(icon, size: 20, color: color),
          ),
        ),
      ),
    );
  }
}

// ─── Download PDF Button ───────────────────────────────────────────────────
class _DownloadButton extends StatelessWidget {
  final bool isOpenAccess;
  final VoidCallback onTap;

  const _DownloadButton({
    required this.isOpenAccess,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: isOpenAccess ? AppColors.primary : AppColors.textTertiary,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                isOpenAccess
                    ? Icons.download_rounded
                    : Icons.open_in_new_rounded,
                size: 14,
                color: Colors.white,
              ),
              const SizedBox(width: 6),
              Text(
                isOpenAccess ? 'PDF' : 'View',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Empty State ─────────────────────────────────────────────────────────────
class _EmptyState extends StatelessWidget {
  final VoidCallback onClear;

  const _EmptyState({required this.onClear});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(40),
      child: Column(
        children: [
          Icon(
            Icons.search_off_rounded,
            size: 56,
            color: AppColors.textTertiary.withValues(alpha: 0.5),
          ),
          const SizedBox(height: 16),
          Text(
            'No papers found',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Try adjusting your filters or search terms',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              color: AppColors.textTertiary,
            ),
          ),
          const SizedBox(height: 20),
          ElevatedButton.icon(
            onPressed: onClear,
            icon: const Icon(Icons.refresh_rounded, size: 16),
            label: const Text('Reset Filters'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              textStyle: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Utility Functions ─────────────────────────────────────────────────────
String _formatDate(DateTime date) {
  final months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec'
  ];
  return '${months[date.month - 1]} ${date.day}, ${date.year}';
}

String _formatNumber(int num) {
  if (num >= 1000) {
    return '${(num / 1000).toStringAsFixed(1)}k';
  }
  return num.toString();
}

// ============================================================================
// ROUTE REGISTRATION (Add to your main.dart router)
// ============================================================================
// GoRouter or Navigator route:
//   '/research-repository' => JournalScreen()
// ============================================================================
