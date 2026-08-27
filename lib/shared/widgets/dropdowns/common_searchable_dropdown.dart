import 'package:dropdown_button2/dropdown_button2.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../core/extensions/padding_extension.dart';
import '../../../core/utils/validators.dart';
import '../app_text.dart';
import '../textfield/common_text_field.dart';

class CommonSearchableDropdown<T extends Object> extends StatefulWidget {
  final List<T> items;
  final String Function(T) displayString;
  final ValueChanged<T> onSelected;
  final String hintText;
  final TextEditingController? controller;
  final String? validationTitle;
  final bool isCompleteNewName;
  final bool isValidation;
  final bool onTapRemoveText;
  final bool isClearController;
  final bool enabled;
  final Color? hintTextColor;
  final ValueChanged<String>? onChanged;

  const CommonSearchableDropdown({
    super.key,
    required this.items,
    required this.displayString,
    required this.onSelected,
    required this.hintText,
    this.controller,
    this.validationTitle,
    this.isCompleteNewName = false,
    this.isValidation = true,
    this.onTapRemoveText = true,
    this.isClearController = false,
    this.enabled = true,
    this.hintTextColor,
    this.onChanged,
  });

  @override
  State<CommonSearchableDropdown<T>> createState() =>
      _CommonSearchableDropdownState<T>();
}

