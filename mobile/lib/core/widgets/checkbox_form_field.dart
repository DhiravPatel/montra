import 'package:flutter/material.dart';

/// A [CheckboxListTile] that takes part in [Form] validation and shows its
/// error under the label (field-associated errors, spec §16).
class CheckboxFormField extends FormField<bool> {
  /// Creates the field.
  CheckboxFormField({
    required Widget title,
    super.validator,
    super.onSaved,
    bool initialValue = false,
    ValueChanged<bool>? onChanged,
    String? errorText,
    super.key,
  }) : super(
         initialValue: initialValue,
         builder: (FormFieldState<bool> state) {
           final String? error = state.errorText ?? errorText;
           final ThemeData theme = Theme.of(state.context);
           return Column(
             crossAxisAlignment: CrossAxisAlignment.start,
             children: <Widget>[
               CheckboxListTile(
                 value: state.value ?? false,
                 contentPadding: EdgeInsets.zero,
                 controlAffinity: ListTileControlAffinity.leading,
                 isError: error != null,
                 title: title,
                 onChanged: (bool? value) {
                   final bool checked = value ?? false;
                   state.didChange(checked);
                   onChanged?.call(checked);
                 },
               ),
               if (error != null)
                 Padding(
                   padding: const EdgeInsets.only(left: 12, bottom: 4),
                   child: Text(
                     error,
                     style: theme.textTheme.bodySmall?.copyWith(
                       color: theme.colorScheme.error,
                     ),
                   ),
                 ),
             ],
           );
         },
       );
}
