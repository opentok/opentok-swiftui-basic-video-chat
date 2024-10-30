import OpenTok
import Combine
import PencilKit

final class OpenTokManager: NSObject, ObservableObject {
    static let shared = OpenTokManager()
    public let annotatorSignalID = UUID()
    
    // Replace with your OpenTok API key
    private let kApiKey = ""
    // Replace with your generated session ID
    private let kSessionId = ""
    // Replace with your generated token
    private let kToken = ""
    
    private lazy var session: OTSession = {
        return OTSession(apiKey: kApiKey, sessionId: kSessionId, delegate: self)!
    }()
    
    private lazy var publisher: OTPublisher = {
        let settings = OTPublisherSettings()
        settings.name = UIDevice.current.name
        return OTPublisher(delegate: self, settings: settings)!
    }()
    
    private var subscriber: OTSubscriber?
    
    @Published var pubView: UIView?
    @Published var subView: UIView?
    @Published var error: OTErrorWrapper?
    
    private let decoder = JSONDecoder()
    private let encoder = JSONEncoder()
    private var receivedAnnotationDataMap: [ReceivedChunkKey: [AnnotationBodyChunk]] = [:]
    
    private let signalSubject = PassthroughSubject<[PKStrokePoint], Never>()
    public var onAnnotation: AnyPublisher<[PKStrokePoint], Never> {
        signalSubject.eraseToAnyPublisher()
    }
    
    override init() {
        super.init()
        doConnect()
    }
    
    // MARK: - Public
    
    public func sendSignal(body: AnnotationBody) {
        if body.totalChunksCount == 1 {
            if let jsonString = makeJSONString(body: body) {
                self.sendSignal(jsonString: jsonString)
            }
        } else {
            // OT Signalling has a max data limit of 8KB, chunk up bigger drawings
            var dataArray: [String?] = []
            
            let headerBody = AnnotationBody(id: body.id, senderID: body.senderID, totalChunksCount: body.totalChunksCount)
            
            if let headerJsonString = makeJSONString(body: headerBody) {
                dataArray.append(headerJsonString)
                dataArray.append(contentsOf: chunksToJSONString(chunks: body.points))
                for jsonString in dataArray {
                    self.sendSignal(jsonString: jsonString!)
                }
            }
        }
    }
    
    // MARK: - Private
    
    private func makeJSONString(body: Codable) -> String? {
        let jsonData = try? encoder.encode(body)
        if let jsonData {
            return String(data: jsonData, encoding: .utf8)
        } else {
            return nil
        }
    }
    
    private func chunksToJSONString(chunks: [AnnotationBodyChunk]) -> [String?] {
        var dataArray: [String?] = []
        
        for chunk in chunks {
            dataArray.append(makeJSONString(body: chunk))
        }
        
        return dataArray
    }
    
    private func sendSignal(jsonString: String) {
        var error: OTError?
        defer {
            processError(error)
        }
        
        session.signal(withType: "annotation", string: jsonString, connection: nil, error: &error)
    }
    
    private func doConnect() {
        var error: OTError?
        defer {
            processError(error)
        }
        session.connect(withToken: kToken, error: &error)
    }
    
    private func doPublish() {
        var error: OTError?
        defer {
            processError(error)
        }
        
        session.publish(publisher, error: &error)
        
        if let view = publisher.view {
            updatePubView(view: view)
        }
    }
    
    private func doSubscribe(_ stream: OTStream) {
        var error: OTError?
        defer {
            processError(error)
        }
        subscriber = OTSubscriber(stream: stream, delegate: self)
        session.subscribe(subscriber!, error: &error)
    }
    
    private func cleanupSubscriber() {
        updateSubView(view: nil)
    }
    
    private func cleanupPublisher() {
        updatePubView(view: nil)
    }
    
    private func processError(_ error: OTError?) {
        if let err = error {
            Task { @MainActor in
                self.error = OTErrorWrapper(error: err.localizedDescription)
            }
        }
    }
    
