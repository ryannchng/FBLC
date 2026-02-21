import '../core/constants.dart';
import '../core/supabase_client.dart';

class UserReview {
  const UserReview({
    required this.id,
    required this.businessId,
    required this.businessName,
    this.businessImageUrl,
    required this.rating,
    this.content,
    required this.isVerifiedVisit,
    required this.isFlagged,
    required this.createdAt,
  });

  final String id;
  final String businessId;
  final String businessName;
  final String? businessImageUrl;
  final int rating;
  final String? content;
  final bool isVerifiedVisit;
  final bool isFlagged;
  final DateTime createdAt;

  factory UserReview.fromJson(Map<String, dynamic> json) {
    final business = json['businesses'] as Map<String, dynamic>?;
    final images = business?['business_images'] as List<dynamic>?;
    final firstImage = images?.isNotEmpty == true
        ? images!.first['image_url'] as String?
        : null;

    return UserReview(
      id: json['id'] as String,
      businessId: json['business_id'] as String,
      businessName: business?['name'] as String? ?? 'Unknown Business',
      businessImageUrl: firstImage,
      rating: json['rating'] as int,
      content: json['content'] as String?,
      isVerifiedVisit: json['is_verified_visit'] as bool? ?? false,
      isFlagged: json['is_flagged'] as bool? ?? false,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }
}

class ReviewRepository {
  Future<List<UserReview>> getMyReviews({
    int limit = AppConstants.pageSize,
    int offset = 0,
  }) async {
    final userId = SupabaseClientProvider.currentUser?.id;
    if (userId == null) return [];

    final data = await SupabaseClientProvider.client
        .from('reviews')
        .select('*, businesses(name, business_images(image_url, display_order))')
        .eq('user_id', userId)
        .order('created_at', ascending: false)
        .range(offset, offset + limit - 1);

    return (data as List).map((e) => UserReview.fromJson(e)).toList();
  }

  Future<void> deleteReview(String reviewId) async {
    await SupabaseClientProvider.client
        .from('reviews')
        .delete()
        .eq('id', reviewId);
  }
}