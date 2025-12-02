import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:network_info_plus/network_info_plus.dart';
import 'package:flutter/services.dart';

class MeshNetworkService {
  static final MeshNetworkService _instance = MeshNetworkService._internal();
  factory MeshNetworkService() => _instance;
  MeshNetworkService._internal();

  static const int DISCOVERY_PORT = 9876;
  static const int TRANSFER_PORT = 9877;
  static const String SERVICE_NAME = 'WaveShare';
  static const platform = MethodChannel('com.example.waveshare/multicast');

  bool _isDiscovering = false;
  bool _isAdvertising = false;

  ServerSocket? _discoveryServer;
  ServerSocket? _transferServer;
  Timer? _advertisementTimer;
  Timer? _discoveryTimer;
  RawDatagramSocket? _discoverySocket;
  List<NearbyDevice> _nearbyDevices = [];
  Map<String, FileTransfer> _activeTransfers = {};

  String? _myOrgId;
  String? _myUserId;
  String? _myUserType;
  String? _myName;
  String? _myIP;

  Function(List<NearbyDevice>)? onDevicesFound;
  Function(String fileId, double progress)? onTransferProgress;
  Function(String fileId)? onTransferComplete;
  Function(String error)? onError;

  Future<void> initialize(String orgId, String userId, String userType, {String? name}) async {
    _myOrgId = orgId;
    _myUserId = userId;
    _myUserType = userType;
    _myName = name ?? userId;

    print('🔵 Mesh Network Initialized');
    print('   User: $_myUserId ($_myUserType)');
    print('   Organization: $_myOrgId');
  }

  Future<void> startScanning() async {
    if (_isDiscovering) return;

    try {
      try {
        await platform.invokeMethod('acquireMulticastLock');
        print('🔓 Multicast lock acquired');
      } catch (e) {
        print('⚠️ Could not acquire multicast lock: $e');
      }

      await _requestPermissions();
      _isDiscovering = true;
      print('📡 Starting device discovery...');

      await _startDiscoveryListener();
      _startPeriodicScan();

      print('✅ Discovery started successfully');
    } catch (e) {
      print('❌ Discovery failed: $e');
      _isDiscovering = false;
      onError?.call('Discovery failed: $e');
    }
  }

  Future<void> startAdvertising() async {
    if (_isAdvertising) return;

    try {
      _isAdvertising = true;
      print('📢 Starting advertisement...');

      final info = NetworkInfo();
      String? wifiIP;

      try {
        wifiIP = await info.getWifiIP();
      } catch (e) {
        print('Error getting WiFi IP: $e');
      }

      if (wifiIP == null || wifiIP.isEmpty) {
        throw Exception('Not connected to WiFi - Please connect to WiFi network');
      }

      _myIP = wifiIP;
      print('   My IP: $wifiIP');

      await _startTransferServer();
      _startPeriodicAdvertisement(wifiIP);

      print('✅ Advertisement started successfully');
    } catch (e) {
      print('❌ Advertisement failed: $e');
      _isAdvertising = false;
      onError?.call('Advertisement failed: $e');
    }
  }

  Future<void> stopScanning() async {
    _isDiscovering = false;
    _discoveryTimer?.cancel();
    _discoverySocket?.close();
    await _discoveryServer?.close();

    try {
      await platform.invokeMethod('releaseMulticastLock');
      print('🔒 Multicast lock released');
    } catch (e) {
      print('⚠️ Could not release multicast lock: $e');
    }

    print('🛑 Discovery stopped');
  }

  Future<void> stopAdvertising() async {
    _isAdvertising = false;
    _advertisementTimer?.cancel();
    await _transferServer?.close();
    print('🛑 Advertisement stopped');
  }

  Future<void> shareFile({
    required String filePath,
    required String fileName,
    required List<String> targetUserIds,
    required Function(double) onProgress,
  }) async {
    try {
      print('📤 Sharing file: $fileName');
      print('   Path: $filePath');
      print('   Targets: ${targetUserIds.length}');

      File file = File(filePath);
      if (!await file.exists()) {
        throw Exception('File not found: $filePath');
      }

      Uint8List fileBytes = await file.readAsBytes();
      String fileId = DateTime.now().millisecondsSinceEpoch.toString();

      print('   File size: ${fileBytes.length} bytes');

      Map<String, dynamic> metadata = {
        'fileId': fileId,
        'fileName': fileName,
        'fileSize': fileBytes.length,
        'senderId': _myUserId,
        'senderName': _myName,
        'senderType': _myUserType,
        'orgId': _myOrgId,
        'targetUsers': targetUserIds,
        'timestamp': DateTime.now().toIso8601String(),
      };

      await _saveSharedFile(fileId, fileBytes, metadata);
      print('💾 File saved locally');

      List<NearbyDevice> targetDevices = _nearbyDevices.where((device) {
        return targetUserIds.contains('ALL') || targetUserIds.contains(device.userId);
      }).toList();

      print('📱 Found ${targetDevices.length} target devices nearby');

      if (targetDevices.isEmpty) {
        print('⚠️ No target devices nearby');
        onProgress(1.0);
        return;
      }

      int completed = 0;
      for (var device in targetDevices) {
        try {
          await _sendFileToDevice(device, fileId, fileBytes, metadata);
          completed++;
          onProgress(completed / targetDevices.length);
          print('✅ Sent to ${device.name} ($completed/${targetDevices.length})');
        } catch (e) {
          print('❌ Failed to send to ${device.name}: $e');
        }
      }

      print('✅ File sharing complete!');
      print('   Reached: $completed/${targetDevices.length} devices');

    } catch (e) {
      print('❌ Share error: $e');
      onError?.call('Share failed: $e');
      rethrow;
    }
  }

