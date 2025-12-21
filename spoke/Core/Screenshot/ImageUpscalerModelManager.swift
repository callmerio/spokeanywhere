import Foundation
import CoreML
import Combine
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
        
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }
            
            // 1. Unzip
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/usr/bin/unzip")
            process.arguments = ["-o", self.zipFileURL.path, "-d", self.modelsDirectory.path]
            
            do {
                try process.run()
                process.waitUntilExit()
                
                if process.terminationStatus == 0 {
                    self.logger.info("✅ Unzip successful")
                    // Remove zip to save space
                    try? FileManager.default.removeItem(at: self.zipFileURL)
                    
                    // 2. Compile
                    self.compileModel()
                } else {
                    DispatchQueue.main.async {
                        self.state = .failed(error: "Unzip failed with code \(process.terminationStatus)")
                    }
                }
            } catch {
                DispatchQueue.main.async {
                    self.state = .failed(error: "Unzip error: \(error.localizedDescription)")
                }
            }
        }
    }
    
    private func compileModel() {
        logger.info("🔨 Compiling CoreML model...")
        
        // Ensure running on background if called directly, or continuing from unzip
        // Note: compileModel is called from background thread in unzipAndCompile,
        // but if called from checkState (main), we should dispatch.
        // Let's assume we are on background or dispatch.
        
        let work = { [weak self] in
            guard let self = self else { return }
            do {
                // compileModel(at:) returns a temporary URL
                let tempCompiledURL = try MLModel.compileModel(at: self.sourceModelURL)
                
                // Remove existing
                if FileManager.default.fileExists(atPath: self.compiledModelURL.path) {
                    try FileManager.default.removeItem(at: self.compiledModelURL)
                }
                
                // Move to permanent location
                try FileManager.default.moveItem(at: tempCompiledURL, to: self.compiledModelURL)
                
                DispatchQueue.main.async {
                    self.state = .compiled
                    self.logger.info("✅ Model compiled and ready")
                }
            } catch {
                DispatchQueue.main.async {
                    self.state = .failed(error: "Compilation failed: \(error.localizedDescription)")
                    self.logger.error("❌ Compilation error: \(error.localizedDescription)")
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
    
    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didFinishDownloadingTo location: URL) {
        // Move file to destination (ZIP)
        do {
            if FileManager.default.fileExists(atPath: zipFileURL.path) {
                try FileManager.default.removeItem(at: zipFileURL)
            }
            try FileManager.default.moveItem(at: location, to: zipFileURL)
            
            DispatchQueue.main.async {
                self.logger.info("✅ Download complete, starting unzip...")
                self.unzipAndCompile()
            }
        } catch {
            DispatchQueue.main.async {
                self.state = .failed(error: "Move file failed: \(error.localizedDescription)")
            }
        }
    }
    
    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didWriteData bytesWritten: Int64, totalBytesWritten: Int64, totalBytesExpectedToWrite: Int64) {
        let progress = Double(totalBytesWritten) / Double(totalBytesExpectedToWrite)
        DispatchQueue.main.async {
            self.state = .downloading(progress: progress)
        }
    }
    
    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        if let error = error {
            DispatchQueue.main.async {
                self.state = .failed(error: error.localizedDescription)
            }
        }
    }
}
