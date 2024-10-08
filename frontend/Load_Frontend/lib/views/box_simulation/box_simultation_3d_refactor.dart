import 'dart:math';

import 'package:auto_route/annotations.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:flutter_gl/flutter_gl.dart';
import 'package:load_frontend/constaints.dart';
import 'package:load_frontend/services/user_service.dart';
import 'package:load_frontend/stores/user_store.dart';
import 'package:load_frontend/stores/worker_store.dart';
import 'package:load_frontend/views/box_simulation/selected_box_overlay_widget.dart';
import 'package:load_frontend/views/box_simulation/simulation_controller.dart';
import 'package:load_frontend/views/box_simulation/video_overlay_widget.dart';
import 'package:provider/provider.dart';
import 'package:three_dart/three_dart.dart' as three;
import 'package:three_dart_jsm/three_dart_jsm.dart' as three_jsm;
import 'package:three_dart_jsm/three_dart_jsm/loaders/mtl_loader.dart';
import 'package:three_dart_jsm/three_dart_jsm/loaders/obj_loader.dart';

import '../../stores/box_store.dart';
import 'box.dart';
import 'box_colors.dart';
import 'package:load_frontend/stores/goods_store.dart';

import 'box_simulation_gobal_setting.dart';

@RoutePage()
class BoxSimulation3dSecondPage extends StatefulWidget {
  const BoxSimulation3dSecondPage({super.key});

  @override
  _BoxSimulation3dSecondPage createState() => _BoxSimulation3dSecondPage();
}

