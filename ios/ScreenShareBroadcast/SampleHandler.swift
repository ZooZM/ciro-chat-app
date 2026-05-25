import ReplayKit
import OSLog

let broadcastLogger = OSLog(subsystem: "com.cirochat.zeyad.ciroChat.ScreenShareBroadcast", category: "Broadcast")

private enum Constants {
    static let appGroupIdentifier = "group.com.cirochat.zeyad.shared"
}

class SampleHandler: RPBroadcastSampleHandler {

    private var clientConnection: SocketConnection?
    private var uploader: SampleUploader?

    var socketFilePath: String {
        let sharedContainer = FileManager.default.containerURL(
            forSecurityApplicationGroupIdentifier: Constants.appGroupIdentifier
        )
        return sharedContainer?.appendingPathComponent("rtc_SSFD").path ?? ""
    }

    override init() {
        super.init()
        if let connection = SocketConnection(filePath: socketFilePath) {
            clientConnection = connection
            setupConnection()
            uploader = SampleUploader(connection: connection)
        }
        os_log(.debug, log: broadcastLogger, "socket path: %{public}s", socketFilePath)
    }

    override func broadcastStarted(withSetupInfo setupInfo: [String: NSObject]?) {
        DarwinNotificationCenter.shared.postNotification(.broadcastStarted)
        openConnection()
    }

    override func broadcastPaused() {}

    override func broadcastResumed() {}

    override func broadcastFinished() {
        DarwinNotificationCenter.shared.postNotification(.broadcastStopped)
        clientConnection?.close()
    }

    override func processSampleBuffer(_ sampleBuffer: CMSampleBuffer, with sampleBufferType: RPSampleBufferType) {
        guard sampleBufferType == .video else { return }
        uploader?.send(sample: sampleBuffer)
    }
}

private extension SampleHandler {

    func setupConnection() {
        clientConnection?.didClose = { [weak self] error in
            os_log(.debug, log: broadcastLogger, "connection closed: %{public}s", String(describing: error))
            if let error = error {
                self?.finishBroadcastWithError(error)
            } else {
                let stopped = NSError(
                    domain: RPRecordingErrorDomain,
                    code: 10001,
                    userInfo: [NSLocalizedDescriptionKey: "Screen sharing stopped"]
                )
                self?.finishBroadcastWithError(stopped)
            }
        }
    }

    func openConnection() {
        let queue = DispatchQueue(label: "broadcast.connectTimer")
        let timer = DispatchSource.makeTimerSource(queue: queue)
        timer.schedule(deadline: .now(), repeating: .milliseconds(100), leeway: .milliseconds(500))
        timer.setEventHandler { [weak self] in
            guard self?.clientConnection?.open() == true else { return }
            timer.cancel()
        }
        timer.resume()
    }
}
