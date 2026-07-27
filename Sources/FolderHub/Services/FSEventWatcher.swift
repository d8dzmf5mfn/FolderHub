import CoreServices
import Foundation

final class FSEventWatcher {
  private final class CallbackBox {
    let handler: ([String]) -> Void

    init(handler: @escaping ([String]) -> Void) {
      self.handler = handler
    }
  }

  private let queue = DispatchQueue(
    label: "com.folderhub.app.fsevents",
    qos: .utility
  )
  private var stream: FSEventStreamRef?
  private var callbackBox: CallbackBox?

  func start(watching url: URL, onChange: @escaping () -> Void) {
    start(watching: url, onEvents: { _ in onChange() })
  }

  func start(
    watching url: URL,
    onEvents: @escaping ([String]) -> Void
  ) {
    stop()

    let box = CallbackBox(handler: onEvents)
    callbackBox = box
    var context = FSEventStreamContext(
      version: 0,
      info: Unmanaged.passUnretained(box).toOpaque(),
      retain: nil,
      release: nil,
      copyDescription: nil
    )
    let callback: FSEventStreamCallback = {
      _, info, _, eventPaths, _, _ in
      guard let info else { return }
      let box = Unmanaged<CallbackBox>
        .fromOpaque(info)
        .takeUnretainedValue()
      let paths = unsafeBitCast(eventPaths, to: NSArray.self)
        .compactMap { $0 as? String }
      box.handler(paths)
    }

    let flags = FSEventStreamCreateFlags(
      kFSEventStreamCreateFlagFileEvents
        | kFSEventStreamCreateFlagWatchRoot
        | kFSEventStreamCreateFlagNoDefer
        | kFSEventStreamCreateFlagUseCFTypes
    )
    guard
      let newStream = FSEventStreamCreate(
        nil,
        callback,
        &context,
        [url.path] as CFArray,
        FSEventStreamEventId(kFSEventStreamEventIdSinceNow),
        0.12,
        flags
      )
    else {
      callbackBox = nil
      return
    }

    stream = newStream
    FSEventStreamSetDispatchQueue(newStream, queue)
    FSEventStreamStart(newStream)
  }

  func stop() {
    guard let stream else {
      callbackBox = nil
      return
    }
    FSEventStreamStop(stream)
    FSEventStreamInvalidate(stream)
    FSEventStreamRelease(stream)
    self.stream = nil
    callbackBox = nil
  }

  deinit {
    stop()
  }
}
