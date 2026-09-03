import 'package:equatable/equatable.dart';

class RewardedAdState extends Equatable {
  final bool isLoading;
  final bool isAdReady;
  final bool isShowingAd;

  const RewardedAdState({
    this.isLoading = false,
    this.isAdReady = false,
    this.isShowingAd = false,
  });

  RewardedAdState copyWith({
    bool? isLoading,
    bool? isAdReady,
    bool? isShowingAd,
  }) {
    return RewardedAdState(
      isLoading: isLoading ?? this.isLoading,
      isAdReady: isAdReady ?? this.isAdReady,
      isShowingAd: isShowingAd ?? this.isShowingAd,
    );
  }

  @override
  List<Object?> get props => [isLoading, isAdReady, isShowingAd];
}