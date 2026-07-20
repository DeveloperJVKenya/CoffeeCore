import 'package:flutter/material.dart';

/// Whether a post is a general discussion (Reddit-style) or a question that
/// can receive an "Accepted Solution" (Stack Overflow-style).
enum PostType { discussion, question }

/// The coffee-farming topic pill shown on every post card.
///
/// `pestControl` keeps its original enum name (rather than being renamed to
/// `pests`) so posts already saved in Firestore under that value keep
/// resolving correctly — only its label changed. `diseases` is a new,
/// separate value: the rest of the app already treats pests and diseases as
/// distinct domains (`coffee_pest_interventions` vs
/// `coffee_disease_interventions`, separate scan pages), so folding disease
/// questions under "Pest Control" was mis-filing real farmer posts.
enum PostCategory {
  flowering,
  pestControl,
  diseases,
  soilNutrition,
  harvesting,
  processing,
  marketPrices,
  general,
}

extension PostCategoryMeta on PostCategory {
  String get label {
    switch (this) {
      case PostCategory.flowering:
        return 'Flowering';
      case PostCategory.pestControl:
        return 'Pests';
      case PostCategory.diseases:
        return 'Diseases';
      case PostCategory.soilNutrition:
        return 'Soil Nutrition';
      case PostCategory.harvesting:
        return 'Harvesting';
      case PostCategory.processing:
        return 'Processing';
      case PostCategory.marketPrices:
        return 'Market Prices';
      case PostCategory.general:
        return 'General';
    }
  }

  Color get color {
    switch (this) {
      case PostCategory.flowering:
        return const Color(0xFFB0562E);
      case PostCategory.pestControl:
        return const Color(0xFF8C4B4B);
      case PostCategory.diseases:
        return const Color(0xFFA13D3D);
      case PostCategory.soilNutrition:
        return const Color(0xFF6B7F4F);
      case PostCategory.harvesting:
        return const Color(0xFF7A5C3E);
      case PostCategory.processing:
        return const Color(0xFF4E6E81);
      case PostCategory.marketPrices:
        return const Color(0xFF3E7C6A);
      case PostCategory.general:
        return const Color(0xFF7A6F5C);
    }
  }
}

/// The crop/stage filter axis — separate from [PostCategory] because a post's
/// topic (e.g. Pest Control) and the crop it applies to (e.g. Robusta) are
/// independent filters a farmer might combine.
enum CropCategory { arabica, robusta, nursery }

extension CropCategoryMeta on CropCategory {
  String get label {
    switch (this) {
      case CropCategory.arabica:
        return 'Arabica';
      case CropCategory.robusta:
        return 'Robusta';
      case CropCategory.nursery:
        return 'Nursery';
    }
  }
}

enum SortOption { topVoted, mostRecent }

extension SortOptionMeta on SortOption {
  String get label => this == SortOption.topVoted ? 'Top Voted' : 'Most Recent';
}

enum VoteDirection { up, down }
