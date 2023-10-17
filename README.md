# AirFlow Simulation on iOS

`fluidSimulation/Controllers/MainViewController.swift`

프로그램의 전체적인 메인 프로세스와 AR scene, 그리고 plane detection, image detection과 같은 AR관련 기능을 관리합니다.

또한 실내 공간 3차원 재구성을 담당하는 `PointCloud Renderer`, TCP 통신 담당 `Communication`, 가시화를 담당하는 `Simulation Renderer`의 모듈들을 생성하고 관리합니다.

버튼들과 그 외의 사용되는 UI들 또한 `MainViewController`에서 기능들을 관리합니다.

## fluidSimulation/Renderers/PCRenderer.swift
3차원 재구성을 위한 3D point cloud를 생성하고 그 정보를 이용해 3차원 grid로 공간을 재구성 하여 관리합니다.

- `func shouldAccumulate(frame: ARFrame)`
  - 카메라가 일정 각도, 거리를 이동 할 때 마다 `accumulatePoints`를 호출하여 point cloud를 생성합니다.

- `func accumulatePoints(frame: ARFrame, commandBuffer: MTLCommandBuffer, renderEncoder: MTLRenderCommandEncoder)`
  - 카메라로부터 받은 RGB와 depth texture를 `PCShaders`로 보내 point cloud를 생성 후 particleBuffer에 그 정보를 담습니다. point cloud 생성 과정은 아래 `PCShader` 부분에서 설명합니다.

- `func checkSideline()`
  - 생성된 point cloud를 사용해 시뮬레이션을 수행할 3차원 grid를 만듭니다.
  - 처음 grid를 초기화 할 때는 지금까지 스캔된 point cloud를 사용해 공간 좌표의 최대, 최소 3차원 좌표를 구해 공간의 길이(gridLength)와 grid cell의 개수(gridSize)를 구합니다.
  - Grid cell의 크기는 10cm로 설정하여 나누었습니다. (AR공간에서 길이 값의 단위는 미터)
