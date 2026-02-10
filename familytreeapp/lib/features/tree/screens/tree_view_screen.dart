import 'package:flutter/material.dart';
import 'package:graphview/GraphView.dart' as gv;
import 'package:flutter_bloc/flutter_bloc.dart';

import 'painters/tree_edge_painter.dart'; // Import Custom Painter

// Import các file trong dự án của bạn (Giữ nguyên đường dẫn của bạn)
import '../models/tree_model.dart';
import 'widgets/tree_node_widget.dart';
import '../../../core/network/api_client.dart'; // Đã sửa đường dẫn cho đúng context thường gặp
import '../../member/screens/member_form_screen.dart';
import '../../member/logic/member_bloc.dart';
import '../../member/logic/member_state.dart';
import '../../member/screens/member_detail_view_screen.dart';

class TreeViewScreen extends StatefulWidget {
  final int familyId;
  const TreeViewScreen({super.key, required this.familyId});

  @override
  State<TreeViewScreen> createState() => _TreeViewScreenState();
}

class _TreeViewScreenState extends State<TreeViewScreen> with TickerProviderStateMixin {
  // 1. Data State
  gv.Graph graph = gv.Graph()..isTree = false;
  final Map<int, TreeNode> _nodeData = {}; // Map lưu data để tra cứu nhanh
  final Map<String, String> _edgeTypes = {}; // Map lưu loại cạnh: COMMON, PRIMARY, SECONDARY
  final Set<int> _coupleNodeIds = {}; // Set lưu các Node là Couple (Width 224)
  bool _isLoading = true;
  String? _error;

  // 2. Control Layout & Animation
  late AnimationController _animationController;
  Animation<Matrix4>? _viewAnimation;
  final TransformationController _transformationController = TransformationController();

  // Cấu hình thuật toán BuchheimWalker (Tốt nhất cho cây gia phả)
  final gv.BuchheimWalkerConfiguration _buchheimBuilder = gv.BuchheimWalkerConfiguration()
    ..siblingSeparation = 20
    ..levelSeparation = 100
    ..subtreeSeparation = 30
    ..orientation = gv.BuchheimWalkerConfiguration.ORIENTATION_TOP_BOTTOM;

  // 3. Search & Interaction State
  int? _selectedFromId;
  int? _selectedToId;
  String _relationshipResult = "";
  bool _isEditMode = false;
  final TextEditingController _searchController = TextEditingController(); // Controller cho tìm kiếm
  
  // 4. Graph Stability & Highlight
  late gv.Algorithm _algorithm;
  Key _graphKey = UniqueKey();
  final Set<String> _highlightedEdgeKeys = {}; // Lưu các cạnh cần tô màu (Format: "id1-id2")
  final Set<int> _highlightedNodeIds = {}; // Lưu các node cần tô màu

  @override
  void initState() {
    super.initState();
    _algorithm = gv.BuchheimWalkerAlgorithm(_buchheimBuilder, gv.TreeEdgeRenderer(_buchheimBuilder));
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    )..addListener(() {
        if (mounted && _viewAnimation != null) {
          _transformationController.value = _viewAnimation!.value;
        }
      });
    
