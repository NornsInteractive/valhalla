import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/layout_breakpoints.dart';
import '../../../core/design/tokens.dart';
import '../../../core/extensions/context_extensions.dart';
import '../../../core/providers/application_center_provider.dart';
import '../../../core/providers/server_provider.dart';
import '../../../data/models/application_center.dart';
import 'app_center_error_resolver.dart';

class AppSourcesDialog extends ConsumerStatefulWidget {
  const AppSourcesDialog({super.key});

  static Future<void> show(BuildContext context) {
    return showDialog<void>(
      context: context,
      builder: (_) => const AppSourcesDialog(),
    );
  }

  @override
  ConsumerState<AppSourcesDialog> createState() => _AppSourcesDialogState();
}

class _AppSourcesDialogState extends ConsumerState<AppSourcesDialog> {
  late List<ApplicationSource> _sources;
  bool _isSaving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _sources = List.of(ref.read(applicationCenterProvider).sources);
  }

  Future<void> _toggleSource(int index, bool enabled) async {
    final capturedKey = ref.read(activeServerProvider)?.connectionKey;
    if (!mounted ||
        ref.read(activeServerProvider)?.connectionKey != capturedKey) {
      return;
    }
    if (index < 0 || index >= _sources.length) return;
    final updated = List<ApplicationSource>.from(_sources);
    updated[index] = updated[index].copyWith(enabled: enabled);
    setState(() {
      _sources = updated;
    });
    await _saveChanges();
  }

  Future<void> _removeSource(int index) async {
    final capturedKey = ref.read(activeServerProvider)?.connectionKey;
    if (!mounted ||
        ref.read(activeServerProvider)?.connectionKey != capturedKey) {
      return;
    }
    if (index < 0 || index >= _sources.length) return;
    final source = _sources[index];
    if (source.id == ApplicationSource.official.id) return;
    final updated = List<ApplicationSource>.from(_sources)..removeAt(index);
    setState(() {
      _sources = updated;
    });
    await _saveChanges();
  }

  Future<void> _saveChanges() async {
    final capturedKey = ref.read(activeServerProvider)?.connectionKey;
    if (capturedKey == null) return;
    setState(() {
      _isSaving = true;
      _error = null;
    });
    try {
      await ref.read(applicationCenterProvider.notifier).saveSources(_sources);
      if (!mounted ||
          ref.read(activeServerProvider)?.connectionKey != capturedKey) {
        return;
      }
    } catch (e) {
      if (mounted &&
          ref.read(activeServerProvider)?.connectionKey == capturedKey) {
        setState(() {
          _error = e is ApplicationCenterException
              ? resolveAppCenterErrorMessage(context, e.code, e.detail)
              : e.toString();
        });
      }
    } finally {
      if (mounted &&
          ref.read(activeServerProvider)?.connectionKey == capturedKey) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  Future<void> _showAddSourceDialog() async {
    final capturedKey = ref.read(activeServerProvider)?.connectionKey;
    final nameCtrl = TextEditingController();
    final urlCtrl = TextEditingController(text: 'https://');
    final formKey = GlobalKey<FormState>();

    String? newName;
    String? newUrl;
    bool? confirmed;
    try {
      confirmed = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text(ctx.l10n.appCenterAddSource),
          content: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: nameCtrl,
                  decoration: InputDecoration(
                    labelText: ctx.l10n.appCenterSourceName,
                    hintText: ctx.l10n.appCenterSourceCommunityHint,
                  ),
                  validator: (val) {
                    if (val == null || val.trim().isEmpty) {
                      return ctx.l10n.appCenterFieldRequired;
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: urlCtrl,
                  decoration: InputDecoration(
                    labelText: ctx.l10n.appCenterSourceUrl,
                    hintText: 'https://example.com/appstore',
                  ),
                  keyboardType: TextInputType.url,
                  validator: (val) {
                    if (val == null || val.trim().isEmpty) {
                      return ctx.l10n.appCenterFieldRequired;
                    }
                    final uri = Uri.tryParse(val.trim());
                    if (uri == null ||
                        uri.scheme != 'https' ||
                        uri.host.isEmpty) {
                      return ctx.l10n.appCenterSourceUrlInvalidHttps;
                    }
                    return null;
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(ctx.l10n.cancel),
            ),
            FilledButton(
              onPressed: () {
                if (formKey.currentState?.validate() == true) {
                  newName = nameCtrl.text.trim();
                  newUrl = urlCtrl.text.trim();
                  Navigator.pop(ctx, true);
                }
              },
              child: Text(ctx.l10n.confirm),
            ),
          ],
        ),
      );
    } finally {
      nameCtrl.dispose();
      urlCtrl.dispose();
    }

    if (confirmed == true &&
        mounted &&
        ref.read(activeServerProvider)?.connectionKey == capturedKey &&
        newName != null &&
        newUrl != null) {
      final newSource = ApplicationSource(
        id: 'source-${DateTime.now().millisecondsSinceEpoch}',
        name: newName!,
        url: newUrl!,
        enabled: true,
      );
      setState(() {
        _sources = [..._sources, newSource];
      });
      await _saveChanges();
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(applicationCenterProvider);
    final sourceErrors = state.sourceErrors;

    return AlertDialog(
      title: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(context.l10n.appCenterManageSources),
          if (_isSaving || state.loadingCatalog)
            const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
        ],
      ),
      content: ConstrainedBox(
        constraints: const BoxConstraints(
          maxWidth: LayoutBreakpoints.modalSheetMaxWidth,
          maxHeight: 480,
        ),
        child: SizedBox(
          width: double.maxFinite,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (_error != null) ...[
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: context.colorScheme.errorContainer,
                    borderRadius: BorderRadius.circular(VRadius.card),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.error_outline,
                        size: 16,
                        color: context.colorScheme.onErrorContainer,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _error!,
                          style: TextStyle(
                            fontSize: 12,
                            color: context.colorScheme.onErrorContainer,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
              ],
              Flexible(
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: _sources.length,
                  separatorBuilder: (_, _) => const Divider(height: 1),
                  itemBuilder: (ctx, index) {
                    final source = _sources[index];
                    final isOfficial =
                        source.id == ApplicationSource.official.id;
                    final sourceError = sourceErrors[source.id];

                    return ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: Icon(
                        isOfficial ? Icons.verified : Icons.source,
                        color: source.enabled
                            ? context.colorScheme.primary
                            : context.colorScheme.outline,
                      ),
                      title: Text(
                        source.name,
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                          color: source.enabled
                              ? null
                              : context.colorScheme.outline,
                        ),
                      ),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            source.url,
                            style: TextStyle(
                              fontSize: 11,
                              color: context.colorScheme.outline,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          if (sourceError != null)
                            Padding(
                              padding: const EdgeInsets.only(top: 2),
                              child: Text(
                                sourceError,
                                style: TextStyle(
                                  fontSize: 11,
                                  color: context.colorScheme.error,
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                        ],
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Switch(
                            value: source.enabled,
                            onChanged: _isSaving
                                ? null
                                : (val) => _toggleSource(index, val),
                          ),
                          if (!isOfficial)
                            IconButton(
                              icon: Icon(
                                Icons.delete_outline,
                                size: 18,
                                color: context.vDanger,
                              ),
                              tooltip: context.l10n.appCenterDeleteSource,
                              onPressed: _isSaving
                                  ? null
                                  : () => _removeSource(index),
                            ),
                        ],
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                icon: const Icon(Icons.add, size: 16),
                label: Text(context.l10n.appCenterAddSource),
                onPressed: _isSaving ? null : _showAddSourceDialog,
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(context.l10n.confirm),
        ),
      ],
    );
  }
}
