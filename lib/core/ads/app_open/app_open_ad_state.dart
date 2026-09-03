import 'package:equatable/equatable.dart';

class AppOpenAdState extends Equatable {
  final bool isLoadingAd;
  final bool isShowingAd;

  const AppOpenAdState({
    this.isLoadingAd = false,
    this.isShowingAd = false,
  });

  AppOpenAdState copyWith({bool? isLoadingAd, bool? isShowingAd}) {
    return AppOpenAdState(
      isLoadingAd: isLoadingAd ?? this.isLoadingAd,
      isShowingAd: isShowingAd ?? this.isShowingAd,
    );
  }

  @override
  List<Object?> get props => [isLoadingAd, isShowingAd];
}