class _BoxSimulation3dSecondPage extends State<BoxSimulation3dSecondPage>
    with TickerProviderStateMixin, WidgetsBindingObserver {
  late FlutterGlPlugin three3dRender;
  three.WebGLRenderer? renderer;
  Ticker? _ticker;
  three.Raycaster raycaster = three.Raycaster();

  late SelectedBoxOverlayWidget
      selectedBoxOverlayWidget; // = SelectedBoxOverlayWidget();
  int? fboId;
  late double width;
  late double height;

  Size? screenSize;

  late three.Scene scene;
  late three.Camera camera;
  late three.Mesh mesh;

  double dpr = 1.0;

  var amount = 4;

  bool verbose = true;
  bool disposed = false;

  late three.WebGLRenderTarget renderTarget;

  dynamic sourceTexture;

  final GlobalKey<three_jsm.DomLikeListenableState> _globalKey =
      GlobalKey<three_jsm.DomLikeListenableState>();

  late three_jsm.OrbitControls controls;
  bool kIsWeb = const bool.fromEnvironment('dart.library.js_util');

  late three.Matrix4 matrix;

  // 각 구역 별 색상을 변경하고 최적화를 진행하기 위함
  List<three.MeshPhongMaterial> materials = [];
  List<three.InstancedMesh> meshes = [];

  three.Vector3 truckPosition = three.Vector3(40, -60, 78);

  bool isClickOrTaped = false;
  three.Vector2 clickedScrinPoint = three.Vector2(0, 0);
  late three.Object3D clickedObject;

  bool isSelected = false;
  late SimulBox selectedBox;

  OverlayEntry? _overlayEntry;

  three.MeshPhysicalMaterial selectedMaterial = three.MeshPhysicalMaterial({
    "color": 0xFFFFFFFF,
    "flatShading": true,
    "transparent": true,
    "opacity": 0.8,
    "depthTest": false,
    //'vertexColors': true,
  });
  three.BoxGeometry selectedGeometry = three.BoxGeometry(1, 1, 1);

  late three.Mesh selectedMesh;
  late three.Mesh selectedEdgeMesh;

  late three.MeshPhongMaterial edgeMaterial = three.MeshPhongMaterial({
    "color": 0x00000000,
    "flatShading": true,
    "transparent": true,
    "opacity": 1.0,
    "wireframe": true,
  });
  late three.InstancedMesh edgeMesh =
      three.InstancedMesh(geometry, edgeMaterial, 300);
  late three.MeshPhongMaterial transparentEdgeMaterial =
      three.MeshPhongMaterial({
    "color": 0x00000000,
    "flatShading": true,
    "transparent": true,
    "opacity": 0.3,
    "wireframe": true,
  });
  late three.InstancedMesh transparentEdgeMesh =
      three.InstancedMesh(geometry, transparentEdgeMaterial, 300);

  //이것 하나만 가지고 전체 mesh를 관리
  three.BoxGeometry geometry = three.BoxGeometry(1, 1, 1);

  three.BoxGeometry adjustBoxGeometryPivot(three.BoxGeometry geometry,
      double offsetX, double offsetY, double offsetZ) {
    var vertices = geometry.attributes['position'];

    if (vertices != null) {
      for (int i = 0; i < vertices.count; i++) {
        var x = vertices.getX(i);
        var y = vertices.getY(i);
        var z = vertices.getZ(i);
        vertices.setXYZ(i, x - offsetX, y - offsetY, z - offsetZ);
      }
    }
    geometry.attributes['position'].needsUpdate = true;

    return geometry;
  }

  void adjustMeshPivot(
      three.InstancedMesh mesh, double width, double height, double depth) {
    var pivotMatrix = three.Matrix4();
    pivotMatrix.makeTranslation(width / 2, height / 2, depth / 2);
    for (int? i = 0; i! < mesh.count!; i++) {
      var originalMatrix = three.Matrix4();
      mesh.getMatrixAt(i, originalMatrix);
      originalMatrix.multiply(pivotMatrix);
      mesh.setMatrixAt(i, originalMatrix);
    }
    mesh.instanceMatrix?.needsUpdate = true;
  }

  void adjustPivot(
      three.Object3D object, double offsetX, double offsetY, double offsetZ) {
    var tempObject = three.Object3D();
    while (object.children.isNotEmpty) {
      tempObject.add(object.children.first);
    }
    if (object.geometry != null) {
      object.geometry!.translate(-offsetX, -offsetY, -offsetZ);
    }
    while (tempObject.children.isNotEmpty) {
      object.add(tempObject.children.first);
    }
    object.position.set(offsetX, offsetY, offsetZ);
  }

  void onPointerDown(TapDownDetails event) {
    var size = MediaQuery.of(context).size;
    double x = (event.localPosition.dx /
                (size.width - gCurrSideBarWidth - gCurrRightSideBarWidth)) *
//        (size.width - sideBarDesktopWidth - rightsideBarDesktopWidth)) *
            2 -
        1;
//    double y = -(event.localPosition.dy / (size.height - topBarHeight)) * 2 + 1;
    double y =
        -(event.localPosition.dy / (size.height - gCurrTopBarHeight)) * 2 + 1;

    //double x = (event.localPosition.dx / width) * 2 - 1;
    //double y = -(event.localPosition.dy / height) * 2 + 1;

    isClickOrTaped = true;
    clickedScrinPoint = three.Vector2(x, y);
  }

  Map<String, double> calculateHeightExtremes() {
    if (boxes.isEmpty) return {'minHeight': 0.0, 'maxHeight': 0.0};

    double minHeight = boxes[0].currPosition.y;
    double maxHeight = minHeight;

    for (var box in boxes) {
      double boxHeight = box.currPosition.y;
      if (boxHeight + box.boxSize.y > maxHeight)
        maxHeight = boxHeight + box.boxSize.y;
      if (boxHeight < minHeight) minHeight = boxHeight;
    }
    return {'minHeight': minHeight, 'maxHeight': maxHeight};
  }

  void updateBoxVisibility() {
    var heightExtremes = calculateHeightExtremes();

    double totalMinHeight = heightExtremes['minHeight']!;
    double totalMaxHeight = heightExtremes['maxHeight']!;

    if (heightFloorValuesLowPercent < 0) heightFloorValuesLowPercent = 0;
    if (heightFloorValuesLowPercent > 100) heightFloorValuesLowPercent = 100;
    if (heightFloorValuesHighPercent < 0) heightFloorValuesHighPercent = 0;
    if (heightFloorValuesHighPercent > 100) heightFloorValuesHighPercent = 100;

    double minHeight = totalMinHeight +
        (totalMaxHeight - totalMinHeight) *
            (heightFloorValuesLowPercent / 100.0);
    double maxHeight = totalMinHeight +
        (totalMaxHeight - totalMinHeight) *
            (heightFloorValuesHighPercent / 100.0);

    for (var box in boxes) {
      double boxHeight = box.currPosition.y + box.boxSize.y;
      box.isVisible = (boxHeight >= minHeight && boxHeight <= maxHeight);
    }
  }

  makeInstanced(geometry, double opacity) {
    for (int i = 0; i < 21; i++) {
      if (i == 20) {
        opacity = 0.4;
      }
      materials.add(three.MeshPhongMaterial({
        "color": distinctColors[i].value,
        "flatShading": true,
        "transparent": true,
        "opacity": opacity,
      }));
    }
    edgeMaterial = three.MeshPhongMaterial({
      "color": 0xFFFFFFFF,
      "flatShading": true,
      "transparent": false,
      "opacity": 1.0,
      "wireframe": true,
    });
    transparentEdgeMaterial = three.MeshPhongMaterial({
      "color": 0xFFFFFFFF,
      "flatShading": true,
      "transparent": true,
      "opacity": 0.3,
      "wireframe": true,
    });
  }

  three.Vector3 truckSize =
      three.Vector3(280 * gScale, 160 * gScale, 160 * gScale);

  static const List<String> allowedMaterialNames = [
    'wire_087224198',
    'wire_028089177',
    'wire_143224087',
    'wire_224086086',
    'wire_229166215',
    'wire_224198087',
    'wire_177028149',
    'wire_134006006',
    'wire_134110008',
    'wire_006134006'
  ];

  // loadTruck() async {
  //   late three.Object3D object = three.Object3D();
  //   late MTLLoader mtlLoader;
  //   late MaterialCreator material;
  //   OBJLoader objLoader = OBJLoader(null);
  //
  //   mtlLoader = MTLLoader(three.LoadingManager());
  //   mtlLoader.setPath('assets/textures/');
  //   print("material1");
  //   material = await mtlLoader.loadAsync('truck.mtl');
  //   print("material2");
  //   await material.preload();
  //   print("material3");
  //   objLoader.setMaterials(material);
  //   object = await objLoader.loadAsync('assets/models3d/3d-model.obj');
  //   print("object");
  //
  //   truckSize.x = gtruckLength;
  //   truckSize.z = gtruckWidth; //gtruckLength;
  //   truckSize.y = gtruckHeight;
  //
  //   for (var child in object.children) {
  //     if (child is three.Mesh) {
  //       three.Mesh mesh = child as three.Mesh;
  //       if (mesh.material is three.Material &&
  //           (mesh.material as three.Material).name == 'wire_006134006') {
  //         mesh.visible = false;
  //       }
  //     }
  //   }
  //
  //   for (var child in object.children) {
  //     if (child is three.Mesh) {
  //       three.Mesh mesh = child as three.Mesh;
  //       if (mesh.material is three.Material) {
  //         three.Material material = mesh.material as three.Material;
  //         if (!allowedMaterialNames.contains(material.name)) {
  //           mesh.visible = false;
  //         }
  //       }
  //     }
  //   }
  //
  //   print("object loaded");
  //   object.rotation.y = three.Math.pi / 2;
  //   object.scale.set(0.05, 0.05, 0.05);
  //   object.position.set(40, -60, 78);
  //   scene.add(object);
  // }

  static three.Object3D object = three.Object3D();
  late OBJLoader objLoader;
  late MTLLoader mtlLoader;
  static late MaterialCreator material;

  static bool loaded = false;

  loadTruck() async {
    objLoader = OBJLoader(null);
    mtlLoader = MTLLoader(three.LoadingManager());
    mtlLoader.setPath('assets/textures/');
    print("Loading material...");
    if (loaded == false) {
      material = await mtlLoader.loadAsync('truck.mtl');
    }
    print("Material loaded");

    await material.preload();
    objLoader.setMaterials(material);

    print("Loading object...");
    if (loaded == false) {
      object = await objLoader.loadAsync('assets/models3d/3d-model.obj');
    }
    //object = await objLoader.loadAsync('assets/models3d/3d-model.obj');
    print("Object loaded");

    loaded = true;

    truckSize.x = gtruckLength;
    truckSize.z = gtruckWidth;
    truckSize.y = gtruckHeight;

    for (var child in object.children) {
      if (child is three.Mesh) {
        three.Mesh mesh = child as three.Mesh;
        if (mesh.material is three.Material &&
            (mesh.material as three.Material).name == 'wire_006134006') {
          mesh.visible = false;
        }
      }
    }

    for (var child in object.children) {
      if (child is three.Mesh) {
        three.Mesh mesh = child as three.Mesh;
        if (mesh.material is three.Material) {
          three.Material material = mesh.material as three.Material;
          if (!allowedMaterialNames.contains(material.name)) {
            mesh.visible = false;
          }
        }
      }
    }

    object.rotation.y = three.Math.pi / 2;
    object.scale.set(0.05, 0.05, 0.05);
    object.position.set(40, -60, 78);
    scene.add(object);
  }

  Future<void> initPlatformState() async {
    width = MediaQuery.of(context).size.width;
    height = MediaQuery.of(context).size.height;
    three3dRender = FlutterGlPlugin();

    Map<String, dynamic> options = {
      "antialias": true,
      "alpha": false,
      "width": width.toInt(),
      "height": height.toInt(),
      "dpr": dpr
    };

    await three3dRender.initialize(options: options);

    setState(() {});

    Future.delayed(const Duration(milliseconds: 100), () async {
      await three3dRender.prepareContext();

      initScene();
    });
  }

  initSize(BuildContext context) {
    if (screenSize != null) {
      return;
    }

    final mqd = MediaQuery.of(context);

    screenSize = mqd.size;
    dpr = mqd.devicePixelRatio;

    initPlatformState();
  }

  @override
  initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _showOverlay(context);
    });
  }

  late GlobalKey<VideoControlsOverlayState> overlayKey;

  void _showOverlay(BuildContext context) {
    overlayKey = GlobalKey<VideoControlsOverlayState>();

    if (_overlayEntry != null) {
      _overlayEntry!.remove();
    }
    _overlayEntry = OverlayEntry(
      builder: (context) => VideoControlsOverlay(
        onClose: _removeOverlay,
        overlayKey: overlayKey,
      ),
    );
    Overlay.of(context).insert(_overlayEntry!);
  }

  void _removeOverlay() {
    _overlayEntry?.remove();
    _overlayEntry = null;
    ;
  }

  @override
  void dispose() {
    print("dispose!!!!!!");
    disposed = true;
    scene.remove(object);
    object.dispose();
    scene.dispose();

    if (_ticker != null) {
      _ticker!.dispose(); // Ticker가 활성화된 경우 해제
    }
    if (isSelected) {
      print("remove ovelray");
      if (selectedBoxOverlayWidget.isShowing) {
        selectedBoxOverlayWidget.remove();
      }
    }
    _removeOverlay();

    three3dRender.dispose();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  FocusNode _focusNode = FocusNode();

  String positionText = "Position: x=0, y=0, z=0";
  double x = 0, y = 0, z = 0; // 트럭의 초기 위치

  void calculateCameraDirection(three.Camera camera) {
    three.Vector3 direction = three.Vector3(); // 방향을 저장할 Vector3 객체 생성
    camera.getWorldDirection(direction); // 카메라의 방향을 계산하여 'direction' 객체에 저장
    direction.normalize(); // 방향 벡터 정규화

    print("Camera direction: ${direction.x}, ${direction.y}, ${direction.z}");
  }

  @override
  Widget build(BuildContext context) {
    final Size _size = MediaQuery.of(context).size;
    final bool _isDesktop = _size.width >= screenLg;
    final bool _isMobile = _size.width < screenSm;

    WorkerStore workerStore = Provider.of<WorkerStore>(context, listen: false);
    truckSize.x = workerStore.gtruckLength.toDouble();
    truckSize.y = workerStore.gtruckHeight.toDouble();
    truckSize.z = workerStore.gtruckWidth.toDouble();
    print("truckSize: ${truckSize.x}, ${truckSize.y}, ${truckSize.z}");

    if (_isDesktop) {
      gCurrTopBarHeight = topBarHeight;
      gCurrSideBarWidth = sideBarDesktopWidth;
      gCurrRightSideBarWidth = rightSideBarDesktopWidth;
    } else if (_isMobile) {
      gCurrTopBarHeight = mobileTopBarHeight;
      gCurrSideBarWidth = 0;
      gCurrRightSideBarWidth = 0;
    } else {
      gCurrTopBarHeight = topBarHeight;
      gCurrSideBarWidth = sideBarMobileWidth;
      gCurrRightSideBarWidth = rightSideBarDesktopWidth;
    }
    return
        // Scaffold(
        // body: Focus(
        //   focusNode: _focusNode,
        //   autofocus: true,
        //   onKeyEvent: (node, event) {
        //     _handleKeyEvent(event);
        //     return KeyEventResult.handled;
        //   },
        //   child: Builder(
        //     builder: (BuildContext context) {
        //       initSize(context);
        //       return _build(context);
        //     },
        //   ),
        // ),
        Scaffold(
      body: Builder(
        builder: (BuildContext context) {
          initSize(context);
          return _build(context);
        },
      ),
      floatingActionButton:
          Column(mainAxisAlignment: MainAxisAlignment.end, children: [
        FloatingActionButton(
          heroTag: "State",
          key: Key("State"),
          child: const Text("재생바"),
          onPressed: () {
            showOverlayWidget();
          },
        ),
      ]),
      // floatingActionButton:
      //     Column(
      //         mainAxisAlignment: MainAxisAlignment.end,
      //         children: [
      //           FloatingActionButton(
      //             heroTag: "restart",
      //             key: Key("restart"),
      //             child: const Text("Restart"),
      //             onPressed: () {
      //               reStart();
      //             },
      //           ),
      //           FloatingActionButton(
      //             heroTag: "rewind",
      //             key: Key("rewind"),
      //             child: const Text("Rewind"),
      //             onPressed: () {
      //               rewind();
      //             },
      //           )
      //         ]
      //     ),
    );
  }

  bool isOverlayCreated = false;

  Widget _build(BuildContext context) {
    if (isOverlayCreated == false) {
      selectedBoxOverlayWidget = SelectedBoxOverlayWidget(
          context: context,
          position: Offset(gCurrSideBarWidth + 20, gCurrTopBarHeight + 20));

      isOverlayCreated = true;
    }
    return GestureDetector(
      onTapDown: onPointerDown,
      child: Stack(
        children: [
          three_jsm.DomLikeListenable(
              key: _globalKey,
              builder: (BuildContext context) {
                return Container(
                    width: MediaQuery.of(context).size.width,
                    height:
                        MediaQuery.of(context).size.height - gCurrTopBarHeight,
                    color: Colors.black,
                    child: Builder(builder: (BuildContext context) {
                      if (kIsWeb) {
                        return three3dRender.isInitialized
                            ? HtmlElementView(
                                viewType: three3dRender.textureId!.toString())
                            : Container();
                      } else {
                        return three3dRender.isInitialized
                            ? Texture(textureId: three3dRender.textureId!)
                            : Container();
                      }
                    }));
              }),
        ],
      ),
    );
  }

  bool isOverlayWidgetShowing = true;

  void showOverlayWidget() {
    if (isOverlayWidgetShowing) {
      _removeOverlay();
    } else {
      _showOverlay(context);
    }
    isOverlayWidgetShowing = !isOverlayWidgetShowing;
  }

  void reStart() {
    print("reStart ............. ");
    gCurrentBoxIndex = 0;
    gIsForword = true;
    for (int i = 0; i < boxes.length; i++) {
      boxes[i].isDone = false;
      boxes[i].init();
    }
  }

  void rewind() {
    print("rewind ............. ");
    gIsForword = false;
    for (int i = 0; i < boxes.length; i++) {
      boxes[i].determineIsFinished();
    }
  }

  render() {
    renderer!.render(scene, camera);
    if (!kIsWeb) {
      three3dRender.updateTexture(sourceTexture);
    }
  }

  initRenderer() {
    Map<String, dynamic> options = {
      "width": MediaQuery.of(context).size.width,
      "height": MediaQuery.of(context).size.height,
      "gl": three3dRender.gl,
      "antialias": true,
      "canvas": three3dRender.element,
      "alpha": true,
    };
    renderer = three.WebGLRenderer(options);
    renderer!.setPixelRatio(dpr);
    renderer!.setSize(MediaQuery.of(context).size.width,
        MediaQuery.of(context).size.height, false);
    //renderer!.shadowMap.enabled = false;

    if (!kIsWeb) {
      var pars = three.WebGLRenderTargetOptions({
        "minFilter": three.LinearFilter,
        "magFilter": three.LinearFilter,
        "format": three.RGBAFormat
      });
      renderTarget = three.WebGLRenderTarget(
          (MediaQuery.of(context).size.width * dpr).toInt(),
          (MediaQuery.of(context).size.height * dpr).toInt(),
          pars);
      renderTarget.samples = 4;
      renderer!.setRenderTarget(renderTarget);
      sourceTexture = renderer!.getRenderTargetGLTexture(renderTarget);
    }
  }

  initScene() {
    initRenderer();
    initPage();
  }

  initPage() async {
    scene = three.Scene();
    scene.background = three.Color(0xdddddd);
    //scene.fog = three.FogExp2(0xcccccc, 0.002);

    camera = three.PerspectiveCamera(60, width / height, 1, 20000000);

    camera.position.set(450, 200, 340);

    //
    // camera.lookAt(three.Vector3(11110, 11110, 11110));

    // controls

    controls = three_jsm.OrbitControls(camera, _globalKey);
    //controls.target.set(truckSize.x/2.0, 0, truckSize.z/2.0);// (0, 0, 0) 좌표를 바라보도록 설정
    //controls.offset.set(truckSize.x/2.0, 0, truckSize.z/2.0);
    controls.update();
    //controls.listenToKeyEvents( window );
    //controls.addEventListener( 'change', render ); // call this only in static scenes (i.e., if there is no animation loop)

    //window.addEventListener('resize', render());
    //window.addEventListener('resize', (event) {
    //  renderTarget.setSize((MediaQuery.of(context).size.width * dpr).toInt(), (MediaQuery.of(context).size.height * dpr).toInt());
    //});

    controls.enableDamping =
        true; // an animation loop is required when either damping or auto-rotation are enabled
    controls.dampingFactor = 0.05;

    controls.screenSpacePanning = false;

    controls.minDistance = 10;
    controls.maxDistance = 20000000;

    controls.maxPolarAngle = three.Math.pi / 2;

    // controls.addEventListener('change', (_) {
    //   renderer!.render(scene, camera);
    // });

    // var floorGeometry = three.PlaneGeometry(10000, 10000); // 크기는 필요에 맞게 조절
    // var floorMaterial = three.MeshPhongMaterial({
    //   "color": 0xffffffff, // 바닥 색상
    //   "side": three.DoubleSide,
    // });
    // var floorMesh = three.Mesh(floorGeometry, floorMaterial);
    // floorMesh.rotation.x = -three.Math.pi / 2; // X축을 따라 90도 회전하여 수평 배치
    // floorMesh.position.set(0, -6, 0); // 바닥 위치 조정, 필요에 따라 조절
    // scene.add(floorMesh);

    // world

    makeInstanced(geometry, 0.8);
    initBox();

    var dirLight1 = three.DirectionalLight(0xffffff);
    dirLight1.position.set(400, 400, 400);
    scene.add(dirLight1);

    var dirLight3 = three.DirectionalLight(0xffffff);
    dirLight3.position.set(-400, -400, -400);
    scene.add(dirLight1);

    var dirLight4 = three.DirectionalLight(0xffffff);
    dirLight4.position.set(-400, 400, 400);
    scene.add(dirLight1);

    var dirLight5 = three.DirectionalLight(0xffffff);
    dirLight5.position.set(400, -400, 400);
    scene.add(dirLight1);
    var dirLight6 = three.DirectionalLight(0xffffff);
    dirLight5.position.set(400, 400, -400);
    scene.add(dirLight1);

    var dirLight2 = three.DirectionalLight(0x000000);
    dirLight2.position.set(-400, -400, -400);
    scene.add(dirLight2);

    var ambientLight = three.AmbientLight(0x777777);
    scene.add(ambientLight);

    // 강력한 주광 조명
//     var dirLight1 = three.DirectionalLight(0xffffff, 1); // 강도 1로 설정
//     dirLight1.position.set(0, 10, 10);
//     dirLight1.castShadow = true;
//     scene.add(dirLight1);
//
// // 약간의 보조 광
//     var dirLight2 = three.DirectionalLight(0); // 강도 0.5로 밝기 감소
//     dirLight2.position.set(-5, -5, -5);
//     scene.add(dirLight2);

// 스포트라이트 추가, 특정 영역에 초점을 맞추고 그림자 생성
//     var spotLight = three.SpotLight(0xffffff, 0.8);
//     spotLight.position.set(65, 60, 65);
//     spotLight.angle = three.Math.pi / 6;
//     spotLight.penumbra = 0.2; // 빛의 경계 부드러움
//     spotLight.decay = 2;
//     spotLight.distance = 200;
//     spotLight.castShadow = true;
//     scene.add(spotLight);

// 환경 조명, 전체적인 밝기와 색감을 부드럽게 조정
//     var ambientLight = three.AmbientLight(0x404040); // 더 어두운 색상으로 변경
//     scene.add(ambientLight);

    loadTruck();

    _ticker = createTicker(_onTick)..start();
  }

  _onTick(Duration elapsed) {
    //controls.dispose();

    controls.target
        .set(truckSize.x / 2.0, 0, truckSize.z / 2.0); // (0, 0, 0) 좌표를 바라보도록 설정
    controls.update();
    animate();
  }

  animate() async {
    if (!mounted || disposed) {
      return;
    }
    onTickBox();
    render();
  }

  three.Vector3 randomVector3(double maxX, double maxY, double maxZ) {
    Random random = Random();

    // 각 축에 대해 0과 최대값 사이의 랜덤한 값 생성
    double x = random.nextDouble() * maxX;
    double y = random.nextDouble() * maxY;
    double z = random.nextDouble() * maxZ;

    return three.Vector3(x, y, z);
  }

  Map<int, int> mapNumbersToSequential(List<int> numbers) {
    Map<int, int> mapping = {};
    int counter = 0;

    for (int number in numbers) {
      if (!mapping.containsKey(number)) {
        // 중복된 숫자를 다시 매핑하지 않도록 확인
        mapping[number] = counter++;
      }
    }

    return mapping;
  }

  Map<int, int> numberMapping = {};

  void initBox() async {
    gCurrentBoxIndex = 0; // 현재 애니메이션 중인 상자 인덱스
    gBoxCount = gGoods.length;
    selectedGeometry =
        adjustBoxGeometryPivot(selectedGeometry, -0.5, -0.5, -0.5);
    selectedMesh = three.Mesh(selectedGeometry, selectedMaterial);

    selectedMesh.renderOrder = 9999;
    geometry = adjustBoxGeometryPivot(geometry, -0.5, -0.5, -0.5);
    matrix = three.Matrix4();

    List<int> numbers = [];
    for (int i = 0; i < gGoods.length; i++) {
      numbers.add(gGoods[i].buildingId);
    }
    Map<int, int> numberMapping = mapNumbersToSequential(numbers);

    for (int i = 0; i < gGoods.length; i++) {
      var randomValue = gGoods[i].position;
      //randomVector3(truckSize.x, truckSize.y, truckSize.z);

      boxes.add(SimulBox(
          gGoods[i].type,
          three.Vector3(randomValue.x + 25, randomValue.y, randomValue.z),
          three.Vector3(randomValue.x + 25, randomValue.y, randomValue.z),
          three.Vector3(randomValue.x, randomValue.y, randomValue.z),
          three.Vector3(2, 2, 2),
          gGoods[i].goodsId,
          gGoods[i].buildingId,
          //numberMapping[gGoods[i].buildingId]!,//gGoods[i].buildingId,
          numberMapping[gGoods[i].buildingId]!));
    }
    print("boxes.length = ${boxes.length}");
    for (int i = 0; i < boxes.length; i++) {
      boxes[i].init();
    }

    /* 처음에 한번 집어 넣어줘야함 */
    for (int i = 0; i < 21; i++) {
      meshes.add(three.InstancedMesh(geometry, materials[i], boxes.length));
    }
    edgeMesh = three.InstancedMesh(geometry, edgeMaterial, boxes.length);
    transparentEdgeMesh =
        three.InstancedMesh(geometry, transparentEdgeMaterial, boxes.length);

    var quaternion = three.Quaternion();
    for (int i = 0; i < boxes.length; i++) {
      var box = boxes[i];
      if (box.isDone) {
        continue;
      }

      matrix.setPosition(
          box.currPosition!.x, box.currPosition!.y, box.currPosition!.z);
      matrix.compose(box.currPosition!, quaternion, box.boxSize!);
      meshes[box.boxColorId].setMatrixAt(i, matrix.clone());
    }

    for (int i = 0; i < 21; i++) {
      scene.add(meshes[i]);
    }
    scene.add(edgeMesh);
    scene.add(transparentEdgeMesh);
  }

  static double lastCheckTransparantValue = 80.0;

  void createVisualRay(
      three.Vector2 pointer, three.Camera camera, three.Scene scene) {
    three.Raycaster raycaster = three.Raycaster();
    raycaster.setFromCamera(pointer, camera);

    three.Vector3 start = camera.position;
    three.Vector3 end = raycaster.ray.direction
        .clone()
        .multiplyScalar(500)
        .add(camera.position);
    three.BufferGeometry geometry = three.BufferGeometry();
    List<double> vertices = [start.x, start.y, start.z, end.x, end.y, end.z];
    geometry.setAttribute('position',
        three.Float32BufferAttribute(Float32Array.from(vertices), 3));
    three.LineBasicMaterial material =
        three.LineBasicMaterial({'color': 0xff0000});

    three.Line line = three.Line(geometry, material);
    scene.add(line);
  }

  three.Vector2 worldToScreen(three.Vector3 worldCoords, three.Camera camera,
      double screenWidth, double screenHeight) {
    worldCoords.project(camera);

    return three.Vector2((worldCoords.x + 1) * screenWidth / 2,
        -(worldCoords.y - 1) * screenHeight / 2);
  }

  /**********************************************************/
  /**
   * MainLoop
   *
   */
  int lastcheck = 0;

  void onTickBox() {
    if (boxes.isEmpty) {
      return;
    }
    if (lastCheckTransparantValue != transparencyValuePercent) {
      for (int i = 0; i < 20; i++) {
        materials[i].opacity = transparencyValuePercent / 100.0;
      }
      lastCheckTransparantValue = transparencyValuePercent;
    }

    if (gCurrentBoxIndex < 0)
      gCurrentBoxIndex = 0;
    else if (gCurrentBoxIndex >= boxes.length)
      gCurrentBoxIndex = boxes.length - 1;

    if (gIsForword) {
      if (gCurrentBoxIndex < boxes.length) {
        SimulBox currentBox = boxes[gCurrentBoxIndex];
        currentBox.update();
        if (currentBox.isDone && gCurrentBoxIndex < boxes.length) {
          gCurrentBoxIndex++;
        }
      }
    } else {
      if (gCurrentBoxIndex >= 0) {
        if (gCurrentBoxIndex >= boxes.length) {
          gCurrentBoxIndex = boxes.length - 1;
        }
        SimulBox currentBox = boxes[gCurrentBoxIndex];
        currentBox.update();
        if (currentBox.isDone && gCurrentBoxIndex >= 0) {
          gCurrentBoxIndex--;
        }
      }
    }

    updateBoxVisibility();

    scene.remove(edgeMesh);
    scene.remove(transparentEdgeMesh);
    for (int i = 0; i < 21; i++) {
      scene.remove(meshes[i]);
    }

    //loadTruck();

    matrix = three.Matrix4();
    for (int i = 0; i < 21; i++) {
      meshes[i] =
          three.InstancedMesh(geometry, materials[i], boxes.length + 40);
    }
    edgeMesh = three.InstancedMesh(geometry, edgeMaterial, boxes.length + 40);
    transparentEdgeMesh = three.InstancedMesh(
        geometry, transparentEdgeMaterial, boxes.length + 40);

    var quaternion = three.Quaternion();

    for (int i = 0; i < gCurrentBoxIndex + 1 && i < boxes.length; i++) {
      var box = boxes[i];
      if (box.isChecked == false) {
        continue;
      }
      if (box.isVisible == false) {
        continue;
      }
      if (gIsForword == false && box.isDone) {
        continue;
      }

      matrix.setPosition(
          box.currPosition!.x, box.currPosition!.y, box.currPosition!.z);
      matrix.compose(box.currPosition!, quaternion, box.boxSize!);

      meshes[box.boxColorId].name = box.boxColorId.toString();
      meshes[box.boxColorId].setMatrixAt(i, matrix.clone());
      edgeMesh.setMatrixAt(i, matrix.clone());
    }

    matrix.setPosition(0, 0, 0);
    matrix.compose(three.Vector3(0, 0, 0), quaternion, truckSize);
    edgeMesh.setMatrixAt(boxes.length, matrix.clone());

    three.Vector3 bottomPannelsize = truckSize.clone();
    bottomPannelsize.y = 0.5;
    matrix.setPosition(0, -0.5, 0);
    matrix.compose(three.Vector3(0, -0.5, 0), quaternion, bottomPannelsize);
    meshes[20].setMatrixAt(0, matrix.clone());

    bottomPannelsize = truckSize.clone();
    bottomPannelsize.x = 0.5;
    matrix.setPosition(-0.5, -0.5, 0);
    matrix.compose(three.Vector3(-0.5, 0, 0), quaternion, bottomPannelsize);
    meshes[20].setMatrixAt(1, matrix.clone());

    bottomPannelsize = truckSize.clone();
    bottomPannelsize.z = 0.5;
    matrix.setPosition(0, 0, -0.5);
    matrix.compose(three.Vector3(0, 0, -0.5), quaternion, bottomPannelsize);
    meshes[20].setMatrixAt(2, matrix.clone());
    bottomPannelsize = truckSize.clone();

    for (int i = 0; i < 21; i++) {
      scene.add(meshes[i]);
    }
    scene.add(edgeMesh);
    scene.add(transparentEdgeMesh);

    // 레이트레이싱 사용해서 선택된 박스 찾기
    if (isClickOrTaped) {
      if (isSelected) {
        scene.remove(selectedMesh);
        scene.remove(selectedEdgeMesh);
        if (selectedBoxOverlayWidget.isShowing) {
          selectedBoxOverlayWidget.remove();
        }
        //selectedBoxOverlayWidget.remove();
      }
      isSelected = false;
      isClickOrTaped = false;
      //createVisualRay(clickedScrinPoint, camera, scene);

      raycaster.setFromCamera(
          three.Vector2(clickedScrinPoint.x, clickedScrinPoint.y), camera);
      var intersects = raycaster.intersectObjects(scene.children, true);

      if (intersects.isNotEmpty) {
        for (int i = 0; i < intersects.length; i++) {
          if (intersects[i].object is three.InstancedMesh) {
            if (intersects[i].object.name.isNotEmpty) {
              int selectedBuildingId = int.parse(intersects[i].object.name);
              three.Vector3 intersectedPoint = intersects[i].point;

              three.CircleGeometry circleGeometry = three.CircleGeometry();
              three.Mesh circle = three.Mesh(
                  circleGeometry,
                  three.MeshBasicMaterial({
                    "color": 0xFFFFFFFF,
                    "side": three.DoubleSide,
                    "depthTest": false,
                    "transparent": true
                  }));

              circle.position.set(intersects[i].point.x, intersects[i].point.y,
                  intersects[i].point.z);
              circle.renderOrder = 1;

              //scene.add(circle);

              double minDistance = double.infinity;
              for (var box in boxes) {
                if (box.isVisible == false) {
                  continue;
                }
                if (box.isChecked == false) {
                  continue;
                }
                if (box.boxColorId == selectedBuildingId) {
                  three.Vector3 centerPosition = three.Vector3(
                      box.currPosition.x + box.boxSize.x / 2.0,
                      box.currPosition.y + box.boxSize.y / 2.0,
                      box.currPosition.z + box.boxSize.z / 2.0);

                  double distToPoint =
                      intersectedPoint.distanceTo(centerPosition);
                  if (distToPoint < minDistance) {
                    minDistance = distToPoint;
                    selectedBox = box;
                  }
                }
              }
              if (minDistance != double.infinity) {
                isSelected = true;
                selectedGeometry = three.BoxGeometry(selectedBox.boxSize.x,
                    selectedBox.boxSize.y, selectedBox.boxSize.z);

                //selectedGeometry = adjustBoxGeometryPivot(selectedGeometry, -1 * selectedBox.boxSize.x, -1 * selectedBox.boxSize.y, -1 * selectedBox.boxSize.z);

                selectedEdgeMesh = three.Mesh(
                    selectedGeometry,
                    three.MeshPhongMaterial({
                      "color": 0xFF000000,
                      "flatShading": true,
                      "transparent": true,
                      "opacity": 1.0,
                      "wireframe": true,
                      "side": three.DoubleSide,
                      'depthTest': false, // 깊이 테스트 비활성화
                      'depthWrite': false, // 깊이 버퍼에 쓰기 비활성화
                      // 'renderOrder': 1000  // 다른 객체들보다 나중에 렌더링되도록 순서 설정
                    }));

                selectedMesh = three.Mesh(selectedGeometry, selectedMaterial);
                selectedMesh.position.set(
                    selectedBox.currPosition.x + selectedBox.boxSize.x / 2.0,
                    selectedBox.currPosition.y + selectedBox.boxSize.y / 2.0,
                    selectedBox.currPosition.z + selectedBox.boxSize.z / 2.0);
                selectedMesh.renderOrder = 9999;
                scene.add(selectedMesh);
                selectedMesh.renderOrder = 9999;
                selectedEdgeMesh.position.set(
                    selectedBox.currPosition.x + selectedBox.boxSize.x / 2.0,
                    selectedBox.currPosition.y + selectedBox.boxSize.y / 2.0,
                    selectedBox.currPosition.z + selectedBox.boxSize.z / 2.0);
                scene.add(selectedEdgeMesh);
                selectedBoxOverlayWidget.show();

                GoodsStore goodsStore = context.read<GoodsStore>();
                goodsStore.setSelectedGoodsId(selectedBox.goodsId);
                break;
              }
            }
          }
        }
      }
    }

    if (lastcheck != gCurrentBoxIndex) {
      lastcheck = gCurrentBoxIndex;
      Provider.of<BoxStore>(context, listen: false)
          .setEveryThing(gCurrentBoxIndex, gBoxCount);
    }
  }
}
