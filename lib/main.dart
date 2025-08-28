// ==================== 导入依赖包 ====================
import 'dart:convert'; // JSON编码解码功能
import 'package:flutter/material.dart'; // Flutter UI框架
import 'package:flutter/services.dart'; // 系统服务（如剪贴板）
import 'package:mongo_dart/mongo_dart.dart' hide Center, State; // MongoDB数据库操作
import 'services/database_service.dart'; // 自定义数据库服务

/// 应用程序入口点
/// 启动Flutter应用并运行MyApp组件
void main() {
  runApp(const MyApp());
}

// ==================== 主应用组件 ====================

/// 应用程序的根组件
/// 配置应用的主题、标题和主页面
class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      // 应用标题，显示在任务栏等位置
      title: '萌芽农场可视化游戏配置',

      // 移除右上角的Debug标识
      debugShowCheckedModeBanner: false,

      // 应用主题配置
      theme: ThemeData(
        // 使用绿色作为主色调，符合农场主题
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.green),
        // 启用Material 3设计规范
        useMaterial3: true,
      ),

      // 设置应用的主页面
      home: const GameConfigPage(),
    );
  }
}

// ==================== JSON文本输入组件 ====================

/// 支持JSON语法高亮的文本输入框组件
/// 提供多行文本编辑功能，适用于JSON数据的编辑和显示
class JsonHighlightTextField extends StatefulWidget {
  /// 文本控制器，用于获取和设置文本内容
  final TextEditingController controller;

  /// 输入框的提示文本
  final String hintText;

  /// 最大显示行数
  final int maxLines;

  /// 最小显示行数
  final int minLines;

  /// 文本变化时的回调函数
  final Function(String)? onChanged;

  const JsonHighlightTextField({
    super.key,
    required this.controller,
    required this.hintText,
    required this.maxLines,
    required this.minLines,
    this.onChanged,
  });

  @override
  State<JsonHighlightTextField> createState() => _JsonHighlightTextFieldState();
}

/// JsonHighlightTextField的状态管理类
/// 负责构建和管理JSON文本输入框的UI
class _JsonHighlightTextFieldState extends State<JsonHighlightTextField> {
  @override
  Widget build(BuildContext context) {
    return Container(
      // 外层容器装饰，提供边框和背景
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade400),
        borderRadius: BorderRadius.circular(4),
        color: Colors.white,
      ),
      child: TextField(
        controller: widget.controller,
        decoration: InputDecoration(
          // 移除默认边框，使用外层Container的边框
          border: InputBorder.none,
          // 设置内边距
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 12,
          ),
          // 提示文本
          hintText: widget.hintText,
          // 提示文本样式，使用等宽字体
          hintStyle: TextStyle(
            fontSize: 14,
            fontFamily: 'monospace',
            color: Colors.grey.shade500,
          ),
        ),
        // 文本样式配置
        style: const TextStyle(
          fontSize: 14,
          fontFamily: 'monospace', // 等宽字体，适合代码显示
          color: Colors.black87,
          height: 1.4, // 行高，提高可读性
        ),
        // 光标样式
        cursorColor: Colors.blue,
        cursorWidth: 1.5,
        // 行数限制
        maxLines: widget.maxLines,
        minLines: widget.minLines,
        // 文本变化回调
        onChanged: (value) {
          if (widget.onChanged != null) {
            widget.onChanged!(value);
          }
        },
      ),
    );
  }
}

// ==================== 主页面组件 ====================

/// 游戏配置管理主页面
/// 提供数据库连接、集合切换、数据查看和编辑功能
class GameConfigPage extends StatefulWidget {
  const GameConfigPage({super.key});

  @override
  State<GameConfigPage> createState() => _GameConfigPageState();
}

/// GameConfigPage的状态管理类
/// 负责管理数据库连接、数据加载、UI状态等
class _GameConfigPageState extends State<GameConfigPage> {
  // ==================== 核心服务实例 ====================
  /// 数据库服务实例，用于所有数据库操作
  final DatabaseService _databaseService = DatabaseService();

  // ==================== 状态变量 ====================
  /// 当前加载的游戏配置数据列表
  List<Map<String, dynamic>> _gameConfigs = [];

  /// 是否正在加载数据的标志
  bool _isLoading = false;

  /// 数据库连接状态标志
  bool _isConnected = false;

  /// 状态消息，显示给用户的连接或操作状态
  String _statusMessage = '未连接到数据库';

  /// 当前选择的数据库集合名称
  String _selectedCollection = 'gameconfig';

  /// 可用的数据库集合列表
  final List<String> _availableCollections = [
    'gameconfig',
    'playerdata',
    'chat',
  ];

  // ==================== 生命周期方法 ====================

  /// 组件初始化时调用
  /// 自动尝试连接数据库
  @override
  void initState() {
    super.initState();
    _connectToDatabase();
  }

  /// 组件销毁时调用
  /// 确保数据库连接被正确关闭，避免资源泄漏
  @override
  void dispose() {
    _databaseService.disconnect();
    super.dispose();
  }

  // ==================== 数据库操作方法 ====================