class _CommonSearchableDropdownState<T extends Object>
    extends State<CommonSearchableDropdown<T>> {
  static const String _noMatchKey = '__NO_MATCH_';

  late final TextEditingController _controller;
  late final FocusNode _focusNode;
  late final ScrollController _scrollController;

  // 1️⃣ ADD THIS: The link that connects the field to the dropdown
  final LayerLink _layerLink = LayerLink();

  bool _hasValidSelection = false;
  bool _enableKeyboard = false;
  bool _dropdownOpen = false;
  bool _isScrollable = false; // ✅ NEW
  static const int _maxVisibleItems = 5;

  @override
  void initState() {
    super.initState();
    _controller = widget.controller ?? TextEditingController();
    _focusNode = FocusNode();
    _scrollController = ScrollController(); // ✅ ADD THIS
    _focusNode.addListener(() {
      // ✅ Clear text if focus lost & no valid selection
      if (!_focusNode.hasFocus && !_hasValidSelection) {
        _controller.clear();
        widget.onChanged?.call(''); // 🔥 ADDED: Notify text cleared
      }
      if (!_focusNode.hasFocus) {
        // 🔴 HARD RESET when dropdown closes / tap outside
        _enableKeyboard = false;
        _dropdownOpen = false;

        if (!_hasValidSelection) {
          _controller.clear();
          widget.onChanged?.call(''); // 🔥 ADDED: Notify text cleared
        }

        ///Clear the controller after selecting the value
        if (widget.isClearController) {
          if (_hasValidSelection) {
            _controller.clear();
            widget.onChanged?.call(''); // 🔥 ADDED: Notify text cleared
          }
        }
        setState(() {});
      }
    });
  }

  @override
  void dispose() {
    _scrollController.dispose(); // ✅ ADD THIS
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    _isScrollable = widget.items.length > _maxVisibleItems;
    return RawAutocomplete<T>(
      textEditingController: _controller,
      focusNode: _focusNode,

      optionsBuilder: (TextEditingValue value) {
        // 🚫 Disable search if not scrollable
        if (!_isScrollable) {
          return widget.items;
        }

        if (value.text.isEmpty) {
          return widget.items;
        }

        final matches = widget.items.where(
          (item) => widget
              .displayString(item)
              .toLowerCase()
              .contains(value.text.toLowerCase()),
        );

        // ✅ Important: return dummy option when no match
        if (matches.isEmpty) {
          return [_noMatchKey as T];
        }

        return matches;
      },

      displayStringForOption: (option) {
        if (option == _noMatchKey) return '';
        return widget.displayString(option);
      },

      onSelected: (item) {
        if (item == _noMatchKey) return;

        _hasValidSelection = true;
        _dropdownOpen = false;
        _enableKeyboard = false;

        _controller.text = widget.displayString(item);
        widget.onChanged?.call(
          _controller.text,
        ); // 🔥 ADDED: Notify text populated by selection
        widget.onSelected(item);

        FocusManager.instance.primaryFocus?.unfocus();
      },

      fieldViewBuilder: (context, controller, focusNode, _) {
        String dynamicHint;

        if (!_dropdownOpen) {
          dynamicHint = widget.hintText;
        } else if (!_isScrollable) {
          dynamicHint = widget.hintText; // No search hint
        } else if (!_enableKeyboard) {
          dynamicHint = "Tap to search";
        } else {
          dynamicHint = "Search";
        }

        return CompositedTransformTarget(
          link: _layerLink,
          child: CommonTextField(
            enabled: widget.enabled,
            controller: controller,
            hintText: dynamicHint,
            hintTextColor: widget.hintTextColor,
            isDropDown: true,
            focusNode: focusNode,
            // 🚫 Disable typing if not scrollable
            readOnly: !_enableKeyboard || !_isScrollable,
            onTap: () {
              if (!_dropdownOpen) {
                // 👉 FIRST TAP
                _dropdownOpen = true;
                _enableKeyboard = false;

                if (widget.onTapRemoveText) {
                  _controller.clear();
                  widget.onChanged?.call(''); // Notify text cleared on tap
                }

                // ✅ FIX 1: Uncommented this line. RawAutocomplete REQUIRES focus to open the overlay.
                focusNode.requestFocus();

                // ✅ FIX 2: Force RawAutocomplete to trigger its listener and show the
                // options overlay even if the text hasn't changed or is already empty.
                controller.value = TextEditingValue(
                  text: controller.text,
                  selection: TextSelection.collapsed(
                    offset: controller.text.length,
                  ),
                );

                setState(() {});
              }
              // Only allow second tap to enable keyboard if scrollable
              else if (_isScrollable && !_enableKeyboard) {
                // 👉 SECOND TAP
                _enableKeyboard = true;
                setState(() {});
              }
            },
            suffixIcon: widget.enabled
                ? IconButton(
                    icon: AnimatedRotation(
                      turns: _dropdownOpen ? 0.5 : 0.0, // rotates 180°
                      duration: const Duration(milliseconds: 200),
                      child: const Icon(Icons.keyboard_arrow_down),
                    ),
                    splashColor: Colors.transparent,
                    highlightColor: Colors.transparent,
                    hoverColor: Colors.transparent,
                    onPressed: () {
                      if (!widget.enabled) return;

                      if (!_dropdownOpen) {
                        // OPEN DROPDOWN
                        _dropdownOpen = true;
                        _enableKeyboard = false;

                        if (widget.onTapRemoveText) {
                          _controller.clear();
                          widget.onChanged?.call(
                            '',
                          ); // 🔥 ADDED: Notify text cleared on suffix tap
                        }

                        _focusNode.requestFocus(); // 🔥 important
                      } else {
                        // CLOSE DROPDOWN
                        _dropdownOpen = false;
                        _enableKeyboard = false;
                        _focusNode.unfocus();
                      }

                      setState(() {});
                    },
                  )
                : null,

            onChanged: (val) {
              _hasValidSelection = false;
              widget.onChanged?.call(
                val,
              ); // 🔥 ADDED: Notify text changed by typing
            },

            validator: widget.isValidation
                ? (value) => validateRequired(
                    value,
                    fieldName: widget.validationTitle ?? "Field",
                    isCompleteNewName: widget.isCompleteNewName,
                    maxLength: 50000,
                    isImplementMinCheck: false,
                  )
                : null,
          ),
        );
      },

      optionsViewBuilder: (context, onSelected, options) {
        // 1. THE KILL SWITCH: If focus is removed (by the scroll extension),
        // stop rendering immediately.
        if (!_focusNode.hasFocus) return const SizedBox.shrink();

        final noMatchFound =
            options.length == 1 && options.first == _noMatchKey;
        const int maxVisibleItems = 5;
        const double estimatedItemHeight = 60;

        final double dropdownHeight =
            (_isScrollable ? maxVisibleItems : options.length) *
            estimatedItemHeight;

        // 2. FOLLOWER: This "pins" the list to the TextField via _layerLink
        return Align(
          alignment: Alignment.topLeft,
          child: CompositedTransformFollower(
            link: _layerLink,
            showWhenUnlinked: false,
            // 🔥 Hides the list if the TextField scrolls off-screen
            offset: Offset(0, 52.h),
            // Offset based on your TextField height
            child: Material(
              color: Theme.of(context).colorScheme.onPrimary,
              elevation: 4,
              borderRadius: BorderRadius.circular(8.r),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxHeight: dropdownHeight,
                  // 3. WIDTH SYNC: Use leaderSize to match the TextField width exactly
                  maxWidth:
                      _layerLink.leaderSize?.width ??
                      (MediaQuery.of(context).size.width - 40.w),
                ),
                child: Scrollbar(
                  controller: _scrollController,
                  thumbVisibility: true,
                  child: ListView.separated(
                    padding: EdgeInsets.zero,
                    controller: _scrollController,
                    shrinkWrap: true,
                    // Required for ConstrainedBox height
                    itemCount: options.length,
                    separatorBuilder: (context, index) => Divider(
                      height: 1,
                      thickness: 1.5,
                      color: Theme.of(context).dividerColor,
                      // Subtle divider
                      indent: 12,
                      // Optional: matches the horizontal padding of the text
                      endIndent: 12,
                    ),
                    itemBuilder: (context, index) {
                      final item = options.elementAt(index);
                      return InkWell(
                        onTap: () {
                          if (!noMatchFound) onSelected(item);
                          FocusManager.instance.primaryFocus?.unfocus();
                        },
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 10,
                          ),
                          child: AppText(
                            text: noMatchFound
                                ? "No Match Found"
                                : widget.displayString(item),
                            fontSize: 15,
                            fontWeight: FontWeight.w400,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      );
                    },
                  ),
                ).paddingSymmetric(vertical: 6.h),
              ),
            ),
          ),
        ).paddingSymmetric(horizontal: 3.w);
      },
    );
  }
}

