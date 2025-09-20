import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class LearnCoffeeFarming extends StatefulWidget {
  const LearnCoffeeFarming({super.key});

  @override
  LearnCoffeeFarmingState createState() => LearnCoffeeFarmingState();
}

class LearnCoffeeFarmingState extends State<LearnCoffeeFarming> {
  String? _selectedSection; 

  final Map<String, Map<String, dynamic>> _coffeeFarmingGuide = {
    'Planning Your Coffee Farm': {
      'icon': Icons.map,
      'content': '''
🌱 **Planning Your Coffee Farm**  
Successful coffee farming starts with solid planning .

📍 **Choosing the Location**  
- **Altitude**: Arabica grows best at 1,200–2,200m, Robusta at sea level to 800m, as per ICO guidelines.  
- **Climate**: Aim for 15–24°C for Arabica, 24–30°C for Robusta, with 1,200–2,500mm rainfall yearly (USDA data).  
- **Shade**: Plant shade trees like Grevillea or bananas to reduce sun stress, improving yields by up to 20% .  

🌍 **Land Assessment**  
- Check soil: Deep, fertile loams with good drainage; test pH at 5.0–6.0 for Arabica, 5.3–6.5 for Robusta .  
- Avoid steep slopes over 15% to prevent erosion; use terraces if needed.  

📅 **Timing**  
- Plant at rainy season start (e.g., March–May in Kenya's highlands).  
- Prep land 6–9 months ahead for soil amendments.  

💡 **Key Tips**  
- Get soil tested every 2–3 years to avoid nutrient issues.  
- Plan for irrigation if rainfall dips below 1,200mm, using drip systems for efficiency.  
      ''',
    },
    'Preparation & Tools': {
      'icon': Icons.agriculture,
      'content': '''
🌱 **Preparation & Tools**  
Prep your land right using the right tools and methods  for healthy starts.

🌍 **Land Preparation**  
- Clear vegetation and till soil to 30–50cm deep; add compost to boost organic matter to 3–5% (World Coffee Research).  
- Build contours on slopes to hold water and reduce runoff.  
- Mix in lime if pH is below 4.4, applying 250g/tree yearly until 5.0–5.4 .  

🛠 **Tools Required**  
- **Hoe/Jembe**: Dig 50x50x50cm holes for planting.  
- **Pruning Shears**: Trim for airflow, reducing disease risk.  
- **Wheelbarrow**: Move manure or soil mixes.  
- **Sprayer/Watering Can**: For even watering; aim for 20–40L/tree weekly in dry spells.  
- **pH Kit**: Monitor soil; adjust with organic matter.  

📏 **Planting Setup**  
- Space Arabica 2–2.5m apart, Robusta 2.5–3m, for 1,000–2,000 trees/ha (ICO standards).  
- Align rows north-south for better sun exposure.  

💡 **Key Tips**  
- Sterilize tools with bleach to stop disease spread.  
- Use NEMA-approved pots for nurseries if starting seedlings .  
      ''',
    },
    'Coffee Varieties & Growth Periods': {
      'icon': Icons.local_florist,
      'content': '''
🌱 **Coffee Varieties & Growth Periods**  
Choose varieties like those from CRI: SL28, Ruiru 11 (resistant to CBD/CLR), with growth data from field trials.

☕ **Arabica (Coffea arabica)**  
- **Flavor**: Smooth, fruity; 70% of global production (ICO).  
- **Growth Conditions**: Shaded highlands; pH 5.0–6.0.  
- **Growth Period**:  
  - Seed to harvest: 3–4 years.  
  - Flowering: 2–3 months post-rain.  
  - Ripening: 7–9 months; yields 5–15kg/tree/year.  

☕ **Robusta (Coffea canephora)**  
- **Flavor**: Bold, nutty; pest-resistant.  
- **Growth Conditions**: Warmer lowlands; tolerates full sun.  
- **Growth Period**:  
  - Seed to harvest: 2–3 years.  
  - Flowering: Similar timing.  
  - Ripening: 9–11 months; higher yields up to 20kg/tree (USDA).  

💡 **Key Tips**  
- Pick Ruiru 11 or Batian for Kenya's disease-prone areas .  
- Monitor growth; apply NPK fertilizers based on soil tests for optimal yields.  
      ''',
    },
    'How to Cultivate Coffee': {
      'icon': Icons.spa,
      'content': '''
🌱 **How to Cultivate Coffee**  
Follow step-by-step guide from the Coffee Nursery Management Manual(Manual section of this system) for reliable results.

1️⃣ **Seed Selection**  
- Get certified seeds ; 1kg yields 3,000–4,000 seedlings.  
- De-husk and sow in river sand media for 80–90% germination.  

2️⃣ **Nursery Stage**  
- Use shaded beds (50–80% shade nets); transplant at 2 cotyledons (8–10 weeks).  
- Pot in 3:2:1 topsoil:sand:manure mix .  

3️⃣ **Planting**  
- Plant in 50cm holes with compost; space 2m apart.  
- Mulch base to retain moisture.  

4️⃣ **Care**  
- Water regularly; apply 150–300g N/tree/year in splits .  
- Prune annually; harden seedlings 7–8 months post-potting.  

5️⃣ **Harvesting**  
- Hand-pick ripe cherries; process wet for Arabica (yields 15–20% clean coffee).  

💡 **Key Tips**  
- Weed regularly; use foliar feeds after 4 months .  
- Estimate crop 7–17 weeks post-flowering for planning .  
      ''',
    },
    'Common Coffee Pests': {
      'icon': Icons.bug_report,
      'content': '''
🌱 **Common Coffee Pests**  
Based on Journal of Agricultural Science reports, these pests cut yields by 20–50% if unchecked.

🐜 **Coffee Berry Borer**  
- **Damage**: Borers ruin 30–50% of beans (ICO data).  
- **Control**: Collect fallen berries; use Beauveria fungus sprays.  

🐞 **Antestia Bug**  
- **Damage**: Causes potato taste defect in beans.  
- **Control**: Shade management; apply neem (effective in 70% cases, per CRI).  

🦗 **Leaf Miner**  
- **Damage**: Reduces photosynthesis by 20–30%.  
- **Control**: Prune infested leaves; introduce parasitic wasps.  

🐛 **White Stem Borer**  
- **Damage**: Kills 10–20% of young trees.  
- **Control**: Stem painting with lime; destroy infested stems.  

💡 **Key Tips**  
- Scout fields bi-weekly (World Coffee Research).  
- Combine controls to avoid resistance buildup.  
      ''',
    },
    'Common Coffee Diseases': {
      'icon': Icons.local_hospital,
      'content': '''
🌱 **Common Coffee Diseases**  
From Coffee Recommendation Handbooks, these can drop yields by 30–80%.

🍂 **Coffee Leaf Rust**  
- **Symptoms**: Yellow-orange spots; defoliation.  
- **Control**: Resistant varieties like Ruiru 11; copper sprays (0.5% solution, CRI).  

🦠 **Coffee Berry Disease**  
- **Symptoms**: Dark lesions on berries.  
- **Control**: Prune for airflow; remove mummies.  

🌿 **Wilt (Fusarium)**  
- **Symptoms**: Wilting, root decay.  
- **Control**: Well-drained soil; healthy seedlings.  

🍃 **Root Rot**  
- **Symptoms**: Yellow leaves, collapse.  
- **Control**: Improve drainage; add compost (boosts microbes, per CRI).  

💡 **Key Tips**  
- Use 50% shade to lower humidity .  
- Burn infected parts; rotate if needed.  
      ''',
    },
    'Common Cultivation Challenges': {
      'icon': Icons.warning,
      'content': '''
🌱 **Common Cultivation Challenges**  
Real issues from ICO reports , affecting 20–40% of smallholder farms.

🌧 **Unpredictable Weather**  
- **Issue**: Droughts cut yields by 25%; floods cause root rot.  
- **Solution**: Mulch with pulp; install drip irrigation.  

💰 **High Input Costs**  
- **Issue**: Fertilizers take 20–30% of budget.  
- **Solution**: Use compost (5–10kg/tree,); join co-ops for bulk buys.  

🐛 **Pest & Disease Outbreaks**  
- **Issue**: Humidity boosts spread.  
- **Solution**: Weekly checks; IPM reduces losses by 50% (Journal of Ag Science).  

📉 **Market Fluctuations**  
- **Issue**: Prices vary 20–50% yearly.  
- **Solution**: Certify for premiums; intercrop with legumes.  

💡 **Key Tips**  
- Soil test every 2–3 years .  
- Build buffers like savings or diverse crops.  
      ''',
    },
    'How to Manage Pests': {
      'icon': Icons.shield,
      'content': '''
🌱 **How to Manage Pests**  
Use IPM from World Coffee Research for 40–60% better control.

1️⃣ **Monitoring**  
- Inspect weekly; count pests on 20–25 trees/sample.  
- Set traps to track trends.  

2️⃣ **Natural Methods**  
- Plant borders with repellent herbs; attract birds/ladybugs.  
- Shade reduces borer by 20% .  

3️⃣ **Organic Sprays**  
- Neem or soap mixes; apply evenings at 20–40ml/L water.  
- Copper (0.5%) for scales/loopers .  

4️⃣ **Cultural Practices**  
- Remove debris; prune for air (cuts humidity 10–15%).  
- Rotate crops if possible.  

5️⃣ **Chemical Control**  
- Last resort; follow labels for safe use.  

💡 **Key Tips**  
- Mix methods for sustainability.  
- Train on early detection to save 30% yields.  
      ''',
    },
    'Coffee Nutrition Basics': {
      'icon': Icons.local_dining,
      'content': '''
🌱 **Coffee Nutrition Basics**  
From Coffee Nutrition Manuals - Proper feeding boosts yields by 30-50%.

🧪 **Key Nutrients**  
- **Nitrogen (N)**: For leafy growth; apply 150-300g/tree/year in splits.  
- **Phosphorus (P)**: Root development; use SSP/TSP at 50g/tree planting.  
- **Potassium (K)**: Bigger beans; 100-200g/tree annually.  
- **Zinc/Boron**: Flower set; foliar spray 2-3kg/ha pre-flowering.  

🌿 **Application Timing**  
- **NPK**: 6 months before main flowering (April/October).  
- **Nitrogen**: 2 weeks after rains, in 2-3 splits.  
- **Manure**: 1-2 debes/tree yearly in dry season.  

💡 **Key Tips**  
- Test soil every 2-3 years .  
- Use 3:2:1 soil:sand:manure for nursery pots.  
      ''',
    },
    'Nursery Management': {
      'icon': Icons.eco, 
      'content': '''
🌱 **Nursery Management**  
Standards for healthy seedlings - 80-90% survival rate.

🏗️ **Site Selection**  
- Level land, good drainage, permanent clean water supply.  
- Sheltered from wind; East-West orientation for shade.  

🛠️ **Structures**  
- **Propagators**: 1.5m wide, 10m long, gravel base with polythene cover.  
- **Shade**: 50% shade net for seedlings, 75-80% for propagators.  

🌱 **Seed Propagation**  
- Sow dehusked seeds 2.5cm apart in pure river sand.  
- Germination: 6-8 weeks; transplant at 8-10 weeks.  

💡 **Key Tips**  
- License nursery for quality control .  
- Water regularly but avoid overwatering (damping-off risk).  
      ''',
    },
  };

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5E8C7), // Light beige background
      appBar: AppBar(
        backgroundColor: const Color(0xFF3E2723), // Dark brown
        title: Text(
          "Learn Coffee Farming",
          style: GoogleFonts.poppins(
            color: Colors.white, 
            fontSize: 20,
            fontWeight: FontWeight.bold, // Added bold weight
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Default Minor Information
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(10),
                  boxShadow: const [
                    BoxShadow(color: Colors.black12, blurRadius: 4, offset: Offset(0, 2)),
                  ],
                ),
                child: Text(
                  '''
☕ **Coffee Growing Essentials**  
* Coffee needs 1,200-2,500mm rainfall, well-drained loamy soils (pH 5.0-6.0), and 15-30°C temperatures. 
* Arabica takes 3-4 years to first harvest, Robusta 2-3 years. 
* Proper nursery management yields 3,000-4,000 seedlings per kg of certified seed. 
* Regular nutrition and pest control can boost yields by 30-50%.
                  ''',
                  style: GoogleFonts.poppins(
                    fontSize: 16,
                    color: const Color(0xFF424242),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              // Expandable Cards
              ..._coffeeFarmingGuide.entries.map((entry) {
                final isExpanded = _selectedSection == entry.key;
                return GestureDetector(
                  onTap: () {
                    setState(() {
                      _selectedSection = isExpanded ? null : entry.key;
                    });
                  },
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFF3E2723), width: 2),
                      boxShadow: const [
                        BoxShadow(color: Colors.black12, blurRadius: 4, offset: Offset(0, 2)),
                      ],
                    ),
                    child: Column(
                      children: [
                        ListTile(
                          leading: Icon(
                            entry.value['icon'],
                            color: const Color(0xFF3E2723),
                            size: 30,
                          ),
                          title: Text(
                            entry.key,
                            style: GoogleFonts.poppins(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: const Color(0xFF3E2723),
                            ),
                          ),
                          trailing: Icon(
                            isExpanded ? Icons.expand_less : Icons.expand_more,
                            color: const Color(0xFF3E2723),
                          ),
                        ),
                        if (isExpanded)
                          Padding(
                            padding: const EdgeInsets.all(12.0),
                            child: Text(
                              entry.value['content'],
                              style: GoogleFonts.poppins(
                                fontSize: 16,
                                height: 1.5,
                                color: const Color(0xFF424242),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                );
              }),
            ],
          ),
        ),
      ),
    );
  }
}

// Navigation function to integrate with home page
void navigateToLearnCoffeeFarming(BuildContext context) {
  Navigator.push(
    context,
    MaterialPageRoute(builder: (context) => const LearnCoffeeFarming()),
  );
}