    // Tải dữ liệu ngay khi vào màn hình
    _loadTree();
  }

  @override
  void dispose() {
    _animationController.dispose();
    _transformationController.dispose();
    _searchController.dispose(); // Giải phóng bộ nhớ
    super.dispose();
  }

  /// Hàm tải dữ liệu quan trọng nhất
  Future<void> _loadTree() async {
    try {
      final dio = ApiClient().dio;
      // Gọi API lấy dữ liệu cây (Nodes & Edges)
      final response = await dio.get('/members/${widget.familyId}/tree');
      final treeData = TreeResponse.fromJson(response.data); // Đảm bảo model TreeResponse khớp JSON

      final newGraph = gv.Graph()..isTree = false;
      final nodes = <int, TreeNode>{};
      final Set<int> hiddenNodes = {};
      final Set<int> newCoupleNodeIds = {}; // Temp set for couple nodes
      final Map<int, int> nodeToPrimary = {}; 

      // Pre-process: Identify Spouses and decide Primary/Secondary
      // Map nodes first
      for (var n in treeData.nodes) {
        nodes[n.id] = n;
      }
      
      for (var n in treeData.nodes) {
        if (hiddenNodes.contains(n.id)) continue;
        
        // Check for spouse
        if (n.spouses.isNotEmpty) {
           // Find first available spouse
           int? spouseId;
           for(var sId in n.spouses) {
             if (nodes.containsKey(sId)) {
               spouseId = sId;
               break;
             }
           }
           
           if (spouseId != null) {
              // Decide Primary: Prefer Male, or Lower ID
              final sNode = nodes[spouseId]!;
              bool iAmPrimary = true;
              
              if (n.gender == 'male' && sNode.gender != 'male') {
                iAmPrimary = true;
              } else if (n.gender != 'male' && sNode.gender == 'male') {
                 iAmPrimary = false;
              } else {
                 if (n.id > spouseId) iAmPrimary = false;
              }
              
              if (iAmPrimary) {
                 hiddenNodes.add(spouseId);
                 nodeToPrimary[n.id] = n.id;
                 nodeToPrimary[spouseId] = n.id;
                 newCoupleNodeIds.add(n.id); // Mark Primary as Couple
              } else {
                 hiddenNodes.add(n.id);
                 nodeToPrimary[n.id] = spouseId;
                 nodeToPrimary[spouseId] = spouseId;
                 newCoupleNodeIds.add(spouseId); // Mark Primary as Couple
              }
           } else {
              nodeToPrimary[n.id] = n.id;
           }
        } else {
           nodeToPrimary[n.id] = n.id;
        }
      }

      // Step 1: Add Visual Nodes (Primary Only)
      for (var n in treeData.nodes) {
        if (!hiddenNodes.contains(n.id)) {
           newGraph.addNode(gv.Node.Id(n.id));
        }
      }

      // Step 2: Create Edges (Remap to Primary - Strict Tree)
      final Set<String> processedEdges = {};
      final Map<String, String> newEdgeTypes = {}; // Temp map for edge types

      for (var n in treeData.nodes) {
        final childVisualId = nodeToPrimary[n.id]!;
        
        final fId = n.fatherId;
        final mId = n.motherId;

        final fVisualId = fId != null ? nodeToPrimary[fId] : null;
        final mVisualId = mId != null ? nodeToPrimary[mId] : null;

        final bool hasF = fVisualId != null && nodes.containsKey(fId);
        final bool hasM = mVisualId != null && nodes.containsKey(mId);
        
        int? parentIdToUse;
        
        if (hasF) {
            parentIdToUse = fVisualId;
        } else if (hasM) {
            parentIdToUse = mVisualId;
        }
        
        if (parentIdToUse != null && parentIdToUse == childVisualId) {
             continue; // Skip self loop
        }

        if (parentIdToUse != null) {
            final edgeKey = "$parentIdToUse-$childVisualId";
            if (!processedEdges.contains(edgeKey)) {
                newGraph.addEdge(gv.Node.Id(parentIdToUse), gv.Node.Id(childVisualId));
                processedEdges.add(edgeKey);
                
                // --- Logic xác định loại cạnh ---
                String type = "COMMON";
                final primaryNode = nodes[parentIdToUse]!;
                
                int? sId;
                if (primaryNode.spouses.isNotEmpty) {
                    for(var sp in primaryNode.spouses) {
                         if (nodeToPrimary[sp] == parentIdToUse && sp != parentIdToUse) {
                             sId = sp;
                             break;
                         }
                    }
                }
                
                if (sId != null) {
                     bool matchPrimary = (n.fatherId == parentIdToUse || n.motherId == parentIdToUse);
                     bool matchSecondary = (n.fatherId == sId || n.motherId == sId);
                     
                     if (matchPrimary && matchSecondary) {
                         type = "COMMON";
                     } else if (matchPrimary) {
                         type = "PRIMARY"; 
                     } else if (matchSecondary) {
                         type = "SECONDARY"; 
                     }
                     print("DEBUG EDGE: child=${n.name}, pId=$parentIdToUse, sId=$sId, typ=$type (mP=$matchPrimary, mS=$matchSecondary)");
                }
                newEdgeTypes[edgeKey] = type;
            }
        }
      }
      
      // --- Step 3: Handle Isolated Members (Virtual Root) ---
      // BuchheimWalker requires a single connected component (Tree).
      // Find all roots (nodes with no incoming edges).
      final Set<int> allNodeIds = newGraph.nodes.map((n) => n.key?.value as int).toSet();
      final Set<int> destIds = newGraph.edges.map((e) => e.destination.key?.value as int).toSet();
      final List<int> roots = allNodeIds.where((id) => !destIds.contains(id)).toList();

      const int virtualRootId = -9999999;

      if (roots.length > 1) {
         // Create Virtual Root
         final virtualRoot = gv.Node.Id(virtualRootId);
         newGraph.addNode(virtualRoot);
         
         final transparentPaint = Paint()..color = Colors.transparent;
         
         for (final rootId in roots) {
             newGraph.addEdge(virtualRoot, gv.Node.Id(rootId), paint: transparentPaint);
         }
      }

      if (mounted) {
        setState(() {
          graph = newGraph;
          _nodeData.clear();
          _nodeData.addAll(nodes);
          _edgeTypes.clear();
          _edgeTypes.addAll(newEdgeTypes); 
          _coupleNodeIds.clear();
          _coupleNodeIds.addAll(newCoupleNodeIds);
          _graphKey = UniqueKey(); 
          _isLoading = false;
          _error = null;
        });

        WidgetsBinding.instance.addPostFrameCallback((_) {
          _autoCenterView();
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = "Không tải được sơ đồ: $e";
          _isLoading = false;
        });
      }
    }
  }

  /// Tự động tính toán để đưa cây vào giữa màn hình
  void _autoCenterView({bool animated = true, double? width}) {
    if (!mounted || graph.nodes.isEmpty) return; 
    
    final double actualWidth = width ?? MediaQuery.of(context).size.width;
    
    // Zoom out to 30% to see the whole forest
    final targetMatrix = Matrix4.identity()
      ..translate(actualWidth / 2, 50.0) // Start top-center
      ..scale(0.3); 

    if (animated) {
       _animationController.reset();
       _viewAnimation = Matrix4Tween(
         begin: _transformationController.value,
         end: targetMatrix,
       ).animate(CurvedAnimation(parent: _animationController, curve: Curves.easeInOut));
       _animationController.forward();
    } else {
       _transformationController.value = targetMatrix;
    }
  }


  // --- LOGIC TƯƠNG TÁC (ADD / VIEW) ---

  void _onAddRelative(TreeNode parent, Alignment alignment) {
    print("DEBUG: _onAddRelative called! parent=${parent.name}, alignment=$alignment");
    
    // 1. Logic Thêm Con (Bottom)
    if (alignment == Alignment.bottomCenter) {
       _showAddChildDialog(parent);
       return;
    }

    // 2. Logic Thêm Cha Mẹ (Top)
    if (alignment == Alignment.topCenter) {
       _showAddParentDialog(parent);
       return;
    }

    // 3. Logic Thêm Vợ/Chồng hoặc Anh Em (Left/Right)
    // Ưu tiên thêm Vợ/Chồng ở hai bên.
    if (alignment == Alignment.centerLeft || alignment == Alignment.centerRight) {
       _showAddSpouseDialog(parent);
       return;
    }
  }

  void _showAddChildDialog(TreeNode parent) {
    // Check if node has spouses (For "Con Chung")
    // Assuming TreeNode has 'spouses' list of IDs. 
    // Need to find Spouse Name? If we only have ID, we might need to look up in _nodeData.
    
    // We can iterate _nodeData to find who lists this node as spouse? 
    // Or if TreeNode has `spouses` field.
    
    // Let's assume for now simple logic.
    // If we can't find spouse easily, just show "Con Riêng".
    // But user wants "Con Chung".
    
    List<TreeNode> spouses = [];
    if (parent.spouses.isNotEmpty) {
      for (var sId in parent.spouses) {
         if (_nodeData.containsKey(sId)) {
           spouses.add(_nodeData[sId]!);
         }
      }
    }

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Tạo mối quan hệ", textAlign: TextAlign.center),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 1. Con Riêng always available
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: () {
                  Navigator.pop(ctx);
                  _openForm(parent, "child"); // Default is single child
                },
                child: const Text("Con Riêng"),
              ),
            ),
            const SizedBox(height: 12),

            // 2. Con Chung (Loop through spouses)
            for (var spouse in spouses)
              Padding(
                padding: const EdgeInsets.only(bottom: 8.0),
                child: SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    onPressed: () {
                      Navigator.pop(ctx);
                      _openForm(parent, "child_common", otherParentId: spouse.id);
                    },
                    child: Text("Con của bạn và ${spouse.name}"),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  void _showAddSpouseDialog(TreeNode parent) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Tạo mối quan hệ", textAlign: TextAlign.center),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: () {
                  Navigator.pop(ctx);
                  _openForm(parent, "spouse_wife");
                },
                child: const Text("Vợ"),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: () {
                  Navigator.pop(ctx);
                  _openForm(parent, "spouse_husband");
                },
                child: const Text("Chồng"),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showAddParentDialog(TreeNode parent) {
      showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Thêm Cha / Mẹ", textAlign: TextAlign.center),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: () {
                  Navigator.pop(ctx);
                  _openForm(parent, "father");
                },
                child: const Text("Cha"),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: () {
                  Navigator.pop(ctx);
                  _openForm(parent, "mother");
                },
                child: const Text("Mẹ"),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Điều hướng sang Form thêm thành viên
  Future<void> _openForm(TreeNode relative, String type, {int? otherParentId}) async {
    int? fId, mId, isFOf, isMOf, spId;
    String? initGender;
    
    // Logic điền sẵn ID cha/mẹ/con dựa trên node hiện tại
    if (type == "child" || type == "child_common") {
      // Logic cũ: relative là cha/mẹ
      if (relative.gender.toLowerCase() == "nam" || relative.gender.toLowerCase() == "male") {
        fId = relative.id;
        if (otherParentId != null) mId = otherParentId;
      } else {
        mId = relative.id;
        if (otherParentId != null) fId = otherParentId;
      }
    } else if (type == "father") {
      isFOf = relative.id; 
      initGender = "male";
    } else if (type == "mother") {
      isMOf = relative.id; 
      initGender = "female";
    } else if (type == "spouse_wife") {
      spId = relative.id;
      initGender = "female";
    } else if (type == "spouse_husband") {
      spId = relative.id;
      initGender = "male";
    } else if (type == "sibling") {
      fId = relative.fatherId;
      mId = relative.motherId;
    }
    
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => MemberFormScreen(
          familyId: widget.familyId,
          initialFatherId: fId,
          initialMotherId: mId,
          isFatherOfId: isFOf,
          isMotherOfId: isMOf,
          spouseId: spId,
          initialGender: initGender,
        ),
      ),
    );

    // Nếu thêm thành công -> Reload lại cây
    if (result == true && mounted) {
      _loadTree(); 
    }
  }

  void _onNodeTap(TreeNode node) async {
    // Logic cũ của bạn: Lấy từ Bloc để có full info
    final state = context.read<MemberBloc>().state;
    if (state is MemberLoaded) {
      try {
        final fullMember = state.members.firstWhere(
          (m) => m.id == node.id, 
          orElse: () => throw Exception("Not found") // Xử lý nếu không tìm thấy
        );
        
        final result = await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => BlocProvider.value(
              value: context.read<MemberBloc>(),
              child: MemberDetailViewScreen(member: fullMember),
            ),
          ),
        );
        if (result == true && mounted) {
           _loadTree();
        }
      } catch (e) {
        // Fallback: Nếu không tìm thấy trong list Bloc (do chưa load), có thể gọi API chi tiết ở đây
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Dữ liệu chi tiết chưa tải xong, vui lòng thử lại.")));
      }
    }
  }

  // --- UI BUILD ---

  @override
  Widget build(BuildContext context) {
    return BlocListener<MemberBloc, MemberState>(
      listener: (context, state) {
        // Reload tree when member is deleted or updated
        if (state is MemberDeleteSuccess || state is MemberUpdateSuccess) {
          _loadTree();
        }
      },
      child: _buildTreeContent(context),
    );
  }

  Widget _buildTreeContent(BuildContext context) {
    // 1. Màn hình Loading
    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    // 2. Màn hình Lỗi
    if (_error != null) {
      return Scaffold(
        appBar: AppBar(title: const Text("Sơ đồ"), backgroundColor: Colors.blue),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, color: Colors.red, size: 48),
              const SizedBox(height: 16),
              Text(_error!, textAlign: TextAlign.center, style: const TextStyle(color: Colors.red)),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: _loadTree, 
                icon: const Icon(Icons.refresh), 
                label: const Text("Thử lại")
              ),
            ],
          ),
        ),
      );
    }

    // 3. Màn hình Chính
    return Scaffold(
      backgroundColor: Colors.grey[50],
      // Dùng Stack để xếp lớp các button lên trên sơ đồ
      body: Stack(
        children: [
          Column(
            children: [
              // A. Header Màu xanh Figma
              // Khoảnh trống bù cho Search Card
              const SizedBox(height: 80),
              
              // Khoảnh trống bù cho Search Card chồng lên
              // const SizedBox(height: 70),

              // B. Khu vực Sơ đồ (Graph)
              Expanded(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    return InteractiveViewer(
                      transformationController: _transformationController,
                      constrained: false, // Cho phép sơ đồ to vô hạn
                      boundaryMargin: const EdgeInsets.all(1000), // Margin hợp lý để không bị lạc
                      minScale: 0.01,
                      maxScale: 5.0,
                      child: graph.nodes.isNotEmpty 
                        ? Stack(
                            children: [
                              gv.GraphView(
                                key: _graphKey,
                                graph: graph,
                                algorithm: _algorithm,
                                paint: Paint()..color = Colors.transparent, // TẮT DRAW DEFAULT EDGE
                                builder: (gv.Node node) {
                                  final id = node.key!.value as int;
                                  
                                  // TRƯỜNG HỢP NÚT GIAO (Union Node) -> Trả về điểm vô hình
                                  if (id < 0) {
                                    return Container(width: 1, height: 1, color: Colors.transparent);
                                  }

                                  final data = _nodeData[id];
                                  if (data == null) {
                                    return Container(
                                      width: 100, height: 50,
                                      color: Colors.red[50],
                                      alignment: Alignment.center,
                                      child: Text("ID: $id?", style: const TextStyle(fontSize: 8)),
                                    );
                                  }

                                  // Check highlight
                                  final isHighlighted = _highlightedNodeIds.contains(id);

                                  // Find Spouse Data if any
                                  TreeNode? spouseData;
                                  if (data.spouses.isNotEmpty) {
                                      // Only pick the spouse that was hidden (merged into this node)
                                      for (var sId in data.spouses) {
                                          // Check if this spouse ID is NOT in the graph (meaning it was hidden)
                                          // How to check? We don't have hiddenNodes set here.
                                          // But we can check if graph.getNodeUsingId(sId) is null?
                                          // OR simpler: Just take the first valid spouse from _nodeData.
                                          if (_nodeData.containsKey(sId)) {
                                              spouseData = _nodeData[sId];
                                              break; // ONLY Support 1 spouse for now in UI
                                          }
                                      }
                                  }

                                  return TreeNodeWidget(
                                    member: data, 
                                    spouse: spouseData, // <--- Pass Spouse!
                                    isEditMode: _isEditMode,
                                    isHighlighted: isHighlighted,
                                    onAddClick: (target, alignment) => _onAddRelative(target, alignment),
                                    onTap: () => _onNodeTap(data),
                                    onTapSpouse: spouseData != null ? () => _onNodeTap(spouseData!) : null,
                                  );
                                },
                              ),
                              
                              // Layer vẽ edge custom (Con riêng vẽ lệch) - THÊM IgnorePointer
                              Positioned.fill(
                                child: IgnorePointer(
                                  child: CustomPaint(
                                    painter: TreeEdgePainter(graph, _edgeTypes, _coupleNodeIds),
                                  ),
                                ),
                              ),

                              // Layer vẽ đường highlight đè lên trên - THÊM IgnorePointer
                              if (_highlightedEdgeKeys.isNotEmpty)
                                Positioned.fill(
                                  child: IgnorePointer(
                                    child: CustomPaint(
                                      painter: PathHighlighter(graph, _highlightedEdgeKeys),
                                    ),
                                  ),
                                ),
                            ],
                          )
                        : const Center(child: Text("Sơ đồ chưa có dữ liệu")),
                    );
                  },
                ),
              ),
            ],
          ),
          
          // C. Các nút điều khiển nổi (Floating Buttons)
          
          // 2. Card Tìm kiếm (Nằm đè lên Header - Positioned trong Stack)
          Positioned(
            top: 10, // Đưa lên sát đầu trang
            left: 0,
            right: 0,
            child: _buildTopSearchArea(),
          ),

          // Nút Chế độ (Xem / Sửa) - Góc phải trên
          Positioned(
            right: 16,
            top: 220, // Đẩy xuống một chút
            child: Column(
              children: [
                _modeButton(
                  icon: Icons.visibility, 
                  isActive: !_isEditMode, 
                  onTap: () => setState(() => _isEditMode = false),
                ),
                const SizedBox(height: 12),
                _modeButton(
                  icon: Icons.edit_outlined, 
                  isActive: _isEditMode, 
                  onTap: () => setState(() => _isEditMode = true),
                ),
              ],
            ),
          ),

          // Nút Căn giữa - Góc phải dưới
          Positioned(
            right: 16,
            bottom: 32,
            child: FloatingActionButton(
              onPressed: () => _autoCenterView(),
              backgroundColor: Colors.white,
              elevation: 4,
              heroTag: "center_btn",
              child: const Icon(Icons.center_focus_strong, color: Colors.blue),
            ),
          ),
        ],
      ),
    );
  }

  // --- WIDGETS CON ---

  Widget _buildTopSearchArea() {
    final members = _nodeData.values.toList()..sort((a, b) => a.name.compareTo(b.name));
    
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16), // Margin ngang sạch sẽ
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          )
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.search, size: 24, color: Colors.blue),
              const SizedBox(width: 8),
              const Text(
                "Tìm kiếm mối quan hệ", 
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.black)
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(child: _buildDropDown(value: _selectedFromId, items: members, onChanged: (v) => setState(() => _selectedFromId = v))),
              const Padding(padding: EdgeInsets.symmetric(horizontal: 10), child: Text("Và", style: TextStyle(color: Colors.black54))),
              Expanded(child: _buildDropDown(value: _selectedToId, items: members, onChanged: (v) => setState(() => _selectedToId = v))),
            ],
          ),
          
          // Nút Tìm kiếm & Kết quả
          if (_selectedFromId != null && _selectedToId != null) ...[
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _findRelationship,
                style: ElevatedButton.styleFrom(backgroundColor: Colors.blue, foregroundColor: Colors.white),
                child: const Text("Tìm đường đi"),
              ),
            ),
          ],
          if (_relationshipResult.isNotEmpty)
            Container(
              margin: const EdgeInsets.only(top: 8),
              padding: const EdgeInsets.all(8),
              width: double.infinity,
              decoration: BoxDecoration(color: Colors.blue.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
              child: Text(_relationshipResult, style: const TextStyle(fontSize: 13, color: Colors.blueAccent, fontStyle: FontStyle.italic)),
            ),
        ],
      ),
    );
  }

  Widget _buildDropDown({required int? value, required List<TreeNode> items, required ValueChanged<int?> onChanged}) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return DropdownMenu<int>(
          width: constraints.maxWidth,
          initialSelection: value,
          requestFocusOnTap: true,
          enableFilter: true, // Cho phép nhập liệu để tìm
          hintText: "Chọn người",
          textStyle: const TextStyle(fontSize: 13),
          inputDecorationTheme: InputDecorationTheme(
            filled: true,
            fillColor: Colors.grey[200],
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
            contentPadding: const EdgeInsets.symmetric(horizontal: 12),
            isDense: true,
          ),
          dropdownMenuEntries: items.map((m) {
            // Lookup Father
            String fatherName = "Unknown";
            if (m.fatherId != null && _nodeData.containsKey(m.fatherId)) {
               fatherName = _nodeData[m.fatherId]!.name;
            }
            // DOB
            String dob = m.dob ?? m.birthYear;
            
            final label = "${m.name} (#${m.id}) - $dob - Bố: $fatherName";
            
            return DropdownMenuEntry<int>(
              value: m.id,
              label: label, 
              style: MenuItemButton.styleFrom(foregroundColor: Colors.black87),
            );
          }).toList(),
          onSelected: onChanged,
        );
      }
    );
  }


  Widget _modeButton({required IconData icon, required bool isActive, required VoidCallback onTap}) {
    return InkWell(
      onTap: onTap,
      child: Container(
        width: 45, height: 45,
        decoration: BoxDecoration(
          color: Colors.white,
          shape: BoxShape.circle,
          boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 4)],
          border: isActive ? Border.all(color: Colors.blue, width: 2) : null,
        ),
        child: Icon(icon, color: isActive ? Colors.blue : Colors.grey, size: 24),
      ),
    );
  }

  Future<void> _findRelationship() async {
    try {
      final dio = ApiClient().dio;
      final response = await dio.post('/members/path', data: {"from_id": _selectedFromId, "to_id": _selectedToId});
      
      final data = response.data;
      final pathIds = List<int>.from(data['path'] ?? []); // Lấy danh sách ID đường đi từ API
      final relText = data['relationship'] ?? "Không tìm thấy mối quan hệ trực tiếp.";

      // Xử lý Highlight
      final Set<String> newEdgeKeys = {};
      final Set<int> newNodeIds = {};

      if (pathIds.isNotEmpty) {
        // Build nodeToPrimary map (same logic as _loadTree)
        final Map<int, int> nodeToPrimary = {};
        final Set<int> hiddenNodes = {};
        
        for (var n in _nodeData.values) {
          if (n.spouses.isNotEmpty) {
            for (var spouseId in n.spouses) {
              if (_nodeData.containsKey(spouseId)) {
                final sNode = _nodeData[spouseId]!;
                bool iAmPrimary = true;
                
                if (n.gender == 'male' && sNode.gender != 'male') {
                  iAmPrimary = true;
                } else if (n.gender != 'male' && sNode.gender == 'male') {
                  iAmPrimary = false;
                } else {
                  if (n.id > spouseId) iAmPrimary = false;
                }
                
                if (iAmPrimary) {
                  hiddenNodes.add(spouseId);
                  nodeToPrimary[n.id] = n.id;
                  nodeToPrimary[spouseId] = n.id;
                } else {
                  hiddenNodes.add(n.id);
                  nodeToPrimary[n.id] = spouseId;
                  nodeToPrimary[spouseId] = spouseId;
                }
                break; // Only process first spouse
              }
            }
          }
          if (!nodeToPrimary.containsKey(n.id)) {
            nodeToPrimary[n.id] = n.id;
          }
        }

        // Map path IDs to visual (primary) nodes
        final visualPathIds = pathIds.map((id) => nodeToPrimary[id] ?? id).toList();
        newNodeIds.addAll(visualPathIds);

        for (int i = 0; i < visualPathIds.length - 1; i++) {
          final u = visualPathIds[i];
          final v = visualPathIds[i+1];
          
          // 1. Kiểm tra cạnh trực tiếp u -> v
          bool found = false;
          
          gv.Node? nodeU = graph.getNodeUsingId(u);
          gv.Node? nodeV = graph.getNodeUsingId(v);
          
          if (nodeU != null && nodeV != null) {
             // Thử tìm cạnh trực tiếp
             if (graph.getEdgeBetween(nodeU, nodeV) != null) {
                newEdgeKeys.add("$u-$v");
                found = true;
             }
             
             // Nếu không thấy, tìm qua Union Node
             // u -> Union -> v (u là cha/mẹ, v là con)
             if (!found) {
                for (var edge in graph.edges) {
                   if (edge.source == nodeU) {
                      final intermediate = edge.destination;
                      final int interId = intermediate.key!.value as int;
                      if (interId < 0) { // Là Union node
                         if (graph.getEdgeBetween(intermediate, nodeV) != null) {
                            newEdgeKeys.add("$u-$interId");
                            newEdgeKeys.add("$interId-$v");
                            found = true;
                            break;
                         }
                      }
                   }
                }
             }

             // Trường hợp v là cha/mẹ, u là con (Đi ngược?)
             if (!found) {
                 // Check path v -> Union -> u
                 for (var edge in graph.edges) {
                   if (edge.source == nodeV) {
                       final intermediate = edge.destination;
                       final int interId = intermediate.key!.value as int;
                       if (interId < 0) {
                          if (graph.getEdgeBetween(intermediate, nodeU) != null) {
                              newEdgeKeys.add("$v-$interId");
                              newEdgeKeys.add("$interId-$u");
                              found = true;
                              break;
                          }
                       }
                   }
                 }
                 
                 // Check trực tiếp v -> u
                 if (!found && graph.getEdgeBetween(nodeV, nodeU) != null) {
                    newEdgeKeys.add("$v-$u");
                    found = true;
                 }
             }
          }
        }
      }

      if (mounted) {
        setState(() {
          _relationshipResult = relText;
          _highlightedEdgeKeys.clear();
          _highlightedEdgeKeys.addAll(newEdgeKeys);
          _highlightedNodeIds.clear();
          _highlightedNodeIds.addAll(newNodeIds);
        });
      }
    } catch (e) {
      debugPrint("Error finding path: $e");
      if (mounted) setState(() => _relationshipResult = "Lỗi khi tìm kiếm hoặc không có kết nối.");
    }
  }
}