  /// 连接到数据库
  /// 使用保存的连接配置尝试建立数据库连接
  /// 连接成功后自动加载当前集合的数据
  Future<void> _connectToDatabase() async {
    // 设置加载状态
    setState(() {
      _isLoading = true;
      _statusMessage = '正在连接数据库...';
    });

    try {
      // 尝试连接数据库
      await _databaseService.connect();

      // 连接成功，更新状态
      setState(() {
        _isConnected = true;
        _statusMessage = '数据库连接成功';
      });

      // 加载当前集合的数据
      await _loadGameConfigs();
    } catch (e) {
      // 连接失败，更新错误状态
      setState(() {
        _isConnected = false;
        _statusMessage = '数据库连接失败: $e';
      });
    } finally {
      // 无论成功失败，都要清除加载状态
      setState(() {
        _isLoading = false;
      });
    }
  }

  /// 加载当前集合的数据
  /// 从数据库服务获取当前集合的所有文档数据
  /// 更新UI状态和数据列表
  Future<void> _loadGameConfigs() async {
    // 设置加载状态
    setState(() {
      _isLoading = true;
      _statusMessage = '正在加载数据...';
    });

    try {
      // 从数据库获取配置数据
      final configs = await _databaseService.getGameConfigs();

      // 更新数据和状态
      setState(() {
        _gameConfigs = configs;
        _statusMessage = '成功加载 ${configs.length} 个数据项';
      });
    } catch (e) {
      // 加载失败，显示错误信息
      setState(() {
        _statusMessage = '加载数据失败: $e';
      });
    } finally {
      // 清除加载状态
      setState(() {
        _isLoading = false;
      });
    }
  }

  /// 切换到指定的数据库集合
  /// 更新当前选择的集合并重新加载数据
  ///
  /// [collectionName] 要切换到的集合名称
  Future<void> _switchCollection(String collectionName) async {
    // 更新选择的集合并设置加载状态
    setState(() {
      _selectedCollection = collectionName;
      _isLoading = true;
      _statusMessage = '正在切换到 $collectionName 集合...';
    });

    try {
      // 在数据库服务中切换集合
      _databaseService.switchCollection(collectionName);

      // 重新加载新集合的数据
      await _loadGameConfigs();
    } catch (e) {
      // 切换失败，显示错误信息
      setState(() {
        _statusMessage = '切换集合失败: $e';
      });
    }
  }

  // ==================== UI交互方法 ====================