    private func updatePubView(view: UIView?) {
        Task { @MainActor in
            self.pubView = view
        }
    }
    
    private func updateSubView(view: UIView?) {
        Task { @MainActor in
            self.subView = view
        }
    }
}

// MARK: - OTSessionDelegate

extension OpenTokManager: OTSessionDelegate {
    func sessionDidConnect(_ session: OTSession) {
        print("Session connected")
        doPublish()
    }
    
    func sessionDidDisconnect(_ session: OTSession) {
        print("Session disconnected")
    }
    
    func session(_ session: OTSession, didFailWithError error: OTError) {
        print("session Failed to connect: \(error.localizedDescription)")
        Task { @MainActor in
            self.error = OTErrorWrapper(error: error.localizedDescription)
        }
    }
    
    func session(_ session: OTSession, streamCreated stream: OTStream) {
        print("Session streamCreated: \(stream.streamId)")
        doSubscribe(stream)
    }
    
    func session(_ session: OTSession, streamDestroyed stream: OTStream) {
        print("Session streamDestroyed: \(stream.streamId)")
        if let subStream = subscriber?.stream, subStream.streamId == stream.streamId {
            cleanupSubscriber()
        }
    }
    
    private func getReceivedChunkKey(for annotationID: UUID) -> ReceivedChunkKey? {
        for (key, _) in receivedAnnotationDataMap {
            if key.annotationID == annotationID {
                return key
            }
        }
        return nil
    }
    
    func session(_ session: OTSession, receivedSignalType type: String?, from connection: OTConnection?, with string: String?) {
        if let jsonString = string, let jsonData = jsonString.data(using: .utf8) {
            if let body = try? JSONDecoder().decode(AnnotationBody.self, from: jsonData) {
                guard annotatorSignalID != body.senderID else { return }
                if body.totalChunksCount > 1 {
                    // Chunk header
                    let key = ReceivedChunkKey(annotationID: body.id, totalChunksCount: body.totalChunksCount)
                    if receivedAnnotationDataMap[key] == nil {
                        receivedAnnotationDataMap[key] = []
                    }
                } else {
                    signalSubject.send(body.points.first!.points)
                }
            } else if let chunk = try? JSONDecoder().decode(AnnotationBodyChunk.self, from: jsonData) {
                guard annotatorSignalID != chunk.senderID else { return }
                // Rebuild chunks
                if let key = getReceivedChunkKey(for: chunk.annotationID) {
                    receivedAnnotationDataMap[key]?.append(chunk)
                    
                    if let allChunks = receivedAnnotationDataMap[key], allChunks.count == key.totalChunksCount {
                        // If all chunks returned, order and recombine
                        let orderedChunks = allChunks.sorted { $0.position < $1.position }
                        let points = orderedChunks.flatMap { $0.points }
                        signalSubject.send(points)
                    }
                }
            }
        }
    }
}

// MARK: - OTPublisherDelegate

extension OpenTokManager: OTPublisherDelegate {
    func publisher(_ publisher: OTPublisherKit, streamCreated stream: OTStream) {
        print("Publishing")
    }
    
    func publisher(_ publisher: OTPublisherKit, streamDestroyed stream: OTStream) {
        cleanupPublisher()
        if let subStream = subscriber?.stream, subStream.streamId == stream.streamId {
            cleanupSubscriber()
        }
    }
    
    func publisher(_ publisher: OTPublisherKit, didFailWithError error: OTError) {
        print("Publisher failed: \(error.localizedDescription)")
    }
}

// MARK: - OTSubscriberDelegate

extension OpenTokManager: OTSubscriberDelegate {
    
    func subscriberDidConnect(toStream subscriberKit: OTSubscriberKit) {
        if let view = subscriber?.view {
            updateSubView(view: view)
        }
    }
    
    func subscriber(_ subscriber: OTSubscriberKit, didFailWithError error: OTError) {
        print("Subscriber failed: \(error.localizedDescription)")
        Task { @MainActor in
            self.error = OTErrorWrapper(error: error.localizedDescription)
        }
    }
}
