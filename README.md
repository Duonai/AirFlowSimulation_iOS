# AirFlow Simulation on iOS

## fluidSimulation/Controllers/MainViewController.swift

프로그램의 전체적인 메인 프로세스와 AR scene, 그리고 plane detection, image detection과 같은 AR관련 기능을 관리합니다.

또한 실내 공간 3차원 재구성을 담당하는 `PointCloud Renderer`, TCP 통신 담당 `Communication`, <br/>가시화를 담당하는 `Simulation Renderer`의 모듈들을 생성하고 관리합니다.

버튼들과 그 외의 사용되는 UI들 또한 `MainViewController`에서 기능들을 관리합니다.

## fluidSimulation/Renderers/PCRenderer.swift

3차원 재구성을 위한 3D point cloud를 생성하고 그 정보를 이용해 3차원 grid로 공간을 재구성 하여 관리합니다.

- `func shouldAccumulate(frame: ARFrame)`
  - 카메라가 일정 각도, 거리를 이동 할 때 마다 `accumulatePoints`를 호출하여 point cloud를 생성합니다.

- `func accumulatePoints(frame: ARFrame, commandBuffer: MTLCommandBuffer, renderEncoder: MTLRenderCommandEncoder)`
  - 카메라로부터 받은 RGB와 depth texture를 `PCShaders`로 보내 point cloud를 생성 후 particleBuffer에 그 정보를 담습니다.

- `func checkSideline()`
  - 생성된 point cloud를 사용해 시뮬레이션을 수행할 3차원 grid를 만듭니다.
  - 처음 grid를 초기화 할 때는 지금까지 스캔된 point cloud를 사용해 공간 좌표의 최대, 최소 3차원 좌표를 구해 공간의 길이(gridLength)와 grid cell의 개수(gridSize)를 구합니다.
  - Grid cell의 크기는 10cm로 설정하여 나누었습니다. (AR공간에서 길이 값의 단위는 미터)
  - 각 grid cell 안에 pointThresh이상의 point cloud가 있을 때는 장애물이 있다고 판단해 해당하는 index의 gridArray의 값을 true로 설정해 각 grid cell이 장애물로 채워져 있는 지를 체크합니다.

## fluidSimulation/Shaders/PCShaders.metal

- `vertex void unprojectVertex(uint vertexID [[vertex_id]]...)`
  - 카메라로부터 받은 matrix들을 이용해 rgb와 depth texture를 역투영해 world space에 있는 3차원 point cloud를 생성합니다.

- `vertex ParticleVertexOut particleVertex(uint vertexID [[vertex_id]]...`<br/>`fragment ParticleFragmentOut particleFragment(ParticleVertexOut in [[stage_in]]...`
  - 생성한 point cloud의 정보를 담은 particleBuffer를 shader에서 처리하여 렌더링합니다.
  - fragment shader에서 좌표를 중심으로 일정 거리 이상의 pixel을 잘라내서 원 형태의 particle로 렌더링 합니다.

## fluidSimulation/Communication/Communication.swift

서버와의 TCP통신을 담당하는 코드입니다.

- `func makeConnection()`
  - 정해진 ip와 port 주소를 사용해 서버 프로그램에 접속합니다.
  - 그 후 work함수를 사용해 TCP 통신을 주고 받습니다. 이 과정을 OperationQueue를 사용해 멀티스레드로 수행합니다.
 
- `func work(type:Type)`
  - 수행하려는 grid 초기화 모드에 따라서 공간 정보를 먼저 서버로 보낸 뒤에 답변을 `receive`로 받습니다.
  - 그 후, while 무한루프를 멀티스레드로 수행하여 `send`와 `receive`를 반복적으로 수행합니다.
  
- `func send()`
  - 상황에 따라서 서버에 정보를 요청하거나 전송합니다.
  - `Packet.swift`에서 Packet 구조체를 구현하여서 각 데이터를 byte array형태로 저장 할 수 있게 했습니다. <br/>저장한 byte array는 서버로 전송합니다.
  - Grid의 데이터, 에어컨의 위치, 기류 모드 등의 데이터가 업데이트 되면 그 데이터를 서버에 전송합니다. <br/>그 외에는 기류 시뮬레이션 데이터를 실시간으로 수신합니다.
 
- `func receive()`
  - 서버로부터 전송된 데이터를 수신합니다. 들어오는 byte array의 앞 부분 4개는 packet의 길이를 담고 있어 <br/>그만큼 packet이 들어올 때까지 계속 packet을 수신하고 완성된 byte array를 `process`를 호출하여 decoding합니다.

## fluidSimulation/Renderers/SimulationRenderer.swift

서버로부터 받은 시뮬레이션 데이터를 사용해 AR환경에서 가시화 하는 코드입니다.
<br/> 화살표 기법을 대표 예시로 합니다. 다른 가시화 기법도 비슷한 형태로 수행됩니다.

- `func startArrowAnimation()`
  - 각 에어컨 기종에 따라 정해진 index의 grid cell에서 화살표 오브젝트를 생성합니다.
 
- `func createArrowAnimation(x:Int, y:Int, z:Int)`
  - 화살표 오브젝트를 생성하고자 하는 index의 grid cell 위치를 이용해 화살표 오브젝트를 생성합니다.
  - 화살표는 생성 될 때 쿼터니온을 사용해 서버로부터 받은 기류의 벡터 방향을 향하게 회전합니다.
 
- `func updateArrow(currentFrame: ARFrame, arrow_speed: Float)`
  - `ArrowTimer` 변수를 사용해 `startArrowAnimation`을 주기적으로 호출하여 화살표를 생성합니다.
  - 각 오브젝트는 주변 8개 cell의 속도 벡터와 온도 값을 trilinear interpolation을 수행하여 자신의 속도 벡터와 온도를 결정합니다.
  - Interpolation을 GPU 병렬 연산으로 수행하기 위해 오브젝트들의 위치 정보를 `arrowVertices`배열에 넣습니다.
  - 이 배열을 사용해 `gpu_interpolation`을 호출,`SimulationShaders.metal`에 넘겨서 interpolation 연산을 병렬로 수행합니다.
  - Interpolation을 수행한 속도 벡터와 온도 값을 `newDirection`과 `newTemp`로 얻습니다.
  - 각 오브젝트는 `newDirection`방향으로 이동하고 `newTemp`온도에 따라서 `getTemperatureColor`로 색을 결정합니다.
  - 시각적 편의성과 연산 효율을 위해 속도, 온도가 threshold를 넘긴 오브젝트들을 `removeArray`에 넣어 제거합니다. <br/>또한 생성된 오브젝트의 수가 일정 threshold 이상이 된다면 오래된 오브젝트부터 제거합니다.

## fluidSimulation/Renderers/Compute.swift

- `func gpu_interpolate(device: MTLDevice, commandQueue: MTLCommandQueue, verticies:[simd_float3])`
  - 오브젝트들의 위치, 공간 정보와 기류의 속도, 방향 벡터, 온도 데이터를 SimulationShaders.metal로 보내 병렬 연산을 수행합니다.
