//
//  AudioRecorder2.swift
//  VoiceRecorder
//
//  Created by 胡恒 on 2024/6/14.
//  Copyright © 2024 Vasiliy Lada. All rights reserved.
//

import AVFoundation
import Network

class AudioRecorder2 {
    private var audioEngine: AVAudioEngine!
    private var inputNode: AVAudioInputNode!
    private var bus: AVAudioNodeBus = 0
    private var bufferSize: AVAudioFrameCount = 1024

    private var webSocketTask: URLSessionWebSocketTask?

    private let webSocketURL:URL
    func setupAudioSession() {
        let audioSession = AVAudioSession.sharedInstance()
        do {
            try audioSession.setCategory(.playAndRecord, mode: .default, options: [.defaultToSpeaker, .allowBluetooth])
            try audioSession.setActive(true)
        } catch {
            print("Failed to set up audio session: \(error)")
        }
    }
    
    

    init(webSocketURL: URL) {
        self.webSocketURL=webSocketURL
        setupAudioSession()

        audioEngine = AVAudioEngine()
        inputNode = audioEngine.inputNode

        // 设置WebSocket连接
    }

    func startRecording() {
        let session = URLSession(configuration: .default)
        webSocketTask = session.webSocketTask(with: webSocketURL)
        webSocketTask?.resume()

        let recordingFormat = inputNode.outputFormat(forBus: bus)

        inputNode.installTap(onBus: bus, bufferSize: bufferSize, format: recordingFormat) { buffer, _ in
            self.sendAudioBuffer(buffer)
        }

        do {
            audioEngine.prepare()
            try audioEngine.start()
        } catch {
            print("Failed to start audio engine: \(error)")
        }
    }

    private func sendAudioBuffer(_ buffer: AVAudioPCMBuffer) {
        guard let channelData = buffer.floatChannelData else {
            return
        }

        let channelDataValue = channelData.pointee
        let channelDataArray = Array(UnsafeBufferPointer(start: channelDataValue, count: Int(buffer.frameLength)))

        let data = Data(buffer: UnsafeBufferPointer(start: channelDataArray, count: channelDataArray.count))

        let message = URLSessionWebSocketTask.Message.data(data)
        webSocketTask?.send(message) { error in
            if let error = error {
                print("WebSocket sending error: \(error)")
            }
        }
    }

    func stopRecording() {
        inputNode.removeTap(onBus: bus)
        audioEngine.stop()
        webSocketTask?.cancel(with: .goingAway, reason: nil)
    }
}
