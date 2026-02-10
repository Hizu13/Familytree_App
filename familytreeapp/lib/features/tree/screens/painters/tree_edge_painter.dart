import 'package:flutter/material.dart';
import 'package:graphview/GraphView.dart';

class TreeEdgePainter extends CustomPainter {
  final Graph graph;
  final Map<String, String> edgeTypes; // Key: "srcId-dstId", Value: "COMMON", "PRIMARY", "SECONDARY"
  final Set<int> coupleNodeIds; // Set of IDs that are visually Couple Nodes (Width 224)
  final Paint _paint;

  TreeEdgePainter(this.graph, this.edgeTypes, this.coupleNodeIds)
      : _paint = Paint()
          ..color = Colors.grey[400]!
          ..strokeWidth = 1.5
          ..style = PaintingStyle.stroke;

  @override
  void paint(Canvas canvas, Size size) {
    if (graph.nodes.isEmpty) return;

    for (final edge in graph.edges) {
      final source = edge.source;
      final dest = edge.destination;

      final srcId = source.key?.value as int?;
      final dstId = dest.key?.value as int?;

      if (srcId == null || dstId == null) continue;
      if (srcId == -9999999) continue; 

      final edgeKey = "$srcId-$dstId";
      final type = edgeTypes[edgeKey] ?? "COMMON";

      // Calculate positions
      double srcWidth = 100;
      if (srcId < 0) {
        srcWidth = 1; 
      } else if (coupleNodeIds.contains(srcId)) {
        srcWidth = 224;
      }
      
      // Default positions (Center of Node)
      var srcX = source.x + (srcWidth / 2); 
      var srcY = source.y + source.height; 
      var dstX = dest.x + (dest.width / 2);
      var dstY = dest.y;

      // Apply Offsets
      if (type == "PRIMARY") { // Con riêng chồng (Left)
         srcX = source.x + 50.0;
      } else if (type == "SECONDARY") { // Con riêng vợ (Right)
         srcX = source.x + 174.0;
      }

      final path = Path();
      path.moveTo(srcX, srcY);
      
      final midY = srcY + (dstY - srcY) / 2;
      
      path.lineTo(srcX, midY);
      path.lineTo(dstX, midY);
      path.lineTo(dstX, dstY);

      canvas.drawPath(path, _paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
