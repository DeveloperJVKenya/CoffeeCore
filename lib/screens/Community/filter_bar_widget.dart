import 'package:flutter/material.dart';
import 'package:coffeecore/screens/Community/community_enums.dart';

class FilterBarWidget extends StatelessWidget {
  final SortOption sort;
  final PostCategory? categoryFilter;
  final CropCategory? cropFilter;
  final ValueChanged<SortOption> onSortChanged;
  final ValueChanged<PostCategory?> onCategoryChanged;
  final ValueChanged<CropCategory?> onCropChanged;

  const FilterBarWidget({
    super.key,
    required this.sort,
    required this.categoryFilter,
    required this.cropFilter,
    required this.onSortChanged,
    required this.onCategoryChanged,
    required this.onCropChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Theme.of(context).scaffoldBackgroundColor,
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            height: 36,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              children: [
                for (final option in SortOption.values)
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      label: Text(option.label,
                          style: const TextStyle(fontSize: 12)),
                      selected: sort == option,
                      onSelected: (_) => onSortChanged(option),
                    ),
                  ),
                Container(
                    width: 1,
                    height: 20,
                    color: Theme.of(context).dividerColor,
                    margin: const EdgeInsets.symmetric(horizontal: 4)),
                for (final crop in CropCategory.values)
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: FilterChip(
                      label: Text(crop.label,
                          style: const TextStyle(fontSize: 12)),
                      selected: cropFilter == crop,
                      onSelected: (selected) =>
                          onCropChanged(selected ? crop : null),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 6),
          SizedBox(
            height: 36,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              children: [
                for (final category in PostCategory.values)
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: FilterChip(
                      label: Text(category.label,
                          style: const TextStyle(fontSize: 12)),
                      selected: categoryFilter == category,
                      selectedColor: category.color.withValues(alpha: 0.2),
                      checkmarkColor: category.color,
                      onSelected: (selected) =>
                          onCategoryChanged(selected ? category : null),
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
