import 'package:dating_app/core/utils/app_loader.dart';
import 'package:dating_app/shared/widgets/empty_widget.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/ads/banner/banner_ad_widget.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../providers/chat_provider.dart';
import '../../../providers/realtime_provider.dart';
import 'request_screen.dart';

class ArchivedChatsScreen extends ConsumerWidget {
  const ArchivedChatsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(archivedConversationsProvider);
    final presence = ref.watch(presenceProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.card,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        shape: Border(
          bottom: BorderSide(color: AppColors.inputBorder, width: 1),
        ),
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: AppColors.textDark),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Archived',
          style: AppTextStyles.title.copyWith(fontSize: 18),
        ),
      ),
      body: Stack(
        children: [
          Positioned.fill(
            child: SafeArea(
              child: RefreshIndicator(
                color: AppColors.primary,
                backgroundColor: AppColors.card,
                onRefresh: () async => ref.invalidate(archivedConversationsProvider),
                child: async.when(
                  loading: () => const Center(
                    child: LoaderWidget(),
                  ),
                  error: (err, _) => ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    children: const [
                      EmptyWidget(
                        title: "Couldn't load your archive",
                        body: 'Pull down to try again.',
                      ),
                    ],
                  ),
                  data: (items) {
                    if (items.isEmpty) {
                      return ListView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        children: const [
                          EmptyWidget(
                            title: 'Nothing archived',
                            body: 'Chats you archive are kept here, out of your '
                                'inbox but not deleted.',
                          ),
                        ],
                      );
                    }

                    return ListView.separated(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 72),
                      itemCount: items.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 8),
                      itemBuilder: (_, index) => ConversationTile(
                        conversation: items[index],
                        colorIndex: index,
                        online: presence[items[index].otherUser.id] ??
                            items[index].otherUser.isOnline,
                        isArchived: true,
                      ),
                    );
                  },
                ),
              ),
            ),
          ),
          const Align(
            alignment: Alignment.bottomCenter,
            child: BannerAdWidget(),
          ),
        ],
      ),
    );
  }
}