  Future<void> _sendFileToDevice(
      NearbyDevice device,
      String fileId,
      Uint8List fileBytes,
      Map<String, dynamic> metadata,
      ) async {
    try {
      print('📲 Connecting to ${device.name} at ${device.ipAddress}:$TRANSFER_PORT');

      Socket socket = await Socket.connect(
        device.ipAddress,
        TRANSFER_PORT,
        timeout: Duration(seconds: 10),
      );

      print('✅ Connected to ${device.name}');

      String metaJson = jsonEncode(metadata);
      socket.write('META:$metaJson\n');
      await socket.flush();
      await Future.delayed(Duration(milliseconds: 100));

      int chunkSize = 8192;
      int totalChunks = (fileBytes.length / chunkSize).ceil();

      for (int i = 0; i < fileBytes.length; i += chunkSize) {
        int end = (i + chunkSize < fileBytes.length) ? i + chunkSize : fileBytes.length;
        socket.add(fileBytes.sublist(i, end));
        await socket.flush();

        int currentChunk = (i / chunkSize).ceil();
        if (currentChunk % 100 == 0) {
          print('   Progress: $currentChunk/$totalChunks chunks');
        }
      }

      socket.write('END:$fileId\n');
      await socket.flush();
      await Future.delayed(Duration(milliseconds: 100));

      await socket.close();
      print('✅ Transfer complete to ${device.name}');

    } catch (e) {
      print('❌ Transfer failed: $e');
      rethrow;
    }
  }

  Future<void> _startDiscoveryListener() async {
    try {
      final socket = await RawDatagramSocket.bind(
        InternetAddress.anyIPv4,
        DISCOVERY_PORT,
        reuseAddress: true,
        reusePort: true,
      );

      print('👂 UDP listener started on port $DISCOVERY_PORT');

      socket.broadcastEnabled = true;
      socket.readEventsEnabled = true;

      socket.listen((event) {
        if (event == RawSocketEvent.read) {
          Datagram? dg = socket.receive();
          if (dg != null) {
            try {
              String message = utf8.decode(dg.data);
              print('📨 Received: $message from ${dg.address.address}');

              if (message.startsWith('WAVESHARE:')) {
                _handleDiscoveryMessage(message, dg.address.address);
              }
            } catch (e) {
              print('Error decoding message: $e');
            }
          }
        }
      });

      _discoverySocket = socket;

    } catch (e) {
      print('❌ Failed to start discovery listener: $e');
      rethrow;
    }
  }

  void _handleDiscoveryMessage(String message, String ipAddress) {
    try {
      print('🔍 Processing: $message from $ipAddress');

      List<String> parts = message.split(':');
      if (parts.length < 5) {
        print('⚠️ Invalid message format');
        return;
      }

      String orgId = parts[1];
      String userId = parts[2];
      String userType = parts[3];
      String userName = parts.sublist(4).join(':');

      print('   OrgId: $orgId (Mine: $_myOrgId)');
      print('   UserId: $userId (Mine: $_myUserId)');
      print('   IP: $ipAddress (Mine: $_myIP)');

      if (orgId != _myOrgId) {
        print('   ❌ Different organization');
        return;
      }

      if (ipAddress == _myIP) {
        print('   ❌ This is me (same IP: $ipAddress)');
        return;
      }

      int existingIndex = _nearbyDevices.indexWhere((d) => d.ipAddress == ipAddress);

      NearbyDevice device = NearbyDevice(
        userId: userId,
        name: userName,
        userType: userType,
        orgId: orgId,
        ipAddress: ipAddress,
        lastSeen: DateTime.now(),
      );

      if (existingIndex >= 0) {
        _nearbyDevices[existingIndex] = device;
        print('   🔄 Updated device: $userName');
      } else {
        _nearbyDevices.add(device);
        print('   ✅ NEW DEVICE ADDED: $userName ($userType) at $ipAddress');
      }

      onDevicesFound?.call(_nearbyDevices);
      print('   📱 TOTAL DEVICES: ${_nearbyDevices.length}');

    } catch (e) {
      print('❌ Error parsing discovery message: $e');
    }
  }

