import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../core/ui/app_notice.dart';
import '../../application/archive_service.dart';

class ArchivePage extends StatefulWidget {
  const ArchivePage({super.key});

  @override
  State<ArchivePage> createState() => _ArchivePageState();
}

class _ArchivePageState extends State<ArchivePage> {
  late Future<List<ArchivedRecord>> _recordsFuture;

  @override
  void initState() {
    super.initState();
    _recordsFuture = ArchiveService.instance.getArchivedRecords();
  }

  Future<void> _reload() async {
    setState(() {
      _recordsFuture = ArchiveService.instance.getArchivedRecords();
    });
  }

  Future<void> _restore(ArchivedRecord record) async {
    try {
      await ArchiveService.instance.restoreRecord(record);
      await _reload();
      if (!mounted) return;
      AppNotice.success('${ArchiveService.instance.typeLabel(record.type)} restored.');
    } catch (error) {
      if (!mounted) return;
      AppNotice.error(error.toString());
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Archives')),
      body: FutureBuilder<List<ArchivedRecord>>(
        future: _recordsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text(snapshot.error.toString()));
          }

          final records = snapshot.data ?? const <ArchivedRecord>[];
          if (records.isEmpty) {
            return const Center(child: Text('No archived records.'));
          }

          return RefreshIndicator(
            onRefresh: _reload,
            child: ListView.separated(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(16),
              itemCount: records.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (context, index) {
                final record = records[index];
                final typeLabel = ArchiveService.instance.typeLabel(record.type);
                return Card(
                  child: ListTile(
                    title: Text(record.title),
                    subtitle: Text(
                      '$typeLabel${record.subtitle.isEmpty ? '' : ' • ${record.subtitle}'}\nArchived: ${DateFormat('MMM d, y h:mm a').format(record.archivedAt)}',
                    ),
                    isThreeLine: true,
                    trailing: FilledButton.tonal(
                      onPressed: () => _restore(record),
                      child: const Text('Restore'),
                    ),
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }
}