  /// 显示数据库设置对话框
  /// 允许用户修改数据库连接参数
  /// 设置更改后会自动重新连接数据库
  void _showSettingsDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return SettingsDialog(
          onSettingsChanged: () {
            // 设置更改后重新连接数据库
            _connectToDatabase();
          },
        );
      },
    );
  }

  /// 编辑指定的配置项
  /// 打开配置编辑页面，允许用户修改配置数据
  ///
  /// [config] 要编辑的配置数据
  void _editConfig(Map<String, dynamic> config) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => ConfigEditPage(
          config: config,
          // 配置保存回调函数
          onSave: (updatedConfig) async {
            // 提取文档ID，处理不同的ID格式
            String docId;
            if (config['_id'] is ObjectId) {
              // 如果是ObjectId对象，转换为十六进制字符串
              docId = (config['_id'] as ObjectId).toHexString();
            } else {
              // 如果是字符串格式，清理多余的字符
              docId = config['_id']
                  .toString()
                  .replaceAll('ObjectId("', '')
                  .replaceAll('")', '');
            }

            // 调用数据库服务更新配置
            final success = await _databaseService.updateGameConfig(
              docId,
              updatedConfig,
            );

            if (success) {
              // 更新成功，重新加载数据并显示成功消息
              _loadGameConfigs();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('配置更新成功'),
                  backgroundColor: Colors.green,
                ),
              );
            } else {
              // 更新失败，显示错误消息
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('配置更新失败'),
                  backgroundColor: Colors.red,
                ),
              );
            }
          },
        ),
      ),
    );
  }

  // ==================== UI构建方法 ====================

  /// 构建主页面UI
  /// 包含应用栏、集合选择器、连接状态显示和数据列表
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // ==================== 应用栏配置 ====================
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: const Text('萌芽农场可视化游戏配置'),
        actions: [
          // 集合选择下拉框容器
          Container(
            margin: const EdgeInsets.only(right: 16),
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.grey.shade300),
            ),
            child: DropdownButton<String>(
              value: _selectedCollection,
              underline: Container(), // 移除默认下划线
              items: _availableCollections.map((String collection) {
                return DropdownMenuItem<String>(
                  value: collection,
                  child: Text(collection, style: const TextStyle(fontSize: 14)),
                );
              }).toList(),
              // 集合切换回调，只有连接时才可用
              onChanged: _isConnected
                  ? (String? newValue) {
                      if (newValue != null && newValue != _selectedCollection) {
                        _switchCollection(newValue);
                      }
                    }
                  : null,
            ),
          ),
          // 设置按钮
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: _showSettingsDialog,
            tooltip: '设置',
          ),
          // 刷新/重连按钮
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _isConnected ? _loadGameConfigs : _connectToDatabase,
            tooltip: _isConnected ? '刷新数据' : '重新连接',
          ),
        ],
      ),

      // ==================== 主体内容区域 ====================
      body: Column(
        children: [
          // 连接状态显示栏
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            // 根据连接状态设置背景色
            color: _isConnected ? Colors.green.shade100 : Colors.red.shade100,
            child: Row(
              children: [
                // 状态图标
                Icon(
                  _isConnected ? Icons.check_circle : Icons.error,
                  color: _isConnected ? Colors.green : Colors.red,
                ),
                const SizedBox(width: 8),
                // 状态消息文本
                Expanded(
                  child: Text(
                    _statusMessage,
                    style: TextStyle(
                      color: _isConnected
                          ? Colors.green.shade800
                          : Colors.red.shade800,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                // 加载指示器
                if (_isLoading)
                  const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
              ],
            ),
          ),

          // ==================== 数据列表区域 ====================
          Expanded(
            child: _gameConfigs.isEmpty
                // 空数据状态显示
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.storage,
                          size: 64,
                          color: Colors.grey.shade400,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          _isConnected ? '暂无数据' : '请先连接数据库',
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                  )
                // 数据列表显示
                : Scrollbar(
                    
                    // 滚动条配置
                    thumbVisibility: true,
                    trackVisibility: true,
                    thickness: 8,
                    radius: const Radius.circular(4),
                    child: ListView.builder(
                      padding: const EdgeInsets.only(
                        left: 16,
                        top: 16,
                        bottom: 16,
                        right: 24,
                      ),
                      itemCount: _gameConfigs.length,
                      itemBuilder: (context, index) {
                        final config = _gameConfigs[index];

                        // ==================== 动态标题生成逻辑 ====================
                        // 根据不同集合类型显示不同的标题和副标题
                        String title;
                        String subtitle;

                        if (_selectedCollection == 'playerdata') {
                          // 玩家数据集合：显示玩家昵称、等级和钱币
                          title =
                              config['农场名称']?.toString() ??
                              config['farmname']?.toString() ??
                              '未知玩家';
                          String level =
                              config['等级']?.toString() ??
                              config['level']?.toString() ??
                              '0';
                          String money =
                              config['钱币']?.toString() ??
                              config['money']?.toString() ??
                              '0';
                          String exp =
                              config['经验']?.toString() ??
                              config['exp']?.toString() ??
                              '0';
                          String nickname =
                              config['玩家昵称']?.toString() ??
                              config['nickname']?.toString() ??
                              '0';
                          subtitle =
                              '等级: $level | 钱币: $money | 经验: $exp | 玩家昵称: $nickname';
                        } else if (_selectedCollection == 'chat') {
                          // 聊天记录集合：显示消息内容和发送者
                          title =
                              config['message']?.toString() ??
                              config['content']?.toString() ??
                              '聊天消息';
                          subtitle =
                              '发送者: ${config['sender']?.toString() ?? config['from']?.toString() ?? '未知'}';
                        } else {
                          // 游戏配置集合：显示配置类型和ID
                          title = config['config_type']?.toString() ?? '未知配置类型';
                          subtitle =
                              'ID: ${config['_id']?.toString() ?? '未知ID'}';
                        }

                          

                        // ==================== 数据卡片UI ====================
                        return Card(
                          // 卡片样式配置
                          margin: const EdgeInsets.only(bottom: 8),
                          elevation: 2,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: ExpansionTile(
                            // 展开面板配置
                            tilePadding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 4,
                            ),
                            childrenPadding: EdgeInsets.zero,
                            expandedCrossAxisAlignment:
                                CrossAxisAlignment.start,
                            expandedAlignment: Alignment.centerLeft,

                            // 主标题
                            title: Text(
                              title,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                            ),

                            // 副标题
                            subtitle: Text(
                              subtitle,
                              style: TextStyle(color: Colors.grey.shade600),
                            ),

                            // 右侧操作按钮区域
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                // 编辑按钮
                                IconButton(
                                  icon: const Icon(
                                    Icons.edit,
                                    color: Colors.blue,
                                  ),
                                  onPressed: () => _editConfig(config),
                                  tooltip: '编辑配置',
                                ),
                                // 展开指示器
                                const Icon(Icons.expand_more),
                              ],
                            ),
                            // ==================== 展开内容区域 ====================
                            children: [
                              Padding(
                                padding: const EdgeInsets.all(16),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  // 遍历配置项的所有键值对，生成详细信息列表
                                  children: config.entries
                                      .map(
                                        (entry) => Padding(
                                          padding: const EdgeInsets.only(
                                            bottom: 8,
                                          ),
                                          child: Row(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              // 字段名称（固定宽度）
                                              SizedBox(
                                                width: 120,
                                                child: Text(
                                                  '${entry.key}:',
                                                  style: const TextStyle(
                                                    fontWeight: FontWeight.w500,
                                                  ),
                                                ),
                                              ),
                                              // 字段值（自适应宽度）
                                              Expanded(
                                                child: Text(
                                                  entry.value?.toString() ??
                                                      'null',
                                                  style: TextStyle(
                                                    color: Colors.grey.shade700,
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      )
                                      .toList(),
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

// ==================== JSON编辑器页面 ====================

/// JSON编辑器页面组件
/// 提供JSON格式的配置编辑功能，支持语法高亮和格式验证
class JsonEditorPage extends StatefulWidget {
  /// 页面标题
  final String title;

  /// 初始JSON内容
  final String initialContent;

  /// 保存回调函数
  final Function(String) onSave;

  const JsonEditorPage({
    super.key,
    required this.title,
    required this.initialContent,
    required this.onSave,
  });

  @override
  State<JsonEditorPage> createState() => _JsonEditorPageState();
}

/// JSON编辑器页面状态管理类
class _JsonEditorPageState extends State<JsonEditorPage> {
  // ==================== 状态变量 ====================
  /// 文本编辑控制器
  late TextEditingController _controller;

  /// JSON格式是否有效
  bool _isValidJson = true;

  /// 错误信息
  String _errorMessage = '';

  // ==================== 生命周期方法 ====================

  /// 初始化状态
  @override
  void initState() {
    super.initState();
    // 使用初始内容初始化文本控制器
    _controller = TextEditingController(text: widget.initialContent);
    // 验证初始JSON内容
    _validateJson(widget.initialContent);
  }

  /// 释放资源
  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  // ==================== 业务逻辑方法 ====================

  /// 验证JSON格式
  /// [content] 要验证的JSON字符串
  void _validateJson(String content) {
    try {
      if (content.trim().isNotEmpty) {
        jsonDecode(content);
      }
      setState(() {
        _isValidJson = true;
        _errorMessage = '';
      });
    } catch (e) {
      setState(() {
        _isValidJson = false;
        _errorMessage = e.toString();
      });
    }
  }

  /// 格式化JSON内容
  /// 将当前编辑器中的JSON内容进行格式化（美化）
  void _formatJson() {
    try {
      final decoded = jsonDecode(_controller.text);
      final formatted = const JsonEncoder.withIndent('  ').convert(decoded);
      _controller.text = formatted;
      _validateJson(formatted);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('JSON格式错误: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  /// 保存内容
  /// 验证JSON格式后调用保存回调并关闭页面
  void _saveContent() {
    if (_isValidJson) {
      // JSON格式正确，执行保存回调并关闭页面
      widget.onSave(_controller.text);
      Navigator.of(context).pop();
    } else {
      // JSON格式错误，显示错误提示
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('请修正JSON格式错误后再保存'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // ==================== UI构建方法 ====================

  /// 构建页面UI
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      // ==================== 应用栏 ====================
      appBar: AppBar(
        title: Text('编辑 ${widget.title}'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        elevation: 1,
        actions: [
          // 格式化按钮
          IconButton(
            onPressed: _formatJson,
            icon: const Icon(Icons.auto_fix_high),
            tooltip: '格式化JSON',
          ),
          // 取消按钮
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('取消'),
          ),
          // 保存按钮（根据JSON有效性动态启用/禁用）
          ElevatedButton(
            onPressed: _isValidJson ? _saveContent : null,
            style: ElevatedButton.styleFrom(
              backgroundColor: _isValidJson ? Colors.green : Colors.grey,
              foregroundColor: Colors.white,
            ),
            child: const Text('保存'),
          ),
          const SizedBox(width: 16),
        ],
      ),

      // ==================== 页面主体内容 ====================
      body: Column(
        children: [
          // JSON格式错误提示区域
          if (!_isValidJson)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              color: Colors.red.shade100,
              child: Row(
                children: [
                  Icon(Icons.error, color: Colors.red.shade700),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'JSON格式错误: $_errorMessage',
                      style: TextStyle(color: Colors.red.shade700),
                    ),
                  ),
                ],
              ),
            ),

          // ==================== JSON编辑器区域 ====================
          Expanded(
            child: Container(
              // 编辑器容器样式
              margin: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey.shade300),
                borderRadius: BorderRadius.circular(8),
                color: Colors.white,
              ),
              child: TextField(
                controller: _controller,
                // 输入框样式配置
                decoration: const InputDecoration(
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.all(16),
                  hintText: '请输入JSON内容...',
                ),
                // 文本样式配置（等宽字体，适合代码编辑）
                style: const TextStyle(
                  fontSize: 14,
                  fontFamily: 'monospace',
                  height: 1.5,
                  color: Colors.black87,
                ),
                // 光标样式
                cursorColor: Colors.blue,
                cursorWidth: 2.0,
                // 多行文本配置
                maxLines: null,
                expands: true,
                textAlignVertical: TextAlignVertical.top,
                // 文本变化回调：实时验证JSON格式
                onChanged: (value) {
                  setState(() {});
                  _validateJson(value);
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ==================== 配置编辑页面 ====================

/// 配置编辑页面组件
/// 提供表单式的配置编辑功能，支持各种数据类型的编辑
class ConfigEditPage extends StatefulWidget {
  /// 要编辑的配置数据
  final Map<String, dynamic> config;

  /// 保存回调函数
  final Function(Map<String, dynamic>) onSave;

  const ConfigEditPage({super.key, required this.config, required this.onSave});

  @override
  State<ConfigEditPage> createState() => _ConfigEditPageState();
}

/// 配置编辑页面状态管理类
class _ConfigEditPageState extends State<ConfigEditPage> {
  // ==================== 状态变量 ====================
  /// 编辑中的配置数据副本
  late Map<String, dynamic> _editedConfig;

  /// 各字段的文本控制器映射
  final Map<String, TextEditingController> _controllers = {};

  // ==================== 生命周期方法 ====================

  /// 初始化状态
  @override
  void initState() {
    super.initState();
    // 创建配置数据的副本
    _editedConfig = Map<String, dynamic>.from(widget.config);

    // 为每个字段（除了_id）创建文本控制器
    widget.config.forEach((key, value) {
      if (key != '_id') {
        String displayText = _formatValue(value);
        _controllers[key] = TextEditingController(text: displayText);
      }
    });
  }

  // ==================== 辅助方法 ====================

  /// 格式化值为显示文本
  /// [value] 要格式化的值
  /// 返回格式化后的字符串
  String _formatValue(dynamic value) {
    if (value == null) return '';

    // 对于复杂对象（Map或List），转换为格式化的JSON字符串
    if (value is Map || value is List) {
      try {
        return const JsonEncoder.withIndent('  ').convert(value);
      } catch (e) {
        return value.toString();
      }
    } else {
      // 简单类型直接转换为字符串
      return value.toString();
    }
  }

  /// 检查值是否为JSON类型（Map或List）
  /// [value] 要检查的值
  /// 返回是否为JSON类型
  bool _isJsonValue(dynamic value) {
    return value is Map || value is List;
  }

  /// 复制JSON内容到剪贴板
  /// [key] 字段名称
  void _copyJsonContent(String key) {
    final content = _controllers[key]?.text ?? '';
    Clipboard.setData(ClipboardData(text: content));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('已复制 "$key" 的JSON内容到剪贴板'),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  /// 在JSON编辑器中编辑内容
  /// [key] 字段名称
  /// [originalValue] 原始值
  void _editJsonContent(String key, dynamic originalValue) {
    Navigator.of(context).push(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (context) => JsonEditorPage(
          title: key,
          initialContent: _controllers[key]?.text ?? '',
          onSave: (newContent) {
            setState(() {
              _controllers[key]?.text = newContent;
            });
          },
        ),
      ),
    );
  }

  /// 导出整个文档到剪贴板
  /// 将当前编辑的所有字段组合成完整文档并复制到剪贴板
  void _exportDocumentToClipboard() {
    try {
      // 创建完整的文档副本，包含所有当前编辑的值
      final exportDoc = <String, dynamic>{};

      // 添加ID - 确保使用一致的格式
      if (widget.config['_id'] is ObjectId) {
        exportDoc['_id'] = (widget.config['_id'] as ObjectId).toHexString();
      } else {
        exportDoc['_id'] = widget.config['_id'];
      }

      // 添加其他字段的当前值
      _controllers.forEach((key, controller) {
        final originalValue = widget.config[key];
        final currentText = controller.text.trim();

        // 对于JSON类型字段，尝试解析为对象
        if (originalValue is Map || originalValue is List) {
          try {
            exportDoc[key] = jsonDecode(currentText);
          } catch (e) {
            exportDoc[key] = currentText;
          }
        } else if (originalValue is num) {
          // 对于数字类型字段，尝试解析为数字
          final numValue = num.tryParse(currentText);
          exportDoc[key] = numValue ?? currentText;
        } else {
          // 其他类型直接使用文本值
          exportDoc[key] = currentText;
        }
      });

      // 转换为格式化的JSON字符串并复制到剪贴板
      final jsonString = const JsonEncoder.withIndent('  ').convert(exportDoc);
      Clipboard.setData(ClipboardData(text: jsonString));

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('文档已导出到剪贴板'),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 2),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('导出失败: $e'),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  /// 从剪贴板导入文档
  /// 读取剪贴板中的JSON数据并更新当前编辑的字段
  void _importDocumentFromClipboard() async {
    try {
      // 获取剪贴板内容
      final clipboardData = await Clipboard.getData('text/plain');
      if (clipboardData?.text == null || clipboardData!.text!.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('剪贴板为空'),
            backgroundColor: Colors.orange,
            duration: Duration(seconds: 2),
          ),
        );
        return;
      }

      // 验证JSON格式
      Map<String, dynamic> importedDoc;
      try {
        importedDoc = jsonDecode(clipboardData.text!) as Map<String, dynamic>;
      } catch (jsonError) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('剪贴板内容不是有效的JSON格式: $jsonError'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
        return;
      }

      // 检查文档ID是否匹配，确保导入的是同一个文档
      String importedId;
      String currentId;

      // 处理导入文档的ID（支持多种ID格式）
      if (importedDoc['_id'] is Map) {
        importedId =
            importedDoc['_id']['\$oid'] ?? importedDoc['_id'].toString();
      } else {
        importedId = importedDoc['_id']?.toString() ?? '';
      }

      // 处理当前文档的ID（支持ObjectId和Map格式）
      if (widget.config['_id'] is ObjectId) {
        currentId = (widget.config['_id'] as ObjectId).toHexString();
      } else if (widget.config['_id'] is Map) {
        currentId =
            widget.config['_id']['\$oid'] ?? widget.config['_id'].toString();
      } else {
        currentId = widget.config['_id']?.toString() ?? '';
      }

      // 清理ID字符串，移除可能的ObjectId包装格式
      importedId = importedId
          .replaceAll('ObjectId("', '')
          .replaceAll('")', '')
          .replaceAll('ObjectId(', '')
          .replaceAll(')', '');
      currentId = currentId
          .replaceAll('ObjectId("', '')
          .replaceAll('")', '')
          .replaceAll('ObjectId(', '')
          .replaceAll(')', '');

      // 验证文档ID是否匹配，防止导入错误的文档
      if (importedId != currentId) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('文档ID不匹配，无法导入\n导入ID: $importedId\n当前ID: $currentId'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
          ),
        );
        return;
      }

      // 更新控制器的值（跳过_id字段）
      importedDoc.forEach((key, value) {
        if (key != '_id' && _controllers.containsKey(key)) {
          final formattedValue = _formatValue(value);
          _controllers[key]?.text = formattedValue;
        }
      });

      // 刷新UI显示
      setState(() {});

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('文档已从剪贴板导入'),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 2),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('导入失败: $e'),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  /// 删除子对象
  /// 显示确认对话框并删除指定的配置字段
  void _deleteSubObject(String key) {
    // 显示删除确认对话框
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('确认删除'),
          content: Text('确定要删除子对象 "$key" 吗？此操作不可撤销。'),
          actions: [
            // 取消按钮
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('取消'),
            ),
            // 确认删除按钮
            ElevatedButton(
              onPressed: () {
                setState(() {
                  // 从编辑配置中移除字段
                  _editedConfig.remove(key);
                  // 释放并移除对应的文本控制器
                  _controllers[key]?.dispose();
                  _controllers.remove(key);
                });
                Navigator.of(context).pop();
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('已删除子对象 "$key"'),
                    backgroundColor: Colors.green,
                    duration: const Duration(seconds: 2),
                  ),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
              ),
              child: const Text('删除'),
            ),
          ],
        );
      },
    );
  }

  /// 释放资源
  /// 清理所有文本控制器以防止内存泄漏
  @override
  void dispose() {
    _controllers.values.forEach((controller) => controller.dispose());
    super.dispose();
  }

  /// 根据文本内容长度计算最大显示行数
  /// 用于动态调整TextField的显示高度
  int _getMaxLines(dynamic value) {
    final text = value?.toString() ?? '';
    if (text.length < 50) return 2;
    if (text.length < 200) return 4;
    if (text.length < 500) return 6;
    if (text.length < 1000) return 10;
    return 15;
  }

  /// 根据文本内容长度计算最小显示行数
  /// 确保TextField有合适的初始高度
  int _getMinLines(dynamic value) {
    final text = value?.toString() ?? '';
    if (text.length < 50) return 1;
    if (text.length < 200) return 2;
    if (text.length < 500) return 3;
    return 4;
  }

  /// 保存配置更改
  /// 验证并保存用户编辑的配置数据
  void _saveChanges() {
    final updatedConfig = <String, dynamic>{};
    String? validationError;

    // 遍历所有控制器，检查并处理更改的字段
    _controllers.forEach((key, controller) {
      final newValue = controller.text.trim();
      final originalValue = widget.config[key];

      // 检查字段值是否有变化
      String originalText;
      if (originalValue is Map || originalValue is List) {
        try {
          // 将复杂对象转换为格式化的JSON字符串进行比较
          originalText = const JsonEncoder.withIndent(
            '  ',
          ).convert(originalValue);
        } catch (e) {
          originalText = originalValue?.toString() ?? '';
        }
      } else {
        originalText = originalValue?.toString() ?? '';
      }

      // 只处理有变化的字段
      if (newValue != originalText) {
        // 根据原始值类型进行相应的数据转换和验证
        if (originalValue is Map || originalValue is List) {
          // JSON类型字段：尝试解析为对象
          try {
            final parsedValue = jsonDecode(newValue);
            updatedConfig[key] = parsedValue;
          } catch (e) {
            validationError = '字段 "$key" 的JSON格式不正确: ${e.toString()}';
            return;
          }
        } else if (originalValue is num) {
          // 数字类型字段：验证并转换为数字
          final numValue = num.tryParse(newValue);
          if (numValue != null) {
            updatedConfig[key] = numValue;
          } else {
            validationError = '字段 "$key" 应该是数字格式';
            return;
          }
        } else {
          // 其他类型：直接使用字符串值
          updatedConfig[key] = newValue;
        }
      }
    });

    // 如果有验证错误，显示错误信息并停止保存
    if (validationError != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(validationError!),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 3),
        ),
      );
      return;
    }

    // 如果有更改，调用保存回调
    if (updatedConfig.isNotEmpty) {
      widget.onSave(updatedConfig);
    }
    // 关闭编辑页面
    Navigator.of(context).pop();
  }

  /// 构建配置编辑页面UI
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // 应用栏：显示标题和操作按钮
      appBar: AppBar(
        title: Text(
          '编辑配置: ${widget.config['config_type'] ?? '未知类型'}',
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        actions: [
          // 取消按钮
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('取消', style: TextStyle(color: Colors.white)),
          ),
          // 保存按钮
          ElevatedButton(
            onPressed: _saveChanges,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
            ),
            child: const Text('保存'),
          ),
          const SizedBox(width: 8),
        ],
      ),
      // 主体：配置字段列表
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: ListView.builder(
          itemCount: widget.config.entries.length + 1, // +1 for add button
          cacheExtent: 1000, // 缓存更多项目以提高滑动性能
          itemBuilder: (context, index) {
            // 如果是最后一个索引，显示导出和导入按钮
            if (index == widget.config.entries.length) {
              return Padding(
                padding: const EdgeInsets.only(top: 20, bottom: 20),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    // 导出按钮
                    ElevatedButton.icon(
                      onPressed: _exportDocumentToClipboard,
                      icon: const Icon(Icons.file_upload),
                      label: const Text('导出到剪贴板'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 12,
                        ),
                      ),
                    ),
                    // 导入按钮
                    ElevatedButton.icon(
                      onPressed: _importDocumentFromClipboard,
                      icon: const Icon(Icons.file_download),
                      label: const Text('从剪贴板导入'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 12,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }

            // 获取当前配置项
            final entry = widget.config.entries.elementAt(index);

            // 特殊处理ID字段（只读显示）
            if (entry.key == '_id') {
              return Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'ID (只读)',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.grey.shade600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    // ID显示容器
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(color: Colors.grey.shade300),
                      ),
                      child: Text(
                        entry.value?.toString() ?? '',
                        style: TextStyle(color: Colors.grey.shade600),
                      ),
                    ),
                  ],
                ),
              );
            }

            // 普通配置字段的UI构建
            return Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 字段名称标签
                  Text(
                    entry.key,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 4),
                  // 根据字段类型显示不同的编辑界面
                  _isJsonValue(entry.value)
                      ? Column(
                          children: [
                            // JSON字段的操作按钮行
                            Row(
                              children: [
                                // 复制JSON内容按钮
                                IconButton(
                                  onPressed: () => _copyJsonContent(entry.key),
                                  icon: const Icon(Icons.copy, size: 18),
                                  tooltip: '复制JSON内容',
                                  style: IconButton.styleFrom(
                                    backgroundColor: Colors.blue.withValues(
                                      alpha: 0.1,
                                    ),
                                    foregroundColor: Colors.blue,
                                    padding: const EdgeInsets.all(8),
                                  ),
                                ),
                                // 编辑JSON内容按钮
                                IconButton(
                                  onPressed: () =>
                                      _editJsonContent(entry.key, entry.value),
                                  icon: const Icon(Icons.edit, size: 18),
                                  tooltip: '编辑JSON内容',
                                  style: IconButton.styleFrom(
                                    backgroundColor: Colors.green.withValues(
                                      alpha: 0.1,
                                    ),
                                    foregroundColor: Colors.green,
                                    padding: const EdgeInsets.all(8),
                                  ),
                                ),
                                // 删除子对象按钮
                                IconButton(
                                  onPressed: () => _deleteSubObject(entry.key),
                                  icon: const Icon(Icons.delete, size: 18),
                                  tooltip: '删除子对象',
                                  style: IconButton.styleFrom(
                                    backgroundColor: Colors.red.withValues(
                                      alpha: 0.1,
                                    ),
                                    foregroundColor: Colors.red,
                                    padding: const EdgeInsets.all(8),
                                  ),
                                ),
                                const Spacer(),
                              ],
                            ),
                            // JSON字段的多行文本编辑区域
                            Container(
                              decoration: BoxDecoration(
                                border: Border.all(color: Colors.grey.shade400),
                                borderRadius: BorderRadius.circular(4),
                                color: Colors.white,
                              ),
                              child: TextField(
                                controller: _controllers[entry.key]!,
                                decoration: InputDecoration(
                                  border: InputBorder.none,
                                  hintText: '请输入${entry.key}',
                                  contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 12,
                                  ),
                                ),
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontFamily: 'monospace', // 使用等宽字体便于阅读JSON
                                  height: 1.4,
                                ),
                                maxLines: _getMaxLines(entry.value),
                                minLines: _getMinLines(entry.value),
                                onChanged: (value) {
                                  setState(() {}); // 实时更新UI状态
                                },
                              ),
                            ),
                          ],
                        )
                      // 普通字段的单行文本编辑器
                      : TextField(
                          controller: _controllers[entry.key],
                          decoration: InputDecoration(
                            border: const OutlineInputBorder(),
                            hintText: '请输入${entry.key}',
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 12,
                            ),
                          ),
                          style: const TextStyle(fontSize: 14),
                          maxLines: _getMaxLines(entry.value), // 动态调整最大行数
                          minLines: _getMinLines(entry.value), // 动态调整最小行数
                        ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

/// 设置对话框
/// 用于配置数据库连接参数
class SettingsDialog extends StatefulWidget {
  final VoidCallback onSettingsChanged; // 设置更改后的回调函数

  const SettingsDialog({super.key, required this.onSettingsChanged});

  @override
  State<SettingsDialog> createState() => _SettingsDialogState();
}

class _SettingsDialogState extends State<SettingsDialog> {
  late TextEditingController _hostController;
  late TextEditingController _portController;
  late TextEditingController _databaseController;
  late TextEditingController _usernameController;
  late TextEditingController _passwordController;
  final DatabaseService _databaseService = DatabaseService();
  bool _isLoading = false;
  bool _showPassword = false;

  @override
  void initState() {
    super.initState();
    _hostController = TextEditingController();
    _portController = TextEditingController();
    _databaseController = TextEditingController();
    _usernameController = TextEditingController();
    _passwordController = TextEditingController();
    _loadCurrentConnection();
  }

  @override
  void dispose() {
    _hostController.dispose();
    _portController.dispose();
    _databaseController.dispose();
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _loadCurrentConnection() async {
    final config = await _databaseService.getSavedDatabaseConfig();
    _hostController.text = config['host'] ?? '';
    _portController.text = config['port'] ?? '';
    _databaseController.text = config['database'] ?? '';
    _usernameController.text = config['username'] ?? '';
    _passwordController.text = config['password'] ?? '';
  }

  Future<void> _testConnection() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // 构建连接字符串进行测试
      String connectionString;
      final username = _usernameController.text.trim();
      final password = _passwordController.text.trim();
      final host = _hostController.text.trim();
      final port = _portController.text.trim();
      final database = _databaseController.text.trim();

      if (username.isNotEmpty && password.isNotEmpty) {
        // URL编码用户名和密码中的特殊字符
        final encodedUsername = Uri.encodeComponent(username);
        final encodedPassword = Uri.encodeComponent(password);
        connectionString =
            'mongodb://$encodedUsername:$encodedPassword@$host:$port/$database?authSource=admin';
      } else {
        connectionString = 'mongodb://$host:$port/$database';
      }

      final testService = DatabaseService();
      await testService.connect(connectionString);
      await testService.disconnect();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('数据库连接测试成功'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('数据库连接测试失败: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _saveSettings() async {
    await _databaseService.saveDatabaseConfig(
      host: _hostController.text.trim(),
      port: _portController.text.trim(),
      database: _databaseController.text.trim(),
      username: _usernameController.text.trim().isEmpty
          ? null
          : _usernameController.text.trim(),
      password: _passwordController.text.trim().isEmpty
          ? null
          : _passwordController.text.trim(),
    );
    widget.onSettingsChanged();
    if (mounted) {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('数据库设置'),
      content: SizedBox(
        width: 400,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '数据库连接配置:',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  flex: 3,
                  child: TextField(
                    controller: _hostController,
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                      labelText: '主机地址',
                      hintText: '192.168.31.233',
                      prefixIcon: Icon(Icons.computer),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  flex: 1,
                  child: TextField(
                    controller: _portController,
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                      labelText: '端口',
                      hintText: '27017',
                      prefixIcon: Icon(Icons.settings_ethernet),
                    ),
                    keyboardType: TextInputType.number,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _databaseController,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                labelText: '数据库名',
                hintText: 'farmvisual',
                prefixIcon: Icon(Icons.storage),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _usernameController,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                labelText: '用户名 (可选)',
                hintText: 'shumengya',
                prefixIcon: Icon(Icons.person),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _passwordController,
              obscureText: !_showPassword,
              decoration: InputDecoration(
                border: const OutlineInputBorder(),
                labelText: '密码 (可选)',
                hintText: '请输入密码',
                prefixIcon: const Icon(Icons.lock),
                suffixIcon: IconButton(
                  icon: Icon(
                    _showPassword ? Icons.visibility : Icons.visibility_off,
                  ),
                  onPressed: () {
                    setState(() {
                      _showPassword = !_showPassword;
                    });
                  },
                ),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                ElevatedButton.icon(
                  onPressed: _isLoading ? null : _testConnection,
                  icon: _isLoading
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.network_check),
                  label: const Text('测试连接'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    foregroundColor: Colors.white,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            const Divider(),
            const SizedBox(height: 10),
            const Text('应用信息:', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(Icons.flutter_dash, color: Colors.blue.shade600),
                const SizedBox(width: 8),
                const Text('由 Flutter 开发'),
              ],
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                Icon(Icons.person, color: Colors.green.shade600),
                const SizedBox(width: 8),
                const Text('作者: 树萌芽'),
              ],
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('取消'),
        ),
        ElevatedButton(
          onPressed: _saveSettings,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.green,
            foregroundColor: Colors.white,
          ),
          child: const Text('保存'),
        ),
      ],
    );
  }
}
