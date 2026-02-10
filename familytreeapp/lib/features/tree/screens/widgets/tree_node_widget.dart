import 'package:flutter/material.dart';
import '../../models/tree_model.dart'; // Fixed path

class TreeNodeWidget extends StatelessWidget {
  final TreeNode member;
  final TreeNode? spouse;
  final VoidCallback onTap;
  final VoidCallback? onTapSpouse;
  final bool isEditMode;
  final bool isHighlighted;
  final Function(TreeNode, Alignment)? onAddClick;

  const TreeNodeWidget({
    super.key,
    required this.member,
    this.spouse,
    required this.onTap,
    this.onTapSpouse,
    this.isEditMode = false,
    this.isHighlighted = false,
    this.onAddClick,
  });

  @override
  Widget build(BuildContext context) {
    if (spouse != null) {
      return _buildCoupleNode(context);
    }
    return _buildSingleNode(context, member, onTap);
  }

  Widget _buildCoupleNode(BuildContext context) {
    // Determine overall width: 2 cards (100 each) + spacing (24) = 224
    const double width = 224;
    
    return Stack(
      clipBehavior: Clip.none,
      children: [
        SizedBox(
          width: width,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Member Block (Card + Specific Buttons including Bottom)
              _buildnodeWithButtons(context, member, onTap, 
                  hasLeft: true, hasTop: true, hasRight: false, hasBottom: true),
              
              SizedBox(
                width: 24,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    Container(height: 2, color: Colors.black54), // Marriage Line
                    const Icon(Icons.favorite, size: 14, color: Colors.pinkAccent), 
                  ],
                ),
              ),

              // Spouse Block (Card + Buttons including Bottom)
              _buildnodeWithButtons(context, spouse!, onTapSpouse ?? () {}, 
                  hasLeft: false, hasTop: true, hasRight: true, hasBottom: true),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSingleNode(BuildContext context, TreeNode node, VoidCallback onTapCallback) {
     return _buildnodeWithButtons(context, node, onTapCallback, 
        hasLeft: true, hasTop: true, hasRight: true, hasBottom: true);
  }

  // Wrapper for Card + Local Buttons
  Widget _buildnodeWithButtons(BuildContext context, TreeNode node, VoidCallback onTapCallback, {
    required bool hasLeft, required bool hasTop, required bool hasRight, required bool hasBottom
  }) {
      return Stack(
          clipBehavior: Clip.none,
          children: [
              _buildCard(context, node, onTapCallback),
              if (isEditMode) ...[
                 if (hasTop) _buildAddPoint(Alignment.topCenter, Icons.add, target: node),
                 if (hasBottom) _buildAddPoint(Alignment.bottomCenter, Icons.add, target: node),
                 if (hasLeft) _buildAddPoint(Alignment.centerLeft, Icons.add, target: node),
                 if (hasRight) _buildAddPoint(Alignment.centerRight, Icons.add, target: node),
              ]
          ],
      );
  }

  Widget _buildCard(BuildContext context, TreeNode node, VoidCallback onTapCallback) {
    final isMale = node.gender.toLowerCase() == "male" || node.gender == "nam";
    Color mainColor = isMale ? const Color(0xFF42A5F5) : const Color(0xFFEC407A);
    if (isHighlighted && node == member) mainColor = Colors.green; 
    
    return InkWell(
      onTap: onTapCallback,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        width: 100,
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: mainColor, width: 1.0),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                shape: BoxShape.circle,
                image: (node.avatarUrl != null && node.avatarUrl!.isNotEmpty) 
                    ? DecorationImage(image: NetworkImage(node.avatarUrl!), fit: BoxFit.cover) 
                    : null,
              ),
              child: (node.avatarUrl == null || node.avatarUrl!.isEmpty)
                  ? const Icon(Icons.person, color: Colors.white, size: 30)
                  : null,
            ),
            const SizedBox(height: 8),
            Text(
              node.name,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 10, color: Colors.black87),
            ),
            const SizedBox(height: 4),
            Text(
              _getBirthYearDisplay(node),
              style: TextStyle(fontSize: 10, color: Colors.grey[600]),
            ),
          ],
        ),
      ),
    );
  }

  String _getBirthYearDisplay(TreeNode node) {
    // Nếu birthYear đã có và không phải "N/A" hoặc "?", dùng luôn
    if (node.birthYear != "N/A" && node.birthYear != "?" && node.birthYear.isNotEmpty) {
      return node.birthYear;
    }
    
    // Thử extract năm từ dob (format: YYYY-MM-DD hoặc DD/MM/YYYY)
    if (node.dob != null && node.dob!.isNotEmpty) {
      try {
        // Format YYYY-MM-DD
        if (node.dob!.contains('-')) {
          final parts = node.dob!.split('-');
          if (parts.isNotEmpty && parts[0].length == 4) {
            return parts[0];
          }
        }
        // Format DD/MM/YYYY
        if (node.dob!.contains('/')) {
          final parts = node.dob!.split('/');
          if (parts.length == 3 && parts[2].length == 4) {
            return parts[2];
          }
        }
      } catch (e) {
        // Ignore parse errors
      }
    }
    
    // Không có thông tin
    return "?";
  }

  Widget _buildAddPoint(Alignment alignment, IconData icon, {required TreeNode target, bool isCouple = false, bool isJoint = false}) {
    // If isCouple (Bottom Shared), we need to adjust position relative to width 224
    // But since it is in Stack, alignment calculates correctly. 
    // Just need translation offset to not overlap border.
    
    return Positioned.fill(
      child: Align(
        alignment: alignment,
        child: InkWell(
          onTap: () {
            print("DEBUG TreeNodeWidget: Add button tapped! target=${target.name}, alignment=$alignment");
            onAddClick?.call(target, alignment);
          },
          child: Container(
            transform: Matrix4.translationValues(
              alignment == Alignment.centerLeft ? -8 : (alignment == Alignment.centerRight ? 8 : 0),
              alignment == Alignment.topCenter ? -8 : (alignment == Alignment.bottomCenter ? 8 : 0),
              0,
            ),
            width: 16,
            height: 16,
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              border: Border.all(color: Colors.blue, width: 1.5),
              boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 2)],
            ),
            child: Icon(icon, size: 10, color: Colors.blue),
          ),
        ),
      ),
    );
  }
}
