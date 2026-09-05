import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../models/customer_feedback.dart';
import '../models/order.dart';
import '../providers/pos_provider.dart';
import '../theme/celestial_theme.dart';
import 'order_details_dialog.dart';

/// Modal dialog for viewing, searching, and filtering all customer feedback
class CustomerFeedbackDialog extends StatefulWidget {
  const CustomerFeedbackDialog({super.key});

  static void show(BuildContext context) {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (_) => const CustomerFeedbackDialog(),
    );
  }

  @override
  State<CustomerFeedbackDialog> createState() => _CustomerFeedbackDialogState();
}

class _CustomerFeedbackDialogState extends State<CustomerFeedbackDialog> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  String _ratingFilter = 'all'; // 'all', '5', '4', 'low', 'with_msg'

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<PosProvider>(context);
    final feedbacks = provider.customerFeedbacks;
    final isMobile = MediaQuery.of(context).size.width < 600;

    // Filter feedback based on search and rating chip
    final filteredFeedbacks = feedbacks.where((fb) {
      if (_ratingFilter == '5' && fb.rating != 5) return false;
      if (_ratingFilter == '4' && fb.rating != 4) return false;
      if (_ratingFilter == 'low' && fb.rating > 3) return false;
      if (_ratingFilter == 'with_msg' && fb.message.trim().isEmpty) return false;

      if (_searchQuery.isNotEmpty) {
        final q = _searchQuery.toLowerCase().trim();
        final matchName = fb.customerName.toLowerCase().contains(q);
        final matchNum = fb.orderNumber.toLowerCase().contains(q) ||
            fb.orderNumber.replaceAll('#', '').toLowerCase().contains(q);
        final matchTable = (fb.tableNumber ?? '').toLowerCase().contains(q);
        final matchMsg = fb.message.toLowerCase().contains(q);
        final matchTags = fb.tags.any((t) => t.toLowerCase().contains(q));

        if (!matchName && !matchNum && !matchTable && !matchMsg && !matchTags) {
          return false;
        }
      }

      return true;
    }).toList();

    // Stats calculations
    final totalCount = feedbacks.length;
    final double avgRating = totalCount == 0
        ? 0.0
        : feedbacks.map((f) => f.rating).reduce((a, b) => a + b) / totalCount;
    final fiveStarCount = feedbacks.where((f) => f.rating == 5).length;
    final fourStarCount = feedbacks.where((f) => f.rating == 4).length;
    final lowStarCount = feedbacks.where((f) => f.rating <= 3).length;
    final withMsgCount = feedbacks.where((f) => f.message.trim().isNotEmpty).length;
    final satisfactionRate = totalCount == 0
        ? 0
        : (((fiveStarCount + fourStarCount) / totalCount) * 100).round();

    return Dialog(
      backgroundColor: CelestialTheme.bgSurface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(22),
        side: BorderSide(color: CelestialTheme.goldPrimary.withValues(alpha: 0.4), width: 1.5),
      ),
      insetPadding: EdgeInsets.symmetric(horizontal: isMobile ? 12 : 24, vertical: 20),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: 680,
          maxHeight: MediaQuery.of(context).size.height * 0.88,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Top Header
            _buildHeader(context, totalCount, avgRating),

            // KPI Stat Summary Banner
            if (feedbacks.isNotEmpty)
              _buildKpiBanner(avgRating, totalCount, satisfactionRate, isMobile),

            // Search Bar & Filter Chips
            if (feedbacks.isNotEmpty) _buildSearchAndFilters(
              totalCount,
              fiveStarCount,
              fourStarCount,
              lowStarCount,
              withMsgCount,
            ),

            // Feedback List or Empty State
            Expanded(
              child: feedbacks.isEmpty
                  ? _buildInitialEmptyState()
                  : filteredFeedbacks.isEmpty
                      ? _buildNoFilteredMatchesState()
                      : _buildFeedbackList(context, provider, filteredFeedbacks),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context, int totalCount, double avgRating) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 16, 16, 16),
      decoration: BoxDecoration(
        color: const Color(0xFF1E140E),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        border: Border(bottom: BorderSide(color: Colors.white.withValues(alpha: 0.08))),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(9),
            decoration: BoxDecoration(
              gradient: CelestialTheme.brownGradient,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: CelestialTheme.goldPrimary.withValues(alpha: 0.4)),
            ),
            child: const Icon(Icons.rate_review_rounded, color: CelestialTheme.goldLight, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Customer Feedback & Ratings',
                  style: GoogleFonts.outfit(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: CelestialTheme.textLight,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  totalCount == 0
                      ? 'Live customer reviews and suggestions'
                      : 'Saved ratings & suggestions from guest orders',
                  style: const TextStyle(fontSize: 11.5, color: CelestialTheme.textMuted),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.close_rounded, color: CelestialTheme.textMuted),
            tooltip: 'Close',
          ),
        ],
      ),
    );
  }

  Widget _buildKpiBanner(double avgRating, int totalCount, int satisfactionRate, bool isMobile) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 14, 16, 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF16100C),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: CelestialTheme.goldPrimary.withValues(alpha: 0.25)),
      ),
      child: Row(
        children: [
          // Avg Rating Card
          Expanded(
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.star_rounded, size: 20, color: Color(0xFFFFB800)),
                    const SizedBox(width: 4),
                    Text(
                      avgRating.toStringAsFixed(1),
                      style: GoogleFonts.outfit(
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                        color: CelestialTheme.goldLight,
                      ),
                    ),
                    Text(
                      ' / 5.0',
                      style: TextStyle(fontSize: 11, color: CelestialTheme.textMuted),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                const Text(
                  'Average Score',
                  style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w600, color: CelestialTheme.textMuted),
                ),
              ],
            ),
          ),
          Container(width: 1, height: 36, color: Colors.white.withValues(alpha: 0.08)),
          // Total Reviews Card
          Expanded(
            child: Column(
              children: [
                Text(
                  '$totalCount',
                  style: GoogleFonts.outfit(
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 2),
                const Text(
                  'Total Reviews',
                  style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w600, color: CelestialTheme.textMuted),
                ),
              ],
            ),
          ),
          Container(width: 1, height: 36, color: Colors.white.withValues(alpha: 0.08)),
          // Positive Rate
          Expanded(
            child: Column(
              children: [
                Text(
                  '$satisfactionRate%',
                  style: GoogleFonts.outfit(
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                    color: const Color(0xFF4ADE80),
                  ),
                ),
                const SizedBox(height: 2),
                const Text(
                  'Positive (4-5★)',
                  style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w600, color: CelestialTheme.textMuted),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchAndFilters(
    int totalCount,
    int fiveCount,
    int fourCount,
    int lowCount,
    int withMsgCount,
  ) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 6, 16, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Search Input
          Container(
            height: 40,
            decoration: BoxDecoration(
              color: CelestialTheme.bgCard,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: CelestialTheme.goldPrimary.withValues(alpha: 0.25)),
            ),
            child: TextField(
              controller: _searchController,
              onChanged: (val) => setState(() => _searchQuery = val),
              style: const TextStyle(fontSize: 13, color: CelestialTheme.textLight),
              decoration: InputDecoration(
                hintText: 'Search customer, #order, table, or keywords...',
                hintStyle: const TextStyle(fontSize: 12, color: CelestialTheme.textMuted),
                prefixIcon: const Icon(Icons.search_rounded, size: 18, color: CelestialTheme.goldLight),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear_rounded, size: 16, color: CelestialTheme.textMuted),
                        onPressed: () {
                          _searchController.clear();
                          setState(() => _searchQuery = '');
                        },
                      )
                    : null,
                contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                border: InputBorder.none,
              ),
            ),
          ),
          const SizedBox(height: 8),
          // Filter Chips Row
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildFilterChip('All', 'all', totalCount),
                const SizedBox(width: 6),
                _buildFilterChip('5 Stars', '5', fiveCount, icon: Icons.star_rounded, iconColor: const Color(0xFFFFB800)),
                const SizedBox(width: 6),
                _buildFilterChip('4 Stars', '4', fourCount, icon: Icons.star_rounded, iconColor: const Color(0xFFFFB800)),
                const SizedBox(width: 6),
                _buildFilterChip('≤ 3 Stars', 'low', lowCount),
                const SizedBox(width: 6),
                _buildFilterChip('With Comments', 'with_msg', withMsgCount, icon: Icons.chat_bubble_outline_rounded),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String label, String key, int count, {IconData? icon, Color? iconColor}) {
    final isSelected = _ratingFilter == key;
    return InkWell(
      onTap: () => setState(() => _ratingFilter = key),
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: isSelected ? CelestialTheme.goldPrimary.withValues(alpha: 0.22) : CelestialTheme.bgCard,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected ? CelestialTheme.goldPrimary : Colors.white.withValues(alpha: 0.12),
            width: isSelected ? 1.3 : 1.0,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 13, color: isSelected ? CelestialTheme.goldLight : (iconColor ?? CelestialTheme.textMuted)),
              const SizedBox(width: 4),
            ],
            Text(
              '$label ($count)',
              style: TextStyle(
                fontSize: 11,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                color: isSelected ? CelestialTheme.goldLight : CelestialTheme.textMuted,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInitialEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: CelestialTheme.goldPrimary.withValues(alpha: 0.1),
                shape: BoxShape.circle,
                border: Border.all(color: CelestialTheme.goldPrimary.withValues(alpha: 0.3)),
              ),
              child: const Icon(Icons.star_outline_rounded, size: 38, color: CelestialTheme.goldLight),
            ),
            const SizedBox(height: 16),
            Text(
              'No Customer Feedback Yet',
              style: GoogleFonts.outfit(
                fontSize: 17,
                fontWeight: FontWeight.bold,
                color: CelestialTheme.textLight,
              ),
            ),
            const SizedBox(height: 6),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 400),
              child: const Text(
                'When customers complete orders via self-ordering or when orders are marked handed over, ratings and suggestions will be automatically recorded here.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12, color: CelestialTheme.textMuted, height: 1.45),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNoFilteredMatchesState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.filter_alt_off_rounded, size: 40, color: CelestialTheme.textMuted),
            const SizedBox(height: 12),
            Text(
              'No Matching Feedback',
              style: GoogleFonts.outfit(fontSize: 15, fontWeight: FontWeight.bold, color: CelestialTheme.textLight),
            ),
            const SizedBox(height: 4),
            const Text(
              'Try changing your search keywords or rating filter.',
              style: TextStyle(fontSize: 12, color: CelestialTheme.textMuted),
            ),
            const SizedBox(height: 14),
            OutlinedButton.icon(
              onPressed: () {
                setState(() {
                  _searchController.clear();
                  _searchQuery = '';
                  _ratingFilter = 'all';
                });
              },
              icon: const Icon(Icons.refresh_rounded, size: 14),
              label: const Text('Reset Filters', style: TextStyle(fontSize: 12)),
              style: OutlinedButton.styleFrom(
                foregroundColor: CelestialTheme.goldLight,
                side: BorderSide(color: CelestialTheme.goldPrimary.withValues(alpha: 0.5)),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFeedbackList(BuildContext context, PosProvider provider, List<CustomerFeedback> feedbacks) {
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
      itemCount: feedbacks.length,
      separatorBuilder: (_, _) => const SizedBox(height: 10),
      itemBuilder: (context, index) {
        final fb = feedbacks[index];
        final matchingOrder = provider.orders.where(
          (o) =>
              (fb.orderId.isNotEmpty && o.id == fb.orderId) ||
              (fb.orderNumber.isNotEmpty &&
                  o.orderNumber.replaceAll('#', '').trim() == fb.orderNumber.replaceAll('#', '').trim()),
        ).firstOrNull;

        return _buildFeedbackItemCard(context, fb, matchingOrder);
      },
    );
  }

  Widget _buildFeedbackItemCard(BuildContext context, CustomerFeedback fb, Order? matchingOrder) {
    final initials = fb.customerName.isNotEmpty
        ? fb.customerName.trim().split(' ').map((s) => s.isNotEmpty ? s[0] : '').take(2).join('').toUpperCase()
        : 'G';

    // Sentiment descriptor based on rating
    String sentimentText;
    Color sentimentColor;
    if (fb.rating == 5) {
      sentimentText = '5.0 ★ Exceptional';
      sentimentColor = const Color(0xFF4ADE80);
    } else if (fb.rating == 4) {
      sentimentText = '4.0 ★ Great';
      sentimentColor = const Color(0xFF60A5FA);
    } else if (fb.rating == 3) {
      sentimentText = '3.0 ★ Good';
      sentimentColor = const Color(0xFFFFB800);
    } else if (fb.rating == 2) {
      sentimentText = '2.0 ★ Fair';
      sentimentColor = const Color(0xFFF97316);
    } else {
      sentimentText = '1.0 ★ Needs Attention';
      sentimentColor = const Color(0xFFEF4444);
    }

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: CelestialTheme.bgCard,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: CelestialTheme.goldPrimary.withValues(alpha: 0.22)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.2),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Row 1: Avatar, Name, Table & Order Tag, Rating Stars
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Initials Avatar
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  gradient: CelestialTheme.brownGradient,
                  shape: BoxShape.circle,
                  border: Border.all(color: CelestialTheme.goldPrimary.withValues(alpha: 0.4)),
                ),
                child: Center(
                  child: Text(
                    initials,
                    style: GoogleFonts.outfit(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: CelestialTheme.goldLight,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              // Customer Name + Table
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      fb.customerName.isNotEmpty ? fb.customerName : 'Guest Customer',
                      style: GoogleFonts.outfit(
                        fontSize: 13.5,
                        fontWeight: FontWeight.bold,
                        color: CelestialTheme.textLight,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Row(
                      children: [
                        if (fb.tableNumber != null && fb.tableNumber!.isNotEmpty) ...[
                          Text(
                            'Table ${fb.tableNumber}',
                            style: const TextStyle(fontSize: 11, color: CelestialTheme.goldLight, fontWeight: FontWeight.w600),
                          ),
                          const SizedBox(width: 5),
                          const Text('•', style: TextStyle(color: CelestialTheme.textMuted, fontSize: 10)),
                          const SizedBox(width: 5),
                        ],
                        Text(
                          DateFormat('MMM d, h:mm a').format(fb.createdAt),
                          style: const TextStyle(fontSize: 10.5, color: CelestialTheme.textMuted),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              // Order Number clickable badge
              InkWell(
                onTap: matchingOrder != null
                    ? () {
                        Navigator.pop(context);
                        OrderDetailsDialog.show(context, matchingOrder);
                      }
                    : null,
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1B1511),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: CelestialTheme.goldPrimary.withValues(alpha: 0.4)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        fb.orderNumber.startsWith('#') ? fb.orderNumber : '#${fb.orderNumber}',
                        style: GoogleFonts.outfit(
                          fontSize: 11.5,
                          fontWeight: FontWeight.bold,
                          color: CelestialTheme.goldLight,
                        ),
                      ),
                      if (matchingOrder != null) ...[
                        const SizedBox(width: 4),
                        const Icon(Icons.open_in_new_rounded, size: 11, color: CelestialTheme.goldLight),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 10),

          // Row 2: Star Rating & Sentiment Badge
          Row(
            children: [
              Row(
                children: List.generate(5, (sIdx) {
                  final filled = sIdx < fb.rating;
                  return Icon(
                    filled ? Icons.star_rounded : Icons.star_outline_rounded,
                    size: 16,
                    color: filled ? const Color(0xFFFFB800) : Colors.white24,
                  );
                }),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(
                  color: sentimentColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: sentimentColor.withValues(alpha: 0.35)),
                ),
                child: Text(
                  sentimentText,
                  style: TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.bold,
                    color: sentimentColor,
                  ),
                ),
              ),
            ],
          ),

          // Row 3: Tags
          if (fb.tags.isNotEmpty) ...[
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 5,
              children: fb.tags.map((tag) {
                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: CelestialTheme.goldPrimary.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: CelestialTheme.goldPrimary.withValues(alpha: 0.2)),
                  ),
                  child: Text(
                    tag,
                    style: const TextStyle(fontSize: 10.5, color: CelestialTheme.goldLight, fontWeight: FontWeight.w500),
                  ),
                );
              }).toList(),
            ),
          ],

          // Row 4: Quoted Message
          if (fb.message.trim().isNotEmpty) ...[
            const SizedBox(height: 9),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFF130E0B),
                borderRadius: BorderRadius.circular(8),
                border: Border(
                  left: BorderSide(color: CelestialTheme.goldPrimary.withValues(alpha: 0.8), width: 3),
                  top: BorderSide(color: Colors.white.withValues(alpha: 0.05)),
                  right: BorderSide(color: Colors.white.withValues(alpha: 0.05)),
                  bottom: BorderSide(color: Colors.white.withValues(alpha: 0.05)),
                ),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.format_quote_rounded, size: 14, color: CelestialTheme.goldLight),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      fb.message.trim(),
                      style: GoogleFonts.outfit(
                        fontSize: 12,
                        fontStyle: FontStyle.italic,
                        color: CelestialTheme.textLight,
                        height: 1.35,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

