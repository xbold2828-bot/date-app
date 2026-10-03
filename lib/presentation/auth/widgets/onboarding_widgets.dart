import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/constants/app_text_styles.dart';
import '../../../core/extensions/global_back_extension.dart';
import '../../../core/extensions/unfocus_on_tap_extension.dart';
import '../../../core/theme/app_colors.dart';
import '../../../data/models/tag_model.dart';
import '../../common/widgets/widgets.dart';

export '../../common/widgets/step_header.dart' show kOnboardingStepCount;

/// Onboarding's own vocabulary: one question per screen, the answers are the
/// interface, and the way forward is always in the same place.
///
/// Built on the shared tokens — the same blue, the same two faces — but bolder
/// than the rest of the app on purpose. Everywhere else a chip is one control
/// among many; here it *is* the screen, so it is bigger, and a chosen answer
/// fills solid instead of tinting.

/// The funnel's top chrome. See [StepHeader].
typedef OnboardingHeader = StepHeader;

/// A selectable pill. See [RadiusChip].
typedef OnboardingChip = RadiusChip;

/// Small uppercase heading between groups. See [SectionLabel].
typedef OnboardingSectionLabel = SectionLabel;

const Cubic _easeOut = Cubic(0.23, 1, 0.32, 1);

/// Every onboarding step's frame: progress, the question, the answers, and a
/// primary action pinned to the bottom edge.
///
/// The action used to sit at the end of the scrolling content, so on a tall
/// step the way forward was below the fold and on a short one it floated in
/// the middle of the screen. Pinned, it is always one thumb-reach away, and it
/// rides up with the keyboard instead of hiding under it.
class OnboardingScaffold extends StatelessWidget {
  const OnboardingScaffold({
    super.key,
    required this.step,
    required this.section,
    required this.title,
    required this.children,
    required this.actionLabel,
    required this.onAction,
    this.subtitle,
    this.isLoading = false,
    this.hint,
    this.hintIsWarning = false,
    this.secondaryLabel,
    this.onSecondary,
    this.showBack = true,
    this.onBack,
    this.trailing,
  });

  final int step;

  /// For screen readers; see [StepHeader.label].
  final String section;

  final String title;
  final String? subtitle;
  final List<Widget> children;

  final String actionLabel;

  /// Null disables the action — the step is not answered yet.
  final VoidCallback? onAction;
  final bool isLoading;

  /// One line above the action: what is missing, or what happens next.
  final String? hint;
  final bool hintIsWarning;

  /// A quiet second way out under the action, e.g. "Skip for now".
  final String? secondaryLabel;
  final VoidCallback? onSecondary;

  final bool showBack;
  final VoidCallback? onBack;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            StepHeader(
              step: step,
              label: section,
              isShowBackButton: showBack,
              onBack: onBack,
              trailing: trailing,
            ),
            Expanded(
              child: SingleChildScrollView(
                keyboardDismissBehavior:
                    ScrollViewKeyboardDismissBehavior.onDrag,
                padding: const EdgeInsets.fromLTRB(24, 14, 24, 28),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    QuestionHeadline(title: title, subtitle: subtitle),
                    const SizedBox(height: 30),
                    ...children,
                  ],
                ),
              ),
            ),
            OnboardingFooter(
              actionLabel: actionLabel,
              onAction: onAction,
              isLoading: isLoading,
              hint: hint,
              hintIsWarning: hintIsWarning,
              secondaryLabel: secondaryLabel,
              onSecondary: onSecondary,
            ),
          ],
        ),
      ),
    ).unfocusOnTap().withGlobalBackHandler(context);
  }
}

/// The question, set large, with at most one plain line under it.
class QuestionHeadline extends StatelessWidget {
  const QuestionHeadline({super.key, required this.title, this.subtitle});

  final String title;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Semantics(
          header: true,
          child: Text(title, style: AppTextStyles.question),
        ),
        if (subtitle != null) ...[
          const SizedBox(height: 10),
          Text(
            subtitle!,
            style: AppTextStyles.bodyMuted.copyWith(fontSize: 15, height: 1.45),
          ),
        ],
      ],
    );
  }
}

/// The bottom edge of a step. Sits above the keyboard and the home indicator.
class OnboardingFooter extends StatelessWidget {
  const OnboardingFooter({
    super.key,
    required this.actionLabel,
    required this.onAction,
    this.isLoading = false,
    this.hint,
    this.hintIsWarning = false,
    this.secondaryLabel,
    this.onSecondary,
  });

