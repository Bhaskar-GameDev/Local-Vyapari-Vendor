import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:shimmer/shimmer.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_dimensions.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../domain/providers/chat_provider.dart';
import '../../common/app_animations.dart';

class ChatsListScreen extends ConsumerWidget {
  const ChatsListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final chatsAsync = ref.watch(vendorChatsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Customer Chats'),
        automaticallyImplyLeading: false,
      ),
      body: SafeArea(
        child: chatsAsync.when(
          data: (chats) {
            if (chats.isEmpty) {
              return Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(AppDimensions.horizontalPadding),
                  child: FadeInSlide(
                    duration: const Duration(milliseconds: 600),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(24),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withOpacity(0.05),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.forum_outlined,
                            size: 64,
                            color: AppColors.primary,
                          ),
                        ),
                        AppSpacing.verticalMd,
                        Text(
                          'No messages yet',
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: AppColors.textPrimary,
                              ),
                        ),
                        AppSpacing.verticalSm,
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 24.0),
                          child: Text(
                            'When customers query your products or shop, their conversations will appear here.',
                            textAlign: TextAlign.center,
                            style: AppTextStyles.getBodyMedium(context).copyWith(
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }

            return ListView.separated(
              padding: const EdgeInsets.symmetric(
                vertical: AppSpacing.sm,
                horizontal: AppDimensions.horizontalPadding,
              ),
              itemCount: chats.length,
              separatorBuilder: (context, index) => const Divider(
                color: AppColors.border,
                height: 1,
              ),
              itemBuilder: (context, index) {
                final chat = chats[index];
                return FadeInSlide(
                  duration: const Duration(milliseconds: 400),
                  delay: Duration(milliseconds: 50 * index),
                  slideOffset: 12,
                  child: Dismissible(
                    key: Key(chat.userId),
                    direction: DismissDirection.endToStart,
                    background: Container(
                      color: AppColors.error,
                      alignment: Alignment.centerRight,
                      padding: const EdgeInsets.only(right: 20),
                      child: const Icon(
                        Icons.delete_outline_rounded,
                        color: Colors.white,
                      ),
                    ),
                    confirmDismiss: (direction) async {
                      return await showDialog<bool>(
                        context: context,
                        builder: (context) => AlertDialog(
                          title: const Text('Delete Chat'),
                          content: Text('Are you sure you want to delete this conversation with ${chat.userName}? This will remove it from your chats list.'),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(context, false),
                              child: const Text('Cancel'),
                            ),
                            TextButton(
                              onPressed: () => Navigator.pop(context, true),
                              style: TextButton.styleFrom(foregroundColor: AppColors.error),
                              child: const Text('Delete'),
                            ),
                          ],
                        ),
                      );
                    },
                    onDismissed: (direction) async {
                      await ref.read(chatServiceProvider).deleteChat(chat.userId);
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Conversation with ${chat.userName} deleted'),
                            behavior: SnackBarBehavior.floating,
                            backgroundColor: AppColors.primary,
                          ),
                        );
                      }
                    },
                    child: _ChatSummaryTile(chat: chat),
                  ),
                );
              },
            );
          },
          loading: () => _buildShimmerLoading(context),
          error: (error, stack) => Center(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.error_outline_rounded,
                    color: AppColors.error,
                    size: 48,
                  ),
                  AppSpacing.verticalSm,
                  Text(
                    'Failed to load chats',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary,
                        ),
                  ),
                  AppSpacing.verticalXs,
                  Text(
                    error.toString(),
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: AppColors.textSecondary),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildShimmerLoading(BuildContext context) {
    return ListView.separated(
      padding: const EdgeInsets.symmetric(
        vertical: AppSpacing.sm,
        horizontal: AppDimensions.horizontalPadding,
      ),
      itemCount: 5,
      separatorBuilder: (context, index) => const Divider(
        color: AppColors.border,
        height: 1,
      ),
      itemBuilder: (context, index) {
        return Shimmer.fromColors(
          baseColor: Colors.grey[300]!,
          highlightColor: Colors.grey[100]!,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8.0),
            child: Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                  ),
                ),
                AppSpacing.horizontalMd,
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 120,
                        height: 16,
                        color: Colors.white,
                      ),
                      AppSpacing.verticalXs,
                      Container(
                        width: double.infinity,
                        height: 12,
                        color: Colors.white,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _ChatSummaryTile extends ConsumerWidget {
  final ChatSummary chat;

  const _ChatSummaryTile({required this.chat});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final initials = chat.userName.isNotEmpty ? chat.userName[0].toUpperCase() : 'C';
    final formattedTime = _formatDateTime(chat.timestamp);

    // Generate a consistent color based on user ID
    final avatarColor = _getAvatarColor(chat.userId);

    return ScaleOnTap(
      onTap: () {
        context.push('/chat', extra: {
          'userId': chat.userId,
          'userName': chat.userName,
        });
      },
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4.0),
        padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 4.0),
        decoration: BoxDecoration(
          borderRadius: AppRadius.borderSm,
          color: chat.unread ? AppColors.primary.withOpacity(0.02) : Colors.transparent,
        ),
        child: Row(
          children: [
            CircleAvatar(
              radius: 24,
              backgroundColor: avatarColor.withOpacity(0.1),
              child: Text(
                initials,
                style: TextStyle(
                  color: avatarColor,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ),
            AppSpacing.horizontalMd,
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          chat.userName,
                          style: TextStyle(
                            fontWeight: chat.unread ? FontWeight.bold : FontWeight.w600,
                            fontSize: 15,
                            color: AppColors.textPrimary,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Text(
                        formattedTime,
                        style: TextStyle(
                          fontSize: 11,
                          color: chat.unread ? AppColors.accent : AppColors.textHint,
                          fontWeight: chat.unread ? FontWeight.bold : FontWeight.normal,
                        ),
                      ),
                    ],
                  ),
                  AppSpacing.verticalXs,
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          chat.lastMessageText.isNotEmpty ? chat.lastMessageText : 'Start chatting',
                          style: TextStyle(
                            color: chat.unread ? AppColors.textPrimary : AppColors.textSecondary,
                            fontSize: 13,
                            fontWeight: chat.unread ? FontWeight.w500 : FontWeight.normal,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (chat.unread) ...[
                        AppSpacing.horizontalSm,
                        Container(
                          width: 8,
                          height: 8,
                          decoration: const BoxDecoration(
                            shape: BoxShape.circle,
                            color: AppColors.accent,
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Color _getAvatarColor(String id) {
    final int hash = id.codeUnits.fold(0, (prev, elem) => prev + elem);
    final List<Color> colors = [
      AppColors.primary,
      AppColors.primaryLight,
      AppColors.accent,
      const Color(0xFFE28743),
      const Color(0xFF76528B),
      const Color(0xFFD9534F),
      const Color(0xFF2E8B57),
    ];
    return colors[hash % colors.length];
  }

  String _formatDateTime(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inDays == 0) {
      return DateFormat('hh:mm a').format(dateTime);
    } else if (difference.inDays == 1) {
      return 'Yesterday';
    } else if (difference.inDays < 7) {
      return DateFormat('EEEE').format(dateTime);
    } else {
      return DateFormat('dd/MM/yyyy').format(dateTime);
    }
  }
}
