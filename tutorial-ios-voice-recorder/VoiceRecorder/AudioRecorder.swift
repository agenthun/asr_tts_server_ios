//
//  AudioRecorder.swift
//  VoiceRecorder
//
//  Created by 胡恒 on 2024/6/14.
//  Copyright © 2024 Vasiliy Lada. All rights reserved.
//

import AVFoundation

class AudioRecorder: NSObject, AVAudioRecorderDelegate {
    private var audioRecorder: AVAudioRecorder?
    private var audioEngine: AVAudioEngine?
    private var audioFormat: AVAudioFormat?

    func startRecording() {
        audioEngine = AVAudioEngine()
        guard let audioEngine = audioEngine else { return }

        let inputNode = audioEngine.inputNode
        audioFormat = inputNode.inputFormat(forBus: 0)

        inputNode.installTap(onBus: 0, bufferSize: 1024, format: audioFormat) { buffer, _ in
            self.processAudioBuffer(buffer: buffer)
        }

        audioEngine.prepare()
        do {
            try audioEngine.start()
        } catch {
            print("Error starting audio engine: \(error.localizedDescription)")
        }
    }

    func stopRecording() {
        audioEngine?.stop()
        audioEngine?.inputNode.removeTap(onBus: 0)
    }

    private func processAudioBuffer(buffer: AVAudioPCMBuffer) {
//        let socketManager = WebSocketManager()
        if let data = convertPCMBufferToData(buffer: buffer) {
//            WebSocketManager?.sendAudioData(data)
        }
    }

    private func convertPCMBufferToData(buffer: AVAudioPCMBuffer) -> Data? {
        guard let channelData = buffer.floatChannelData else {
            return nil
        }

        let channelDataValue = channelData.pointee
        let channelDataArray = Array(UnsafeBufferPointer(start: channelDataValue, count: Int(buffer.frameLength)))

        let data = Data(buffer: UnsafeBufferPointer(start: channelDataArray, count: channelDataArray.count))
        return data
    }
}