  final String actionLabel;
  final VoidCallback? onAction;
  final bool isLoading;
  final String? hint;
  final bool hintIsWarning;
  final String? secondaryLabel;
  final VoidCallback? onSecondary;

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.paddingOf(context).bottom;
    final keyboardUp = MediaQuery.viewInsetsOf(context).bottom > 0;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.background,
        border: Border(top: BorderSide(color: AppColors.inputBorder)),
      ),
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          24,
          12,
          24,
          // With the keyboard up the home indicator is hidden under it, so
          // the inset would only push the button away from the keys.
          (keyboardUp ? 10 : 14) + (keyboardUp ? 0 : bottomInset),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AnimatedSize(
              duration: const Duration(milliseconds: 200),
              curve: _easeOut,
              alignment: Alignment.bottomCenter,
              child: hint == null
                  ? const SizedBox(width: double.infinity)
                  : Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: Text(
                        hint!,
                        textAlign: TextAlign.center,
                        style: AppTextStyles.caption.copyWith(
                          fontSize: 13,
                          color: hintIsWarning
                              ? AppColors.danger
                              : AppColors.textGrey,
                        ),
                      ),
                    ),
            ),
            RadiusButton(
              label: actionLabel,
              isLoading: isLoading,
              onPressed: onAction,
            ),
            if (secondaryLabel != null && onSecondary != null)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: TextButton(
                  onPressed: isLoading ? null : onSecondary,
                  style: TextButton.styleFrom(
                    minimumSize: const Size.fromHeight(44),
                    foregroundColor: AppColors.textGrey,
                  ),
                  child: Text(
                    secondaryLabel!,
                    style: AppTextStyles.bodyStrong.copyWith(
                      color: AppColors.textGrey,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// A heading for one question inside a step that asks more than one.
class GroupHeading extends StatelessWidget {
  const GroupHeading({
    super.key,
    required this.title,
    this.hint,
    this.count,
    this.max,
    this.topSpacing = 0,
  });

  final String title;
  final String? hint;

  /// With [max], renders "1 / 3" so the allowance is visible before it is hit.
  final int? count;
  final int? max;

  final double topSpacing;

  @override
  Widget build(BuildContext context) {
    final full = count != null && max != null && count! >= max!;
    return Padding(
      padding: EdgeInsets.only(top: topSpacing, bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: Semantics(
                  header: true,
                  child: Text(
                    title,
                    style: AppTextStyles.title.copyWith(fontSize: 19),
                  ),
                ),
              ),
              if (count != null && max != null) ...[
                const SizedBox(width: 10),
                Semantics(
                  label: '$count of $max picked',
                  excludeSemantics: true,
                  child: Text(
                    '$count / $max',
                    style: AppTextStyles.caption.copyWith(
                      fontSize: 13,
                      color: full ? AppColors.primaryInk : AppColors.textGrey,
                      fontWeight: FontWeight.w700,
                      fontVariations: const [FontVariation('wght', 700)],
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                ),
              ],
            ],
          ),
          if (hint != null) ...[
            const SizedBox(height: 3),
            Text(hint!, style: AppTextStyles.caption.copyWith(fontSize: 13)),
          ],
        ],
      ),
    );
  }
}

/// One answer, as a pill. Bigger than [RadiusChip] and decisive when chosen:
/// a solid fill and a tick, so the choice reads from across the room.
class ChoicePill extends StatelessWidget {
  const ChoicePill({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
    this.locked = false,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  /// Shown with a padlock and still tappable, so the tap can explain the gate.
  final bool locked;

  @override
  Widget build(BuildContext context) {
    final on = selected && !locked;
    // primaryDeep, not primary: the label is white, and white on the brighter
    // blue misses AA for text this size. The deeper blue clears it.
    final fill = on ? AppColors.primaryDeep : AppColors.card;
    final border = on ? AppColors.primaryDeep : AppColors.inputBorder;
    final ink = on
        ? AppColors.onAccent
        : (locked ? AppColors.textGrey : AppColors.textDark);

    return Semantics(
      button: true,
      selected: on,
      enabled: !locked,
      label: locked ? '$label, locked' : label,
      excludeSemantics: true,
      child: _Pressable(
        onTap: () {
          HapticFeedback.selectionClick();
          onTap();
        },
        borderRadius: BorderRadius.circular(999),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          curve: _easeOut,
          constraints: const BoxConstraints(minHeight: 46),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 11),
          decoration: BoxDecoration(
            color: fill,
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: border, width: 1.5),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (locked) ...[
                Icon(Icons.lock_outline_rounded, size: 15, color: ink),
                const SizedBox(width: 6),
              ],
              Flexible(
                child: Text(
                  label,
                  style: AppTextStyles.chip.copyWith(
                    fontSize: 15,
                    color: ink,
                    fontWeight: on ? FontWeight.w700 : FontWeight.w500,
                    fontVariations: [FontVariation('wght', on ? 700 : 500)],
                  ),
                ),
              ),
              AnimatedSize(
                duration: const Duration(milliseconds: 160),
                curve: _easeOut,
                child: on
                    ? Padding(
                        padding: const EdgeInsets.only(left: 6),
                        child: Icon(Icons.check_rounded, size: 17, color: ink),
                      )
                    : const SizedBox.shrink(),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Lays [ChoicePill]s out with the funnel's gutters.
class ChoicePillWrap extends StatelessWidget {
  const ChoicePillWrap({super.key, required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) =>
      Wrap(spacing: 8, runSpacing: 10, children: children);
}

/// Catalogue tags as [ChoicePill]s, stopping at [max] — the same rules as
/// [LimitedTagChipGroup] (see [applySelectionLimit]), in the funnel's style.
///
/// Selection carries the tag *slug*, never the label.
class LimitedChoicePills extends StatelessWidget {
  const LimitedChoicePills({
    super.key,
    required this.tags,
    required this.selected,
    required this.onChanged,
    required this.onLimitReached,
    this.max,
    this.viewerVerified = true,
    this.onLockedTap,
  });

  final List<Tag> tags;
  final Set<String> selected;
  final ValueChanged<Set<String>> onChanged;
  final VoidCallback onLimitReached;

  /// Null means unlimited.
  final int? max;
  final bool viewerVerified;
  final VoidCallback? onLockedTap;

  @override
  Widget build(BuildContext context) {
    return ChoicePillWrap(
      children: [
        for (final tag in tags)
          Builder(
            builder: (context) {
              final locked = tag.isSensitive && !viewerVerified;
              return ChoicePill(
                label: tag.label,
                selected: selected.contains(tag.slug),
                locked: locked,
                onTap: locked
                    ? (onLockedTap ?? () {})
                    : () {
                        final next = applySelectionLimit(
                          selected,
                          tag.slug,
                          max,
                        );
                        next == null ? onLimitReached() : onChanged(next);
                      },
              );
            },
          ),
      ],
    );
  }
}

/// A one-of-several answer with a line saying what it means. Full width, so
/// the explanation has room; no radio circle — the whole row is the control.
class ChoiceRow extends StatelessWidget {
  const ChoiceRow({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
    this.description,
  });

  final String label;
  final String? description;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final fill = selected ? AppColors.primaryDeep : AppColors.card;
    final border = selected ? AppColors.primaryDeep : AppColors.inputBorder;
    final ink = selected ? AppColors.onAccent : AppColors.textDark;
    final sub = selected
        ? AppColors.onAccent.withValues(alpha: 0.86)
        : AppColors.textGrey;

    return Semantics(
      button: true,
      selected: selected,
      label: description == null ? label : '$label. $description',
      excludeSemantics: true,
      child: _Pressable(
        onTap: () {
          HapticFeedback.selectionClick();
          onTap();
        },
        borderRadius: BorderRadius.circular(18),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: _easeOut,
          width: double.infinity,
          constraints: const BoxConstraints(minHeight: 64),
          padding: const EdgeInsets.fromLTRB(18, 14, 16, 14),
          decoration: BoxDecoration(
            color: fill,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: border, width: 1.5),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      label,
                      style: AppTextStyles.bodyStrong.copyWith(
                        fontSize: 16.5,
                        height: 1.3,
                        color: ink,
                        fontWeight: FontWeight.w700,
                        fontVariations: const [FontVariation('wght', 700)],
                      ),
                    ),
                    if (description != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        description!,
                        style: AppTextStyles.caption.copyWith(
                          fontSize: 13.5,
                          color: sub,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 12),
              AnimatedScale(
                scale: selected ? 1 : 0.6,
                duration: const Duration(milliseconds: 180),
                curve: _easeOut,
                child: AnimatedOpacity(
                  opacity: selected ? 1 : 0,
                  duration: const Duration(milliseconds: 140),
                  child: Icon(Icons.check_rounded, size: 22, color: ink),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A short statement with a mark beside it — privacy promises, house rules of
/// thumb. Deliberately not a tinted box: these are footnotes, and boxing them
/// made every screen look like a form full of warnings.
class FactLine extends StatelessWidget {
  const FactLine({super.key, required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 1),
            child: Icon(icon, size: 16, color: AppColors.iconMuted),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: AppTextStyles.caption.copyWith(fontSize: 13, height: 1.45),
            ),
          ),
        ],
      ),
    );
  }
}

/// A name typed big, on a line rather than in a box — it reads like writing
/// your name on a list, not like filling in a form field.
class BigNameField extends StatelessWidget {
  const BigNameField({
    super.key,
    required this.controller,
    required this.label,
    this.hint,
    this.focusNode,
    this.onChanged,
    this.textInputAction = TextInputAction.next,
    this.onSubmitted,
    this.maxLength = 40,
  });

  final TextEditingController controller;
  final String label;
  final String? hint;
  final FocusNode? focusNode;
  final ValueChanged<String>? onChanged;
  final TextInputAction textInputAction;
  final ValueChanged<String>? onSubmitted;
  final int maxLength;

  @override
  Widget build(BuildContext context) {
    final line = UnderlineInputBorder(
      borderSide: BorderSide(color: AppColors.inputBorder, width: 1.5),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: AppTextStyles.bodyStrong.copyWith(
            fontSize: 13.5,
            color: AppColors.textGrey,
          ),
        ),
        TextField(
          controller: controller,
          focusNode: focusNode,
          onChanged: onChanged,
          onSubmitted: onSubmitted,
          textInputAction: textInputAction,
          textCapitalization: TextCapitalization.words,
          autocorrect: false,
          maxLength: maxLength,
          cursorColor: AppColors.primary,
          style: AppTextStyles.title.copyWith(fontSize: 28, height: 1.3),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: AppTextStyles.title.copyWith(
              fontSize: 28,
              height: 1.3,
              color: AppColors.iconMuted,
              fontWeight: FontWeight.w500,
              fontVariations: const [FontVariation('wght', 500)],
            ),
            counterText: '',
            filled: false,
            isDense: true,
            contentPadding: const EdgeInsets.only(top: 6, bottom: 10),
            border: line,
            enabledBorder: line,
            focusedBorder: UnderlineInputBorder(
              borderSide: BorderSide(color: AppColors.primary, width: 2),
            ),
          ),
        ),
      ],
    );
  }
}

/// What a typed birthday adds up to.
enum DobStatus { incomplete, invalid, underage, ok }

/// Day / month / year as three boxes that move you along as you type.
///
/// Typed rather than picked: a calendar is the slowest possible way to reach a
/// date twenty-five years back, and the keypad is already in everyone's hand.
/// The age it adds up to is said back underneath, so a typo in the year shows
/// up as "You're 3" before it is ever sent.
class DobInput extends StatefulWidget {
  const DobInput({super.key, required this.onChanged, this.initial});

  /// The date when it is a real date, with its status either way.
  final void Function(DateTime? date, DobStatus status) onChanged;

  final DateTime? initial;

  /// Whole years between [dob] and [now], counted the way people count
  /// birthdays — not days ÷ 365, which is wrong around every birthday.
  static int ageOn(DateTime dob, DateTime now) {
    var age = now.year - dob.year;
    final hadBirthday =
        now.month > dob.month || (now.month == dob.month && now.day >= dob.day);
    if (!hadBirthday) age--;
    return age;
  }

  /// Parses the three boxes. Null when they do not make a real calendar date.
  static DateTime? parse(String d, String m, String y) {
    final day = int.tryParse(d);
    final month = int.tryParse(m);
    final year = int.tryParse(y);
    if (day == null || month == null || year == null) return null;
    if (y.length != 4 || month < 1 || month > 12 || day < 1) return null;
    final date = DateTime(year, month, day);
    // DateTime rolls 31/02 over into March; a date that moved is not real.
    if (date.year != year || date.month != month || date.day != day) {
      return null;
    }
    return date;
  }

  @override
  State<DobInput> createState() => _DobInputState();
}

class _DobInputState extends State<DobInput> {
  late final _day = TextEditingController(
    text: widget.initial == null ? '' : _two(widget.initial!.day),
  );
  late final _month = TextEditingController(
    text: widget.initial == null ? '' : _two(widget.initial!.month),
  );
  late final _year = TextEditingController(
    text: widget.initial == null ? '' : '${widget.initial!.year}',
  );
  final _dayFocus = FocusNode();
  final _monthFocus = FocusNode();
  final _yearFocus = FocusNode();

  DobStatus _status = DobStatus.incomplete;
  int? _age;

  static String _two(int v) => v.toString().padLeft(2, '0');

  @override
  void initState() {
    super.initState();
    // Seeded from a saved birthday: work out what it says without setState,
    // which is not allowed before the first build.
    if (widget.initial != null) {
      final (_, status, age) = _compute();
      _status = status;
      _age = age;
    }
  }

  @override
  void dispose() {
    _day.dispose();
    _month.dispose();
    _year.dispose();
    _dayFocus.dispose();
    _monthFocus.dispose();
    _yearFocus.dispose();
    super.dispose();
  }

  (DateTime?, DobStatus, int?) _compute() {
    final complete =
        _day.text.isNotEmpty &&
        _month.text.isNotEmpty &&
        _year.text.length == 4;
    if (!complete) return (null, DobStatus.incomplete, null);

    final date = DobInput.parse(_day.text, _month.text, _year.text);
    final now = DateTime.now();
    if (date == null || date.isAfter(now) || date.year < now.year - 100) {
      return (null, DobStatus.invalid, null);
    }
    final age = DobInput.ageOn(date, now);
    return (date, age >= 18 ? DobStatus.ok : DobStatus.underage, age);
  }

  void _evaluate() {
    final (date, status, age) = _compute();
    setState(() {
      _status = status;
      _age = age;
    });
    widget.onChanged(status == DobStatus.ok ? date : null, status);
  }

  void _onPart(String value, int length, FocusNode? next) {
    if (value.length == length && next != null) next.requestFocus();
    _evaluate();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              flex: 4,
              child: _DobBox(
                label: 'Day',
                hint: 'DD',
                controller: _day,
                focusNode: _dayFocus,
                length: 2,
                onChanged: (v) => _onPart(v, 2, _monthFocus),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              flex: 4,
              child: _DobBox(
                label: 'Month',
                hint: 'MM',
                controller: _month,
                focusNode: _monthFocus,
                length: 2,
                onChanged: (v) => _onPart(v, 2, _yearFocus),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              flex: 6,
              child: _DobBox(
                label: 'Year',
                hint: 'YYYY',
                controller: _year,
                focusNode: _yearFocus,
                length: 4,
                onChanged: (v) {
                  if (v.length == 4) _yearFocus.unfocus();
                  _evaluate();
                },
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 200),
          switchInCurve: _easeOut,
          child: _readout(),
        ),
      ],
    );
  }

  Widget _readout() {
    // Nothing to say until the date is complete — the privacy line under the
    // field already makes the "only your age" promise. The fixed height keeps
    // the page from jumping when the verdict arrives.
    if (_status == DobStatus.incomplete) {
      return const SizedBox(key: ValueKey('dob-empty'), height: 20);
    }
    final (IconData? icon, String text, Color color) = switch (_status) {
      DobStatus.incomplete => (null, '', AppColors.textGrey),
      DobStatus.invalid => (
        Icons.error_outline_rounded,
        "That date doesn't look right.",
        AppColors.danger,
      ),
      DobStatus.underage => (
        Icons.block_rounded,
        'cozune is for people 18 and over.',
        AppColors.danger,
      ),
      DobStatus.ok => (
        Icons.check_circle_rounded,
        "You're $_age — that's what people will see.",
        AppColors.ok,
      ),
    };

    return Semantics(
      liveRegion: _status != DobStatus.incomplete,
      child: Row(
        key: ValueKey('$_status$_age'),
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (icon != null) ...[
            Padding(
              padding: const EdgeInsets.only(top: 1),
              child: Icon(icon, size: 16, color: color),
            ),
            const SizedBox(width: 8),
          ],
          Expanded(
            child: Text(
              text,
              style: AppTextStyles.caption.copyWith(
                fontSize: 13.5,
                color: color,
                fontWeight: _status == DobStatus.incomplete
                    ? FontWeight.w500
                    : FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DobBox extends StatelessWidget {
  const _DobBox({
    required this.label,
    required this.hint,
    required this.controller,
    required this.focusNode,
    required this.length,
    required this.onChanged,
  });

  final String label;
  final String hint;
  final TextEditingController controller;
  final FocusNode focusNode;
  final int length;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    OutlineInputBorder border(Color color, double width) => OutlineInputBorder(
      borderRadius: BorderRadius.circular(16),
      borderSide: BorderSide(color: color, width: width),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: AppTextStyles.caption.copyWith(
            fontSize: 12.5,
            color: AppColors.textGrey,
          ),
        ),
        const SizedBox(height: 6),
        Semantics(
          label: 'Birthday $label',
          child: TextField(
            controller: controller,
            focusNode: focusNode,
            onChanged: onChanged,
            keyboardType: TextInputType.number,
            textInputAction: length == 4
                ? TextInputAction.done
                : TextInputAction.next,
            textAlign: TextAlign.center,
            maxLength: length,
            cursorColor: AppColors.primary,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            style: AppTextStyles.bodyStrong.copyWith(
              fontSize: 22,
              height: 1.3,
              fontWeight: FontWeight.w700,
              fontVariations: const [FontVariation('wght', 700)],
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: AppTextStyles.bodyStrong.copyWith(
                fontSize: 22,
                height: 1.3,
                color: AppColors.iconMuted,
              ),
              counterText: '',
              filled: true,
              fillColor: AppColors.card,
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(vertical: 16),
              border: border(AppColors.inputBorder, 1.5),
              enabledBorder: border(AppColors.inputBorder, 1.5),
              focusedBorder: border(AppColors.primary, 2),
            ),
          ),
        ),
      ],
    );
  }
}

/// Press feedback for the funnel's large controls: a slight give under the
/// thumb, released on lift. Fast and small — these are tapped many times in a
/// row, and anything slower would make answering feel heavy.
class _Pressable extends StatefulWidget {
  const _Pressable({
    required this.onTap,
    required this.borderRadius,
    required this.child,
  });

  final VoidCallback onTap;
  final BorderRadius borderRadius;
  final Widget child;

  @override
  State<_Pressable> createState() => _PressableState();
}

class _PressableState extends State<_Pressable> {
  bool _down = false;

  void _set(bool down) {
    if (_down != down) setState(() => _down = down);
  }

  @override
  Widget build(BuildContext context) {
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    return AnimatedScale(
      scale: _down && !reduceMotion ? 0.97 : 1,
      duration: const Duration(milliseconds: 110),
      curve: _easeOut,
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          onTap: widget.onTap,
          onHighlightChanged: _set,
          borderRadius: widget.borderRadius,
          splashFactory: NoSplash.splashFactory,
          highlightColor: Colors.transparent,
          child: widget.child,
        ),
      ),
    );
  }
}

/// The funnel's primary action, for sheets that borrow it.
///
/// Kept as its own widget rather than a typedef because onboarding separates
/// "disabled because the form is incomplete" from "disabled because we are
/// mid-request" — [RadiusButton] takes a single nullable handler.
class OnboardingButton extends StatelessWidget {
  const OnboardingButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.isLoading = false,
    this.enabled = true,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool isLoading;

  /// False greys the button out — the form is not ready yet.
  final bool enabled;

  @override
  Widget build(BuildContext context) => RadiusButton(
    label: label,
    isLoading: isLoading,
    onPressed: enabled ? onPressed : null,
  );
}

/// Multi-select chips backed by the curated tag catalogue.
///
/// Selection carries the tag *slug*, never the label — the API validates slugs
/// against the catalogue and rejects anything else.
class TagChipGroup extends StatelessWidget {
  const TagChipGroup({
    super.key,
    required this.tags,
    required this.selected,
    required this.onToggle,
    this.viewerVerified = true,
    this.onLockedTap,
  });

  final List<Tag> tags;
  final Set<String> selected;
  final ValueChanged<String> onToggle;

  /// Sensitive tags are verified-members-only; they render locked otherwise.
  final bool viewerVerified;
  final VoidCallback? onLockedTap;

  @override
  Widget build(BuildContext context) {
    return RadiusChipWrap(
      children: tags.map((tag) {
        final locked = tag.isSensitive && !viewerVerified;
        return RadiusChip(
          label: tag.label,
          selected: selected.contains(tag.slug),
          locked: locked,
          onTap: locked ? (onLockedTap ?? () {}) : () => onToggle(tag.slug),
        );
      }).toList(),
    );
  }
}