  void _startPeriodicAdvertisement(String myIP) {
    _advertisementTimer = Timer.periodic(Duration(seconds: 2), (timer) async {
      try {
        String message = 'WAVESHARE:$_myOrgId:$_myUserId:$_myUserType:$_myName';
        String subnet = myIP.substring(0, myIP.lastIndexOf('.'));
        String broadcastAddress = '$subnet.255';

        RawDatagramSocket.bind(InternetAddress.anyIPv4, 0).then((socket) {
          socket.broadcastEnabled = true;
          List<int> data = utf8.encode(message);
          socket.send(data, InternetAddress(broadcastAddress), DISCOVERY_PORT);
          print('📢 Broadcast sent to $broadcastAddress');
          socket.close();
        });

      } catch (e) {
        print('Advertisement error: $e');
      }
    });
  }

  void _startPeriodicScan() {
    _discoveryTimer = Timer.periodic(Duration(seconds: 5), (timer) {
      DateTime cutoff = DateTime.now().subtract(Duration(seconds: 10));
      _nearbyDevices.removeWhere((device) => device.lastSeen.isBefore(cutoff));
      onDevicesFound?.call(_nearbyDevices);
    });
  }

  Future<void> _startTransferServer() async {
    try {
      _transferServer = await ServerSocket.bind(
        InternetAddress.anyIPv4,
        TRANSFER_PORT,
      );

      print('📥 Transfer server listening on port $TRANSFER_PORT');

      _transferServer!.listen((Socket client) {
        _handleIncomingTransfer(client);
      });
    } catch (e) {
      print('❌ Failed to start transfer server: $e');
      rethrow;
    }
  }

  // ✅ FIXED: Proper file receiving and saving
  void _handleIncomingTransfer(Socket client) async {
    try {
      print('📥 Incoming connection from ${client.remoteAddress.address}');

      List<int> buffer = [];
      Map<String, dynamic>? metadata;
      bool receivingFile = false;
      String? currentFileId;
      bool metadataReceived = false;

      client.listen(
            (data) async {
          String chunk = utf8.decode(data, allowMalformed: true);

          // Check for metadata
          if (chunk.contains('META:') && !metadataReceived) {
            int metaStart = chunk.indexOf('META:') + 5;
            int metaEnd = chunk.indexOf('\n', metaStart);

            if (metaEnd > metaStart) {
              String metaJson = chunk.substring(metaStart, metaEnd);
              metadata = jsonDecode(metaJson);
              currentFileId = metadata!['fileId'];
              receivingFile = true;
              metadataReceived = true;

              print('📄 Receiving: ${metadata!['fileName']} (${metadata!['fileSize']} bytes)');

              // Remove metadata from chunk and add rest to buffer
              String remaining = chunk.substring(metaEnd + 1);
              if (remaining.isNotEmpty) {
                buffer.addAll(remaining.codeUnits);
              }
              return;
            }
          }

          // Check for end signal
          if (chunk.contains('END:')) {
            if (metadata != null && receivingFile && metadataReceived) {
              // Save received file
              await _saveReceivedFile(
                  currentFileId!,
                  Uint8List.fromList(buffer),
                  metadata!
              );
              print('✅ File received completely: ${metadata!['fileName']}');
              print('   Size: ${buffer.length} bytes');

              // Notify completion
              onTransferComplete?.call(currentFileId!);
            }
            receivingFile = false;
            metadataReceived = false;
            buffer.clear();
            client.close();
            return;
          }

          // Add data to buffer if receiving
          if (receivingFile && metadataReceived) {
            buffer.addAll(data);

            // Progress update
            if (metadata != null) {
              double progress = buffer.length / metadata!['fileSize'];
              onTransferProgress?.call(currentFileId!, progress);

              if (buffer.length % 100000 == 0) { // Log every 100KB
                print('   Received: ${buffer.length} / ${metadata!['fileSize']} bytes');
              }
            }
          }
        },
        onDone: () {
          print('📭 Transfer connection closed');
          client.close();
        },
        onError: (error) {
          print('❌ Transfer error: $error');
          client.close();
        },
      );

    } catch (e) {
      print('❌ Error handling transfer: $e');
      client.close();
    }
  }

  // ✅ FIXED: Proper file saving
  Future<void> _saveReceivedFile(
      String fileId,
      Uint8List fileBytes,
      Map<String, dynamic> metadata,
      ) async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      final filesDir = Directory('${dir.path}/received_files');

