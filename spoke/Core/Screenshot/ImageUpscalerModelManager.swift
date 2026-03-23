import Combine
import CoreML
import Foundation
import os

// MARK: - Model Download State

enum ImageUpscalerDownloadState: Equatable {
    case notDownloaded
    case downloading(progress: Double)
    case unziping   // new state
    case compiled
    case failed(error: String)
    
    var isReady: Bool {
        if case .compiled = self { return true }
        return false
    }
}

// MARK: - Image Upscaler Model Manager

@MainActor
final class ImageUpscalerModelManager: NSObject, ObservableObject {
    
    static let shared = ImageUpscalerModelManager()
    
    private let logger = Logger(subsystem: "com.spokeanywhere", category: "ImageUpscalerModelManager")
    
    @Published var state: ImageUpscalerDownloadState = .notDownloaded
    
    // HuggingFace Direct Link (TheMurusTeam) - ZIP
    private let modelDownloadURL = URL(string: "https://huggingface.co/TheMurusTeam/coreml-upscaler-realesrgan512/resolve/main/realesrgan512.mlmodel.zip")!
    
    // Files
    private let zipFileName = "realesrgan512.mlmodel.zip"
    private let modelFileName = "realesrgan512.mlmodel" // Name inside zip
    
    private var downloadTask: URLSessionDownloadTask?
    
    private var modelsDirectory: URL {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let dir = appSupport.appendingPathComponent("Spoke/Models/Upscaler", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }
    
    private var zipFileURL: URL {
        modelsDirectory.appendingPathComponent(zipFileName)
    }
    
    private var sourceModelURL: URL {
        modelsDirectory.appendingPathComponent(modelFileName)
    }
    
    private var compiledModelURL: URL {
        modelsDirectory.appendingPathComponent("RealESRGAN.mlmodelc") // Output name can stay generic
    }
    
    // MARK: - Init
    
    override private init() {
        super.init()
        checkState()
    }
    
    // MARK: - Public API
    
    func checkState() {
        if FileManager.default.fileExists(atPath: compiledModelURL.path) {
            state = .compiled
        } else if FileManager.default.fileExists(atPath: sourceModelURL.path) {
            // Check if it's a valid bundle/file
            compileModel()
        } else {
            state = .notDownloaded
        }
    }
    
    func downloadModel() {
        guard state != .compiled else { return }
        
        logger.info("⬇️ Starting model download...")
        state = .downloading(progress: 0.0)
        
        let session = URLSession(configuration: .default, delegate: self, delegateQueue: .main)
        downloadTask = session.downloadTask(with: modelDownloadURL)
        downloadTask?.resume()
    }
    
    func deleteModel() {
        try? FileManager.default.removeItem(at: sourceModelURL)
        try? FileManager.default.removeItem(at: compiledModelURL)
        try? FileManager.default.removeItem(at: zipFileURL)
        checkState()
        logger.info("🗑️ Model deleted")
    }
    
    func getCompiledModelURL() -> URL? {
        if state == .compiled {
            return compiledModelURL
        }
        return nil
    }
    
    // MARK: - Internal Logic
    
    private func unzipAndCompile() {
        self.state = .unziping
        logger.info("📦 Unzipping model...")
        
        let zipPath = self.zipFileURL.path
        let destPath = self.modelsDirectory.path
        
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }
            
            // 1. Unzip
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/usr/bin/unzip")
            process.arguments = ["-o", zipPath, "-d", destPath]
            
            do {
                try process.run()
                process.waitUntilExit()
                
                if process.terminationStatus == 0 {
                    self.logger.info("✅ Unzip successful")
                    // Remove zip to save space
                    try? FileManager.default.removeItem(at: URL(fileURLWithPath: zipPath))
                    
                    // 2. Compile
                    runImageUpscalerModelManagerOnMain(self) { manager in
                        manager.compileModel()
                    }
                } else {
                    runImageUpscalerModelManagerOnMain(self) { manager in
                        manager.state = .failed(error: "Unzip failed with code \(process.terminationStatus)")
                    }
                }
            } catch {
                runImageUpscalerModelManagerOnMain(self) { manager in
                    manager.state = .failed(error: "Unzip error: \(error.localizedDescription)")
                }
            }
        }
    }
    
    private func compileModel() {
        logger.info("🔨 Compiling CoreML model...")
        
        let sourceURL = self.sourceModelURL
        let targetURL = self.compiledModelURL
        
        let work: @Sendable () -> Void = { [weak self] in
            guard let self = self else { return }
            do {
                // compileModel(at:) returns a temporary URL
                let tempCompiledURL = try MLModel.compileModel(at: sourceURL)
                
                // Remove existing
                if FileManager.default.fileExists(atPath: targetURL.path) {
                    try FileManager.default.removeItem(at: targetURL)
                }
                
                // Move to permanent location
                try FileManager.default.moveItem(at: tempCompiledURL, to: targetURL)
                
                runImageUpscalerModelManagerOnMain(self) { manager in
                    manager.state = .compiled
                    manager.logger.info("✅ Model compiled and ready")
                }
            } catch {
                runImageUpscalerModelManagerOnMain(self) { manager in
                    manager.state = .failed(error: "Compilation failed: \(error.localizedDescription)")
                    manager.logger.error("❌ Compilation error: \(error.localizedDescription)")
                }
            }
        }
        
        if Thread.isMainThread {
            DispatchQueue.global(qos: .userInitiated).async(execute: work)
        } else {
            work()
        }
    }
}

// MARK: - URLSessionDownloadDelegate

extension ImageUpscalerModelManager: URLSessionDownloadDelegate {
    
    nonisolated func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didFinishDownloadingTo location: URL) {
        // Move file to destination (ZIP)
        runImageUpscalerModelManagerOnMain(self) { manager in
            do {
                if FileManager.default.fileExists(atPath: manager.zipFileURL.path) {
                    try FileManager.default.removeItem(at: manager.zipFileURL)
                }
                try FileManager.default.moveItem(at: location, to: manager.zipFileURL)
                
                manager.logger.info("✅ Download complete, starting unzip...")
                manager.unzipAndCompile()
            } catch {
                manager.state = .failed(error: "Move file failed: \(error.localizedDescription)")
            }
        }
    }
    
    nonisolated func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didWriteData bytesWritten: Int64, totalBytesWritten: Int64, totalBytesExpectedToWrite: Int64) {
        let progress = Double(totalBytesWritten) / Double(totalBytesExpectedToWrite)
        runImageUpscalerModelManagerOnMain(self) { manager in
            manager.state = .downloading(progress: progress)
        }
    }
    
    nonisolated func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        if let error = error {
            runImageUpscalerModelManagerOnMain(self) { manager in
                manager.state = .failed(error: error.localizedDescription)
            }
        }
    }
}