class CommonSearchableDropdown2<T extends Object> extends StatefulWidget {
  final List<T> items;
  final String Function(T) displayString;
  final ValueChanged<T> onSelected;
  final String hintText;
  final TextEditingController? controller;
  final String? validationTitle;
  final bool isCompleteNewName;
  final bool isValidation;
  final bool onTapRemoveText;
  final bool isClearController;
  final bool enabled;
  final Color? hintTextColor;

  const CommonSearchableDropdown2({
    super.key,
    required this.items,
    required this.displayString,
    required this.onSelected,
    required this.hintText,
    this.controller,
    this.validationTitle,
    this.isCompleteNewName = false,
    this.isValidation = true,
    this.onTapRemoveText = true,
    this.isClearController = false,
    this.enabled = true,
    this.hintTextColor,
  });

  @override
  State<CommonSearchableDropdown2<T>> createState() =>
      _CommonSearchableDropdownState2<T>();
}

class _CommonSearchableDropdownState2<T extends Object>
    extends State<CommonSearchableDropdown2<T>> {
  static const String _noMatchKey = '__NO_MATCH_';
  final LayerLink _layerLink = LayerLink();

  late final TextEditingController _controller;
  late final FocusNode _focusNode;
  late final ScrollController _scrollController;

  // ignore: unused_field
  bool _hasValidSelection = false;
  bool _enableKeyboard = false;
  bool _dropdownOpen = false;
  bool _isScrollable = false; // ✅ NEW
  static const int _maxVisibleItems = 5;

  @override
  void initState() {
    super.initState();
    _controller = widget.controller ?? TextEditingController();
    _focusNode = FocusNode();
    _scrollController = ScrollController(); // ✅ ADD THIS
    _focusNode.addListener(() {
      if (!_focusNode.hasFocus) {
        // 🔴 HARD RESET when dropdown closes / tap outside
        _enableKeyboard = false;
        _dropdownOpen = false;
        setState(() {});
      }
    });
  }

  @override
  void didUpdateWidget(covariant CommonSearchableDropdown2<T> oldWidget) {
    super.didUpdateWidget(oldWidget);

    // If the parent passes a new list (e.g., your API finishes fetching 4000 cities)
    if (widget.items.length != oldWidget.items.length) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          // 1. Save the current text and cursor position
          final currentText = _controller.text;
          final currentSelection = _controller.selection;

          // 2. Perform a microscopic text jiggle to "wake up" RawAutocomplete.
          // This forces the optionsBuilder to run and grab the new 4000 items!
          _controller.text = '$currentText ';
          _controller.text = currentText;

          // 3. Restore the cursor position so the user's typing isn't interrupted
          if (currentSelection.isValid) {
            _controller.selection = currentSelection;
          }
        }
      });
    }
  }

  @override
  void dispose() {
    _scrollController.dispose(); // ✅ ADD THIS
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    _isScrollable = widget.items.length > _maxVisibleItems;
    return RawAutocomplete<T>(
      textEditingController: _controller,
      focusNode: _focusNode,

      optionsBuilder: (TextEditingValue value) {
        // 🚫 Disable search if not scrollable
        if (!_isScrollable) {
          return widget.items;
        }

        if (value.text.isEmpty) {
          return widget.items;
        }

        final matches = widget.items.where(
          (item) => widget
              .displayString(item)
              .toLowerCase()
              .contains(value.text.toLowerCase()),
        );

        // ✅ Important: return dummy option when no match
        if (matches.isEmpty) {
          return [_noMatchKey as T];
        }

        return matches;
      },

      displayStringForOption: (option) {
        if (option == _noMatchKey) return '';
        return widget.displayString(option);
      },

      onSelected: (item) {
        if (item == _noMatchKey) return;

        _hasValidSelection = true;
        _dropdownOpen = false;
        _enableKeyboard = false;

        _controller.text = widget.displayString(item);
        widget.onSelected(item);

        FocusManager.instance.primaryFocus?.unfocus();
      },

      fieldViewBuilder: (context, controller, focusNode, _) {
        String dynamicHint;

        if (!_dropdownOpen) {
          dynamicHint = widget.hintText;
        } else if (!_isScrollable) {
          dynamicHint = widget.hintText; // No search hint
        } else if (!_enableKeyboard) {
          dynamicHint = "Tap to search";
        } else {
          dynamicHint = "Search";
        }

        return CompositedTransformTarget(
          link: _layerLink,
          child: CommonTextField(
            enabled: widget.enabled,
            controller: controller,
            hintText: dynamicHint,
            hintTextColor: widget.hintTextColor,
            isDropDown: true,
            focusNode: focusNode,
            // 🚫 Disable typing if not scrollable
            readOnly: !_enableKeyboard || !_isScrollable,

            onTap: () {
              if (!_dropdownOpen) {
                // 👉 FIRST TAP
                _dropdownOpen = true;
                _enableKeyboard = false;
                if (widget.onTapRemoveText) {
                  _controller.clear();
                }
                // focusNode.requestFocus(); // REQUIRED for dropdown
                if (_controller.text.isEmpty) {
                  _controller.text = '';
                }
                setState(() {});
              }
              // Only allow second tap to enable keyboard if scrollable
              else if (_isScrollable && !_enableKeyboard) {
                // 👉 SECOND TAP
                _enableKeyboard = true;
                setState(() {});
              }
            },
            suffixIcon: widget.enabled
                ? IconButton(
                    icon: AnimatedRotation(
                      turns: _dropdownOpen ? 0.5 : 0.0, // rotates 180°
                      duration: const Duration(milliseconds: 200),
                      child: const Icon(Icons.keyboard_arrow_down),
                    ),
                    splashColor: Colors.transparent,
                    highlightColor: Colors.transparent,
                    hoverColor: Colors.transparent,
                    onPressed: () {
                      if (!widget.enabled) return;

                      if (!_dropdownOpen) {
                        // OPEN DROPDOWN
                        _dropdownOpen = true;
                        _enableKeyboard = false;

                        if (widget.onTapRemoveText) {
                          _controller.clear();
                        }

                        _focusNode.requestFocus(); // 🔥 important
                      } else {
                        // CLOSE DROPDOWN
                        _dropdownOpen = false;
                        _enableKeyboard = false;
                        _focusNode.unfocus();
                      }

                      setState(() {});
                    },
                  )
                : null,

            onChanged: (_) {
              _hasValidSelection = false;
            },

            validator: widget.isValidation
                ? (value) => validateRequired(
                    value,
                    fieldName: widget.validationTitle ?? "Field",
                    isCompleteNewName: widget.isCompleteNewName,
                    maxLength: 50000,
                    isImplementMinCheck: false,
                  )
                : null,
          ),
        );
      },
      optionsViewBuilder: (context, onSelected, options) {
        // 1. If focus is lost, don't build the overlay (prevents ghosting)
        if (!_focusNode.hasFocus) return const SizedBox.shrink();

        final noMatchFound =
            options.length == 1 && options.first == _noMatchKey;
        const double estimatedItemHeight = 60.0;
        final double dropdownHeight =
            (_isScrollable ? _maxVisibleItems : options.length) *
            estimatedItemHeight;

        // 2. Use Align and CompositedTransformFollower to "pin" the search list
        return Align(
          alignment: Alignment.topLeft,
          child: CompositedTransformFollower(
            link: _layerLink,
            showWhenUnlinked: false,
            // 🔥 CRITICAL: Hides menu when field scrolls behind AppBar
            offset: Offset(0, 52.h),
            // Adjust this offset to match your TextField height
            child: Material(
              color: Theme.of(context).colorScheme.onPrimary,
              elevation: 4,
              borderRadius: BorderRadius.circular(8.r),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxHeight: dropdownHeight,
                  // Match the width of the parent TextField automatically
                  maxWidth:
                      _layerLink.leaderSize?.width ??
                      (MediaQuery.of(context).size.width - 40.w),
                ),
                child: Scrollbar(
                  controller: _scrollController,
                  thumbVisibility: true,
                  child: ListView.separated(
                    padding: EdgeInsets.zero,
                    controller: _scrollController,
                    shrinkWrap: true,
                    // Required for ConstrainedBox height
                    itemCount: options.length,
                    separatorBuilder: (context, index) => Divider(
                      height: 1,
                      thickness: 1.5,
                      color: Theme.of(context).dividerColor,
                      // Subtle divider
                      indent: 12,
                      // Optional: matches the horizontal padding of the text
                      endIndent: 12,
                    ),
                    itemBuilder: (context, index) {
                      final item = options.elementAt(index);
                      return InkWell(
                        onTap: () {
                          if (!noMatchFound) onSelected(item);
                          FocusManager.instance.primaryFocus?.unfocus();
                        },
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 10,
                          ),
                          child: AppText(
                            text: noMatchFound
                                ? "No Match Found"
                                : widget.displayString(item),
                            fontSize: 15,
                            maxLines: 2,
                            fontWeight: FontWeight.w400,
                          ),
                        ),
                      );
                    },
                  ),
                ).paddingSymmetric(vertical: 6.h),
              ),
            ),
          ),
        ).paddingSymmetric(horizontal: 3.w);
      },
    );
  }
}