      if (!await filesDir.exists()) {
        await filesDir.create(recursive: true);
      }

      // Save file with original name
      String fileName = metadata['fileName'];
      String sanitizedFileName = fileName.replaceAll(RegExp(r'[^\w\s\-\.]'), '_');
      File file = File('${filesDir.path}/$fileId\_$sanitizedFileName');
      await file.writeAsBytes(fileBytes);

      // Save metadata
      metadata['localPath'] = file.path;
      metadata['receivedAt'] = DateTime.now().toIso8601String();
      metadata['status'] = 'received';

      SharedPreferences prefs = await SharedPreferences.getInstance();
      await prefs.setString('file_meta_$fileId', jsonEncode(metadata));

      // Add to received files list
      List<String> receivedFiles = prefs.getStringList('received_files') ?? [];
      if (!receivedFiles.contains(fileId)) {
        receivedFiles.add(fileId);
        await prefs.setStringList('received_files', receivedFiles);
      }

      print('💾 Received file saved:');
      print('   Name: $fileName');
      print('   Path: ${file.path}');
      print('   Size: ${fileBytes.length} bytes');

    } catch (e) {
      print('❌ Error saving received file: $e');
      rethrow;
    }
  }

  Future<void> _saveSharedFile(
      String fileId,
      Uint8List fileBytes,
      Map<String, dynamic> metadata,
      ) async {
    final dir = await getApplicationDocumentsDirectory();
    final filesDir = Directory('${dir.path}/shared_files');
    if (!await filesDir.exists()) {
      await filesDir.create(recursive: true);
    }

    File file = File('${filesDir.path}/$fileId');
    await file.writeAsBytes(fileBytes);

    metadata['localPath'] = file.path;
    metadata['sharedAt'] = DateTime.now().toIso8601String();
    metadata['status'] = 'shared';

    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setString('file_meta_$fileId', jsonEncode(metadata));

    // Add to shared files list
    List<String> sharedFiles = prefs.getStringList('shared_files') ?? [];
    if (!sharedFiles.contains(fileId)) {
      sharedFiles.add(fileId);
      await prefs.setStringList('shared_files', sharedFiles);
    }
  }

  // ✅ NEW: Get received files
  Future<List<Map<String, dynamic>>> getReceivedFiles() async {
    List<Map<String, dynamic>> files = [];
    SharedPreferences prefs = await SharedPreferences.getInstance();

    List<String> receivedFiles = prefs.getStringList('received_files') ?? [];

    for (String fileId in receivedFiles) {
      String? metaJson = prefs.getString('file_meta_$fileId');
      if (metaJson != null) {
        try {
          Map<String, dynamic> meta = jsonDecode(metaJson);

          // Verify file still exists
          if (meta['localPath'] != null) {
            File file = File(meta['localPath']);
            if (await file.exists()) {
              files.add(meta);
            }
          }
        } catch (e) {
          print('Error parsing metadata for $fileId: $e');
        }
      }
    }

    // Sort by received time (newest first)
    files.sort((a, b) {
      DateTime timeA = DateTime.parse(a['receivedAt'] ?? a['timestamp']);
      DateTime timeB = DateTime.parse(b['receivedAt'] ?? b['timestamp']);
      return timeB.compareTo(timeA);
    });

    return files;
  }

  Future<List<Map<String, dynamic>>> getSharedFiles() async {
    List<Map<String, dynamic>> files = [];
    SharedPreferences prefs = await SharedPreferences.getInstance();

    List<String> sharedFiles = prefs.getStringList('shared_files') ?? [];

    for (String fileId in sharedFiles) {
      String? metaJson = prefs.getString('file_meta_$fileId');
      if (metaJson != null) {
        try {
          Map<String, dynamic> meta = jsonDecode(metaJson);
          files.add(meta);
        } catch (e) {
          print('Error parsing metadata: $e');
        }
      }
    }

    return files;
  }

  Future<void> _requestPermissions() async {
    await Permission.locationWhenInUse.request();
    await Permission.nearbyWifiDevices.request();
  }

  void dispose() {
    stopScanning();
    stopAdvertising();
    _nearbyDevices.clear();
    _activeTransfers.clear();
  }
}

class NearbyDevice {
  final String userId;
  final String name;
  final String userType;
  final String orgId;
  final String ipAddress;
  final DateTime lastSeen;

  NearbyDevice({
    required this.userId,
    required this.name,
    required this.userType,
    required this.orgId,
    required this.ipAddress,
    required this.lastSeen,
  });
}

class FileTransfer {
  final String fileId;
  final String fileName;
  final int fileSize;
  int bytesTransferred = 0;

  FileTransfer({
    required this.fileId,
    required this.fileName,
    required this.fileSize,
  });

  double get progress => bytesTransferred / fileSize;
}