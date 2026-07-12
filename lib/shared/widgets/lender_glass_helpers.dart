// lib/shared/widgets/lender_glass_helpers.dart

import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import 'glass_card.dart';

class LGlassCollapsibleSection extends StatelessWidget {
  final IconData icon;
  final String title;
  final bool expanded;
  final Color accent;
  final VoidCallback onToggle;
  final Widget child;
  const LGlassCollapsibleSection({
    super.key,
    required this.icon,
    required this.title,
    required this.expanded,
    required this.accent,
    required this.onToggle,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      padding: EdgeInsets.zero,
      child: Column(children: [
        InkWell(
          onTap: onToggle,
          borderRadius: BorderRadius.circular(20),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                    color: accent.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8)),
                child: Icon(icon, color: accent, size: 16),
              ),
              const SizedBox(width: 12),
              Expanded(
                  child: Text(title,
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.w600))),
              AnimatedRotation(
                turns: expanded ? 0.5 : 0,
                duration: const Duration(milliseconds: 200),
                child: Icon(Icons.keyboard_arrow_down_rounded,
                    color: Colors.white.withValues(alpha: 0.5), size: 22),
              ),
            ]),
          ),
        ),
        ClipRect(
          child: AnimatedSize(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeInOut,
            child: expanded
                ? Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                    child: child)
                : const SizedBox.shrink(),
          ),
        ),
      ]),
    );
  }
}

class LGlassHeader extends StatelessWidget {
  final IconData icon;
  final String title;
  final Color accent;
  const LGlassHeader(
      {super.key,
      required this.icon,
      required this.title,
      required this.accent});

  @override
  Widget build(BuildContext context) {
    return Row(children: [
      Container(
          padding: const EdgeInsets.all(7),
          decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(8)),
          child: Icon(icon, color: accent, size: 15)),
      const SizedBox(width: 10),
      Text(title,
          style: const TextStyle(
              color: Colors.white, fontSize: 15, fontWeight: FontWeight.w700)),
    ]);
  }
}

class LGlassSwitchTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String? subtitle;
  final bool value;
  final Color accent;
  final ValueChanged<bool> onChanged;
  const LGlassSwitchTile({
    super.key,
    required this.icon,
    required this.label,
    this.subtitle,
    required this.value,
    required this.accent,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(children: [
        Icon(icon, color: Colors.white54, size: 20),
        const SizedBox(width: 14),
        Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label,
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w500)),
          if (subtitle != null)
            Text(subtitle!,
                style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.5), fontSize: 11)),
        ])),
        Switch(
            value: value,
            onChanged: onChanged,
            activeTrackColor: accent,
            activeThumbColor: Colors.white),
      ]),
    );
  }
}

class LGlassTapTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String? subtitle;
  final VoidCallback onTap;
  final Widget? trailing;
  const LGlassTapTile({
    super.key,
    required this.icon,
    required this.label,
    this.subtitle,
    required this.onTap,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(children: [
          Icon(icon, color: Colors.white54, size: 20),
          const SizedBox(width: 14),
          Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                Text(label,
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w500)),
                if (subtitle != null)
                  Text(subtitle!,
                      style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.5),
                          fontSize: 11)),
              ])),
          trailing ??
              Icon(Icons.chevron_right_rounded,
                  color: Colors.white.withValues(alpha: 0.3), size: 20),
        ]),
      ),
    );
  }
}

class LGlassDivider extends StatelessWidget {
  const LGlassDivider({super.key});
  @override
  Widget build(BuildContext context) => Divider(
      height: 1, indent: 50, color: Colors.white.withValues(alpha: 0.08));
}

class LGlassInfoRow extends StatelessWidget {
  final String label;
  final String value;
  final Color? valueColor;
  const LGlassInfoRow(
      {super.key, required this.label, required this.value, this.valueColor});

  @override
  Widget build(BuildContext context) {
    return Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
      Text(label,
          style: TextStyle(
              color: Colors.white.withValues(alpha: 0.55), fontSize: 12)),
      Text(value,
          style: TextStyle(
              color: valueColor ?? Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w600)),
    ]);
  }
}

class LGlassBadge extends StatelessWidget {
  final String label;
  final Color color;
  const LGlassBadge({super.key, required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
          color: color.withValues(alpha: 0.20),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: color.withValues(alpha: 0.4))),
      child: Text(label,
          style: TextStyle(
              fontSize: 11, fontWeight: FontWeight.w600, color: color)),
    );
  }
}

class LGlassStatusBadge extends StatelessWidget {
  final bool active;
  const LGlassStatusBadge({super.key, required this.active});

  @override
  Widget build(BuildContext context) {
    final color = active ? AppColors.success : AppColors.error;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
          color: color.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withValues(alpha: 0.4))),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 5),
        Text(active ? 'Active' : 'Inactive',
            style: TextStyle(
                color: color, fontSize: 11, fontWeight: FontWeight.w600)),
      ]),
    );
  }
}

class GlassEntranceWrapper extends StatefulWidget {
  final Widget child;
  final Duration duration;
  final Offset slideBegin;
  const GlassEntranceWrapper({
    super.key,
    required this.child,
    this.duration = const Duration(milliseconds: 480),
    this.slideBegin = const Offset(0, 0.06),
  });

  @override
  State<GlassEntranceWrapper> createState() => _GlassEntranceWrapperState();
}

class _GlassEntranceWrapperState extends State<GlassEntranceWrapper>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _fade;
  late final Animation<Offset> _slide;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: widget.duration);
    _fade = CurvedAnimation(parent: _ctrl, curve: Curves.easeOut);
    _slide = Tween<Offset>(begin: widget.slideBegin, end: Offset.zero)
        .animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic));
    _ctrl.forward();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _fade,
      child: SlideTransition(position: _slide, child: widget.child),
    );
  }
}

class GlassStaggeredItem extends StatelessWidget {
  final int index;
  final Animation<double> parent;
  final Widget child;
  const GlassStaggeredItem({
    super.key,
    required this.index,
    required this.parent,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    final start = (index * 0.07).clamp(0.0, 0.9);
    final end = (start + 0.4).clamp(0.0, 1.0);
    final fade = Tween<double>(begin: 0, end: 1).animate(CurvedAnimation(
        parent: parent, curve: Interval(start, end, curve: Curves.easeOut)));
    final slide = Tween<Offset>(begin: const Offset(0, 0.12), end: Offset.zero)
        .animate(CurvedAnimation(
            parent: parent,
            curve: Interval(start, end, curve: Curves.easeOutCubic)));
    return FadeTransition(
        opacity: fade, child: SlideTransition(position: slide, child: child));
  }
}