///This dropdown shift it to the center and make screen Freeze
class CommonSearchableDropdown3<T extends Object> extends StatefulWidget {
  final List<T> items;
  final String Function(T) displayString;
  final ValueChanged<T> onSelected;
  final String hintText;
  final TextEditingController? controller;
  final String? validationTitle;
  final bool isCompleteNewName;
  final bool isValidation;
  final bool onTapRemoveText;
  final bool isClearController;
  final bool enabled;
  final Color? hintTextColor;

  const CommonSearchableDropdown3({
    super.key,
    required this.items,
    required this.displayString,
    required this.onSelected,
    required this.hintText,
    this.controller,
    this.validationTitle,
    this.isCompleteNewName = false,
    this.isValidation = true,
    this.onTapRemoveText = true,
    this.isClearController = false,
    this.enabled = true,
    this.hintTextColor,
  });

  @override
  State<CommonSearchableDropdown3<T>> createState() =>
      _CommonSearchableDropdownState3<T>();
}

class _CommonSearchableDropdownState3<T extends Object>
    extends State<CommonSearchableDropdown3<T>> {
  late final TextEditingController _displayController;

  bool _dropdownOpen = false;
  bool _isScrolling = false;

  @override
  void initState() {
    super.initState();
    _displayController = widget.controller ?? TextEditingController();
  }

  @override
  void dispose() {
    if (widget.controller == null) {
      _displayController.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return DropdownButtonHideUnderline(
      child: DropdownButton2<T>(
        // 1. We removed the GlobalKeys entirely.
        isExpanded: true,

        // 2. YOUR CUSTOM UI & SAFE TAP HIJACKER
        customButton: Builder(
          builder: (buttonContext) {
            return GestureDetector(
              onTap: () async {
                if (!widget.enabled || _isScrolling) return;

                setState(() => _isScrolling = true);

                // A. Scroll exactly to this field, placing it in the middle (0.5)
                await Scrollable.ensureVisible(
                  buttonContext,
                  alignment: 0.5,
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeInOut,
                );

                // B. Wait a tiny bit to let the layout recalculate its new center position
                await Future.delayed(const Duration(milliseconds: 50));

                if (mounted) {
                  setState(() => _isScrolling = false);
                }

                // C. THE NATIVE FLUTTER TRICK:
                // Look up the widget tree, find the package's internal button, and click it safely!
                final inkWell = buttonContext
                    .findAncestorWidgetOfExactType<InkWell>();
                if (inkWell?.onTap != null) {
                  inkWell!.onTap!();
                  return;
                }

                // Fallback just in case the package uses GestureDetector instead
                final detector = buttonContext
                    .findAncestorWidgetOfExactType<GestureDetector>();
                if (detector?.onTap != null) {
                  detector!.onTap!();
                }
              },
              child: AbsorbPointer(
                absorbing: true,
                child: CommonTextField(
                  enabled: widget.enabled,
                  controller: _displayController,
                  hintText: widget.hintText,
                  hintTextColor: widget.hintTextColor,
                  isDropDown: true,
                  readOnly: true,

                  suffixIcon: widget.enabled
                      ? AnimatedRotation(
                          turns: _dropdownOpen ? 0.5 : 0.0,
                          duration: const Duration(milliseconds: 200),
                          child: const Icon(Icons.keyboard_arrow_down),
                        )
                      : null,

                  validator: widget.isValidation
                      ? (value) => validateRequired(
                          value,
                          fieldName: widget.validationTitle ?? "Field",
                          isCompleteNewName: widget.isCompleteNewName,
                          maxLength: 50000,
                          isImplementMinCheck: false,
                        )
                      : null,
                ),
              ),
            );
          },
        ),

        // 3. MAPPING ITEMS
        items: widget.items.map((item) {
          return DropdownItem<T>(
            value: item,
            height: 60,
            child: AppText(
              text: widget.displayString(item),
              fontSize: 15,
              fontWeight: FontWeight.w400,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          );
        }).toList(),

        // 4. SELECTION LOGIC
        onChanged: widget.enabled
            ? (value) {
                if (value != null) {
                  _displayController.text = widget.displayString(value);
                  widget.onSelected(value);
                }
              }
            : null,

        onMenuStateChange: (isOpen) {
          setState(() => _dropdownOpen = isOpen);
          if (isOpen && widget.onTapRemoveText) {
            _displayController.clear();
          }
        },

        // 5. SAFE AREA AND CONSTRAINTS
        dropdownStyleData: DropdownStyleData(
          maxHeight: 300,
          useSafeArea: true,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8.r),
            color: Theme.of(context).colorScheme.onPrimary,
          ),
          elevation: 4,
          offset: const Offset(0, -5),
        ),

        dropdownSeparator: DropdownSeparator(
          height: 1,
          child: Divider(
            height: 1,
            thickness: 1.5,
            color: Theme.of(context).dividerColor,
            // Subtle divider
            indent: 12,
            // Optional: matches the horizontal padding of the text
            endIndent: 12,
          ),
        ),

        menuItemStyleData: MenuItemStyleData(
          padding: EdgeInsets.symmetric(horizontal: 12.w),
        ),
      ),
    );
  }
}
