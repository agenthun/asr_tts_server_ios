//
//  AudioRecorder2.swift
//  VoiceRecorder
//
//  Created by 胡恒 on 2024/6/14.
//  Copyright © 2024 Vasiliy Lada. All rights reserved.
//

import AVFoundation
import Network

class AudioRecorder3: WebSocketConnectionDelegate {
    func onConnected(connection: WebSocketConnection) {
        print("Connected")
    }

    func onDisconnected(connection: WebSocketConnection, error: Error?) {
        if let error = error {
            print("Disconnected with error:\(error)")
        } else {
            print("Disconnected normally")
        }
    }

    func onError(connection: WebSocketConnection, error: Error) {
        print("Connection error:\(error)")
    }

    func onMessage(connection: WebSocketConnection, text: String) {
        print("Text message: \(text)")
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
            self.webSocketConnection.send(text: "ping")
        }
    }

    func onMessage(connection: WebSocketConnection, data: Data) {
        print("Data message: \(data)")
        playAudio(data: data)
    }

    private var audioEngine: AVAudioEngine!
    private var inputNode: AVAudioInputNode!
    private var bus: AVAudioNodeBus = 0
    private var bufferSize: AVAudioFrameCount = 1024

    private let webSocketURL: URL
    func setupAudioSession() {
        let audioSession = AVAudioSession.sharedInstance()
        do {
            try audioSession.setCategory(.playAndRecord, mode: .default, options: [.defaultToSpeaker, .allowBluetooth])
            try audioSession.setActive(true)
        } catch {
            print("Failed to set up audio session: \(error)")
        }
    }

    var webSocketConnection: WebSocketConnection!

    private var audioPlayer: AVAudioPlayer?

    init(webSocketURL: URL) {
        self.webSocketURL = webSocketURL
        setupAudioSession()

        audioEngine = AVAudioEngine()
        inputNode = audioEngine.inputNode

        // 设置WebSocket连接
        webSocketConnection = WebSocketTaskConnection(url: URL(string: "ws://192.168.0.106:8081")!)
        webSocketConnection.delegate = self
    }

    func playAudio(data: Data) {
        if audioPlayer?.isPlaying == true {
            audioPlayer?.stop()
        }
        do {
            audioPlayer = try AVAudioPlayer(data: data)
            audioPlayer?.volume = 1.0
            audioPlayer?.prepareToPlay()
            audioPlayer?.play()
            debugPrint("playAudio")
        } catch {
            print("Failed to play audio: \(error)")
        }
    }

    func startRecording() {
        webSocketConnection.send(text: "[msg_begin]")
        
        let recordingFormat = inputNode.outputFormat(forBus: bus)
        let sampleRate = recordingFormat.sampleRate
        let channelCount = recordingFormat.channelCount
        let commonFormat = recordingFormat.commonFormat
        let settings = recordingFormat.settings
        let bsize = AVAudioFrameCount(0.1 * Double(sampleRate))
        inputNode.installTap(onBus: bus, bufferSize: bsize, format: recordingFormat) { buffer, _ in
            self.sendAudioBuffer(buffer)
        }

//        let inputFormat=inputNode.inputFormat(forBus: bus)
////        let recordingFormat  = AVAudioFormat(
////            commonFormat: .pcmFormatInt16, 
////            sampleRate: 44000, channels: 1, interleaved: true)
//    
//        let lowPassFilter = AVAudioUnitEQ(numberOfBands: 1)
//                let filterParams = lowPassFilter.bands.first!
//                filterParams.filterType = .lowPass
//                filterParams.frequency = 5000.0 // 设置低通滤波器的截止频率
//                filterParams.bypass = false
//        
//       
//        audioEngine.attach(lowPassFilter)
//         audioEngine.connect(inputNode, to: lowPassFilter, format: inputFormat)
//                audioEngine.connect(lowPassFilter, to: audioEngine.mainMixerNode, format: inputFormat)
//
//        inputNode.installTap(onBus: bus, bufferSize: bufferSize, format: inputFormat) { buffer, _ in
//            self.sendAudioBuffer(buffer)
//        }

        do {
            audioEngine.prepare()
            try audioEngine.start()
        } catch {
            print("Failed to start audio engine: \(error)")
        }
    }

    private func sendAudioBuffer(_ buffer: AVAudioPCMBuffer) {
        if let data = convertPCMBufferToData(buffer: buffer) {
            webSocketConnection.send(data: data)
        }
    }

    private func convertPCMBufferToData(buffer: AVAudioPCMBuffer) -> Data? {
        guard let channelData = buffer.floatChannelData else {
            return nil
        }

        let channelDataValue = channelData.pointee
        let channelDataArray = Array(UnsafeBufferPointer(start: channelDataValue, count: Int(buffer.frameLength)))

        let data = Data(buffer: UnsafeBufferPointer(start: channelDataArray, count: channelDataArray.count))
        print("Processed PCM data: \(data.count) bytes")
        return data
   
//        var pcmData = Data()
//        guard let channelData = buffer.int16ChannelData else { return pcmData }
//
//            let channelDataPointer = channelData.pointee
//            let frameLength = Int(buffer.frameLength)
//   
//
//            for frame in 0..<frameLength {
//                let sample = channelDataPointer[frame]
//                let sampleData = withUnsafeBytes(of: sample.littleEndian) { Data($0) }
//                pcmData.append(sampleData)
//            }
//
//            // 对pcmData进行进一步处理或保存
//            print("Processed PCM data: \(pcmData.count) bytes")
//        return pcmData
    }

    func stopRecording() {
        webSocketConnection.send(text: "[msg_end]")
        inputNode.removeTap(onBus: bus)
        audioEngine.stop()

        if let player = audioPlayer, player.isPlaying {
            player.stop()
        }
    }
    
    func connectSocket(){
        webSocketConnection.connect()
        webSocketConnection.send(text: "ping")
    }
    
    func disconnectSocket(){
        webSocketConnection.disconnect()
    }
}
