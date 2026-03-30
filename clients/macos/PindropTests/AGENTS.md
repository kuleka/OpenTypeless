# TEST SUITE

Swift Testing suite covering all 8 services. ~450 tests across multiple files.

## STRUCTURE

```
PindropTests/
├── AudioRecorderTests.swift        # Recording lifecycle, format validation
├── TranscriptionServiceTests.swift # Model states, audio conversion
├── ModelManagerTests.swift         # Download, storage paths
├── HotkeyManagerTests.swift        # Registration, modifiers, PTT mode
├── OutputManagerTests.swift        # Clipboard, direct insert, key codes
├── HistoryStoreTests.swift         # CRUD, search, export formats
├── SettingsStoreTests.swift        # AppStorage, Keychain
├── PermissionManagerTests.swift    # Mic, Accessibility checks
├── PolishServiceTests.swift        # MockURLSession, Engine polish API
├── AppCoordinatorContextFlowTests.swift # Context flow, streaming logic
├── AppCoordinatorEnginePipelineTests.swift # Engine pipeline integration
├── UpdateServiceTests.swift        # Update service wiring
├── PindropTests.swift              # Base template
├── TestSupport.swift               # MockURLSession, ManualTaskScheduler
└── TestHelpers/                    # Protocol mocks for hardware dependencies
    ├── MockPermissionProvider.swift    # Mock for PermissionProviding protocol
    └── MockAudioCaptureBackend.swift   # Mock for AudioCaptureBackend protocol
```

## PATTERNS

### Async Testing

```swift
@MainActor
@Suite
struct ServiceTests {
    @Test func testAsync() async throws {
        let result = try await service.method()
        #expect(result == expected)
    }
}
```

### In-Memory SwiftData

```swift
let config = ModelConfiguration(isStoredInMemoryOnly: true)
modelContainer = try ModelContainer(for: schema, configurations: [config])
```

### Mock URLSession (TestSupport.swift)

```swift
class MockURLSession: URLSessionProtocol {
    var mockData: Data?
    var mockResponse: URLResponse?
    var mockError: Error?
}
```

### Mock Hardware Dependencies (AudioRecorder)

```swift
// Setup with mocks — no real microphone or permissions needed
let mockPermission = MockPermissionProvider()
mockPermission.grantPermission = true

let mockBackend = MockAudioCaptureBackend()
mockBackend.simulatedBuffers = [MockAudioCaptureBackend.makeSynthesizedBuffer(
    format: mockBackend.targetFormat
)!]

sut = try AudioRecorder(
    permissionManager: mockPermission,
    captureBackend: mockBackend
)
```

## HARDWARE DEPENDENCY TESTING

1. **Rule**: All services that depend on hardware (microphone, camera, etc.) MUST accept protocol-based dependencies via initializer injection
2. **Pattern**: Define a protocol for the hardware abstraction, create a production implementation and a mock implementation
3. **Examples**: PermissionProviding → MockPermissionProvider, AudioCaptureBackend → MockAudioCaptureBackend
4. **Future services**: Any new service with hardware dependencies should follow this exact pattern
5. **CI compatibility**: Tests MUST pass on GitHub Actions (macos runners with no microphone, no permission dialogs)

## CONVENTIONS

| Pattern         | Usage                                                                 |
| --------------- | --------------------------------------------------------------------- |
| `sut`           | System Under Test variable name                                       |
| `@MainActor`    | All tests for @MainActor services                                     |
| Permission skip | `catch AudioRecorderError.permissionDenied { expectation.fulfill() }` |
| Cleanup         | Keychain/file cleanup in setUp, nil assignments in tearDown           |
| Timeouts        | 1-5s for unit, 10s for integration                                    |
| Hardware deps   | Use protocol-based DI with mocks — never depend on real hardware      |

## WHERE TO ADD TESTS

| New Feature                | Add To                      | Pattern                               |
| -------------------------- | --------------------------- | ------------------------------------- |
| New service method         | Existing `*Tests.swift`     | Async test with #expect               |
| New service                | New `*Tests.swift`          | Copy structure from similar service   |
| API integration            | PolishServiceTests          | MockURLSession pattern                |
| SwiftData queries          | HistoryStoreTests           | In-memory container                   |
| Hardware-dependent service | Use protocol + mock pattern | See AudioRecorderTests + TestHelpers/ |

## RUN TESTS

```bash
xcodebuild test -scheme Pindrop -only-testing:PindropTests -destination 'platform=macOS'
```

## ANTI-PATTERNS

| DO NOT                                  | WHY                                                        |
| --------------------------------------- | ---------------------------------------------------------- |
| Add third-party test frameworks         | Swift Testing sufficient                                   |
| Use real network in tests               | Mock URLSession instead                                    |
| Test with real hardware/permissions     | Use MockPermissionProvider/MockAudioCaptureBackend instead |
| Leave test data on disk                 | Cleanup in tearDown                                        |
| Instantiate real AVAudioEngine in tests | Use MockAudioCaptureBackend                                |
