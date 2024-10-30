//
//  Models.swift
//  BasicVideoChatSwiftUI
//
//  Created by Abdul Ajetunmobi on 29/10/2024.
//

import PencilKit

struct OTErrorWrapper: Identifiable {
    var id = UUID()
    let error: String
}

struct ReceivedChunkKey: Hashable {
    let annotationID: UUID
    let totalChunksCount: Int
}

struct AnnotationBodyChunk: Codable {
    let annotationID: UUID
    let senderID: UUID
    let position: Int
    let points: [PKStrokePoint]
}

struct AnnotationBody: Codable {
    let id: UUID
    let senderID: UUID
    let points: [AnnotationBodyChunk]
    let totalChunksCount: Int
    
    // Init for Header of chunked messages
    init(id: UUID, senderID: UUID, totalChunksCount: Int) {
        self.id = id
        self.senderID = senderID
        self.points = []
        self.totalChunksCount = totalChunksCount
    }
    
    // OT Signalling has a max data limit of 8KB, chunk up bigger drawings
    init(senderID: UUID, points: [PKStrokePoint], totalChunksCount: Int? = nil) {
        let annotationID = UUID()
        
        let estimatedSizePerPoint = 1024
        let targetEstimatedSize = 8000
        
        let totalEstimatedSize = estimatedSizePerPoint * points.count
        
        if totalEstimatedSize > targetEstimatedSize {
            let chunks = AnnotationBody.chunkPoints(annotationID, senderID, points, estimatedSizePerPoint, targetEstimatedSize)
            self.points = chunks
            self.totalChunksCount = totalChunksCount ?? chunks.count
        } else {
            self.points = [AnnotationBodyChunk(annotationID: annotationID, senderID: senderID, position: 0, points: points)]
            self.totalChunksCount = totalChunksCount ?? 1
        }
        
        self.id = annotationID
        self.senderID = senderID
    }
    
    static func chunkPoints(_ id: UUID, _ senderID: UUID, _ points: [PKStrokePoint], _ pointSize: Int, _ targetEstimatedSize: Int) -> [AnnotationBodyChunk] {
        var chunks: [AnnotationBodyChunk] = []
        var currentChunk: [PKStrokePoint] = []
        var currentChunkSize = 0
        var currentChunkPosition = 0
        
        for point in points {
            if currentChunkSize + pointSize > targetEstimatedSize {
                currentChunkPosition += 1
                chunks.append(AnnotationBodyChunk(annotationID: id, senderID: senderID, position: currentChunkPosition, points: currentChunk))
                currentChunk = [point]
                currentChunkSize = pointSize
            } else {
                currentChunk.append(point)
                currentChunkSize += pointSize
            }
        }
        
        if !currentChunk.isEmpty {
            currentChunkPosition += 1
            chunks.append(AnnotationBodyChunk(annotationID: id, senderID: senderID, position: currentChunkPosition, points: currentChunk))
        }
        
        return chunks
    }
}

extension PKStrokePoint: Codable {
    private enum CodingKeys: String, CodingKey {
        case location
        case timeOffset
        case size
        case opacity
        case force
        case azimuth
        case altitude
        case secondaryScale
    }
    
    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        let location = try container.decode(CGPoint.self, forKey: .location)
        let timeOffset = try container.decode(TimeInterval.self, forKey: .timeOffset)
        let size = try container.decode(CGSize.self, forKey: .size)
        let opacity = try container.decode(CGFloat.self, forKey: .opacity)
        let force = try container.decode(CGFloat.self, forKey: .force)
        let azimuth = try container.decode(CGFloat.self, forKey: .azimuth)
        let altitude = try container.decode(CGFloat.self, forKey: .altitude)
        let secondaryScale = try container.decode(CGFloat.self, forKey: .secondaryScale)
        
        self.init(location: location,
                  timeOffset: timeOffset,
                  size: size,
                  opacity: opacity,
                  force: force,
                  azimuth: azimuth,
                  altitude: altitude,
                  secondaryScale: secondaryScale)
    }
    
    public func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        
        try container.encode(location, forKey: .location)
        try container.encode(timeOffset, forKey: .timeOffset)
        try container.encode(size, forKey: .size)
        try container.encode(opacity, forKey: .opacity)
        try container.encode(force, forKey: .force)
        try container.encode(azimuth, forKey: .azimuth)
        try container.encode(altitude, forKey: .altitude)
        try container.encode(secondaryScale, forKey: .secondaryScale)
    }
}