// --- PAINTER & HELPERS ---

class PathHighlighter extends CustomPainter {
  final gv.Graph graph;
  final Set<String> highlightedKeys;

  PathHighlighter(this.graph, this.highlightedKeys);

  @override
  void paint(Canvas canvas, Size size) {
    if (highlightedKeys.isEmpty) return;

    final paint = Paint()
      ..color = Colors.green
      ..strokeWidth = 3.0 // Dày hơn bình thường
      ..style = PaintingStyle.stroke;

    for (var edge in graph.edges) {
      final sourceId = edge.source.key!.value as int;
      final destId = edge.destination.key!.value as int;
      
      // Check cả 2 chiều key cho chắc ăn
      final key1 = "$sourceId-$destId";
      final key2 = "$destId-$sourceId";
      
      if (highlightedKeys.contains(key1) || highlightedKeys.contains(key2)) {
         // Vẽ đè lên cạnh này
         final p1 = Offset(edge.source.x + edge.source.width / 2, edge.source.y + edge.source.height / 2);
         final p2 = Offset(edge.destination.x + edge.destination.width / 2, edge.destination.y + edge.destination.height / 2);
         
         canvas.drawLine(p1, p2, paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant PathHighlighter oldDelegate) {
     return oldDelegate.highlightedKeys != highlightedKeys;
  }
}

