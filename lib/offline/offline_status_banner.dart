import 'package:flutter/material.dart';
import 'offline_content_service.dart';

class OfflineStatusBanner extends StatelessWidget {
  const OfflineStatusBanner({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<bool>(
      stream: OfflineContentService.instance.connectionStream,
      initialData: OfflineContentService.instance.isOnline,
      builder: (context, snapshot) {
        final online = snapshot.data ?? true;
        return AnimatedSwitcher(
          duration: const Duration(milliseconds: 260),
          child: online
              ? const SizedBox.shrink(key: ValueKey('online'))
              : Container(
                  key: const ValueKey('offline'),
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 9,
                  ),
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Color(0xFFF59E0B), Color(0xFFF97316)],
                    ),
                  ),
                  child: const SafeArea(
                    bottom: false,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.cloud_off_rounded,
                          color: Colors.white,
                          size: 17,
                        ),
                        SizedBox(width: 8),
                        Flexible(
                          child: Text(
                            'Offline mode • showing saved practice',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w800,
                              fontSize: 11,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
        );
      },
    );
  }
}

class OfflineAvailabilityChip extends StatelessWidget {
  const OfflineAvailabilityChip({super.key});

  @override
  Widget build(BuildContext context) {
    if (OfflineContentService.instance.isOnline) return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: const Color(0xFF22C55E).withOpacity(.12),
        borderRadius: BorderRadius.circular(100),
        border: Border.all(color: const Color(0xFF22C55E).withOpacity(.30)),
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.offline_pin_rounded, color: Color(0xFF22C55E), size: 14),
          SizedBox(width: 5),
          Text(
            'Offline available',
            style: TextStyle(
              color: Color(0xFF22C55E),
              fontSize: 9,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}
