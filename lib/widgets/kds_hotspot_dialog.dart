import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../providers/pos_provider.dart';
import '../theme/celestial_theme.dart';

class KdsHotspotDialog extends StatefulWidget {
  const KdsHotspotDialog({super.key});

  @override
  State<KdsHotspotDialog> createState() => _KdsHotspotDialogState();
}

class _KdsHotspotDialogState extends State<KdsHotspotDialog> {
  late TextEditingController _ipController;

  @override
  void initState() {
    super.initState();
    final provider = Provider.of<PosProvider>(context, listen: false);
    _ipController = TextEditingController(text: provider.kdsServer.localIp);
  }

  @override
  void dispose() {
    _ipController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<PosProvider>(context);
    final isMobile = MediaQuery.of(context).size.width < 600;
    final serverUrl = provider.kdsServer.serverUrl;
    final clientCount = provider.kdsServer.clientCount;

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: EdgeInsets.symmetric(
        horizontal: isMobile ? 12 : 24,
        vertical: isMobile ? 16 : 24,
      ),
      child: Container(
        width: isMobile ? double.infinity : 480,
        decoration: BoxDecoration(
          color: CelestialTheme.bgSurface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: CelestialTheme.goldPrimary.withValues(alpha: 0.4),
            width: 1.2,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.8),
              blurRadius: 28,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              decoration: const BoxDecoration(
                color: CelestialTheme.bgCard,
                borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.wifi_tethering_rounded, color: CelestialTheme.goldPrimary, size: 22),
                      const SizedBox(width: 10),
                      Text(
                        'Barista Phone Connect (Hotspot)',
                        style: GoogleFonts.outfit(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: CelestialTheme.textLight,
                        ),
                      ),
                    ],
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close_rounded, color: CelestialTheme.textMuted),
                    splashRadius: 18,
                  ),
                ],
              ),
            ),

            const Divider(height: 1),

            // Content
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  // Status Badge
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      color: provider.kdsServer.isRunning
                          ? CelestialTheme.emeraldReady.withValues(alpha: 0.15)
                          : CelestialTheme.roseAlert.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: provider.kdsServer.isRunning
                            ? CelestialTheme.emeraldReady.withValues(alpha: 0.4)
                            : CelestialTheme.roseAlert.withValues(alpha: 0.4),
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: provider.kdsServer.isRunning
                                ? CelestialTheme.emeraldReady
                                : CelestialTheme.roseAlert,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          provider.kdsServer.isRunning
                              ? (clientCount > 0
                                  ? '🟢 Server Live • $clientCount Barista Connected'
                                  : '🟢 Server Live • Ready on ${provider.kdsServer.localIp}')
                              : '🔴 Server Offline',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: provider.kdsServer.isRunning
                                ? CelestialTheme.emeraldReady
                                : CelestialTheme.roseAlert,
                          ),
                        ),
                        const Spacer(),
                        InkWell(
                          onTap: () async {
                            await provider.restartKdsServer();
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  backgroundColor: CelestialTheme.bgCard,
                                  content: Text(provider.kdsServer.isRunning
                                      ? '⚡ Server online at ${provider.kdsServer.serverUrl}'
                                      : '⚠️ Server offline. Please check hotspot.'),
                                ),
                              );
                            }
                          },
                          borderRadius: BorderRadius.circular(6),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: CelestialTheme.goldPrimary.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(color: CelestialTheme.goldPrimary.withValues(alpha: 0.4)),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.refresh_rounded, size: 13, color: CelestialTheme.goldLight),
                                SizedBox(width: 4),
                                Text(
                                  'Restart',
                                  style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: CelestialTheme.goldLight),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),

                  // QR Code Card
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: CelestialTheme.goldPrimary.withValues(alpha: 0.25),
                          blurRadius: 16,
                        ),
                      ],
                    ),
                    child: QrImageView(
                      data: serverUrl,
                      version: QrVersions.auto,
                      size: isMobile ? 160 : 180,
                      backgroundColor: Colors.white,
                      eyeStyle: const QrEyeStyle(
                        eyeShape: QrEyeShape.square,
                        color: Color(0xFF1E1720),
                      ),
                      dataModuleStyle: const QrDataModuleStyle(
                        dataModuleShape: QrDataModuleShape.square,
                        color: Color(0xFF1E1720),
                      ),
                    ),
                  ),

                  const SizedBox(height: 14),

                  // URL Chip & Copy Button
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: CelestialTheme.bgCard,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: CelestialTheme.goldPrimary.withValues(alpha: 0.3)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Icon(Icons.link_rounded, color: CelestialTheme.goldPrimary, size: 16),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            serverUrl,
                            style: GoogleFonts.outfit(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              color: CelestialTheme.goldLight,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        InkWell(
                          onTap: () {
                            Clipboard.setData(ClipboardData(text: serverUrl));
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                backgroundColor: CelestialTheme.bgCard,
                                content: Text('📋 KDS Link copied to clipboard!'),
                              ),
                            );
                          },
                          child: const Padding(
                            padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            child: Row(
                              children: [
                                Icon(Icons.copy_rounded, size: 13, color: CelestialTheme.goldPrimary),
                                SizedBox(width: 4),
                                Text(
                                  'Copy',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    color: CelestialTheme.goldLight,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),

                  // 3-Step Instructions
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: CelestialTheme.bgCard,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'HOW TO CONNECT (100% OFFLINE):',
                          style: GoogleFonts.outfit(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.8,
                            color: CelestialTheme.goldLight,
                          ),
                        ),
                        const SizedBox(height: 6),
                        _buildStep('1', 'Turn on Mobile Hotspot on this host phone.'),
                        _buildStep('2', 'Connect Barista phone to this Hotspot Wi-Fi.'),
                        _buildStep('3', 'Scan the QR code above (or open browser to $serverUrl).'),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const Divider(height: 1),

            // Footer
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: CelestialTheme.goldPrimary,
                    foregroundColor: CelestialTheme.bgDark,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  child: const Text('Done', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStep(String num, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 16,
            height: 16,
            alignment: Alignment.center,
            decoration: const BoxDecoration(
              color: CelestialTheme.goldPrimary,
              shape: BoxShape.circle,
            ),
            child: Text(
              num,
              style: const TextStyle(
                fontSize: 9,
                fontWeight: FontWeight.bold,
                color: CelestialTheme.bgDark,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(fontSize: 11, color: CelestialTheme.textLight, height: 1.3),
            ),
          ),
        ],
      ),
    );
  }
}
