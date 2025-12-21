import Foundation

// MARK: - Annotation Command Protocol

/// 标注命令协议（Command Pattern）
protocol AnnotationCommand {
    func execute()
    func undo()
}

// MARK: - Add Annotation Command

/// 添加标注命令
final class AddAnnotationCommand: AnnotationCommand {
    private let annotation: Annotation
    private weak var canvas: AnnotationCanvas?
    
    init(annotation: Annotation, canvas: AnnotationCanvas) {
        self.annotation = annotation
        self.canvas = canvas
    }
    
    func execute() {
        canvas?.addAnnotation(annotation, recordCommand: false)
    }
    
    func undo() {
        canvas?.removeAnnotation(annotation, recordCommand: false)
    }
}

// MARK: - Remove Annotation Command

/// 删除标注命令
final class RemoveAnnotationCommand: AnnotationCommand {
    private let annotation: Annotation
    private weak var canvas: AnnotationCanvas?
    
    init(annotation: Annotation, canvas: AnnotationCanvas) {
        self.annotation = annotation
        self.canvas = canvas
    }
    
    func execute() {
        canvas?.removeAnnotation(annotation, recordCommand: false)
    }
    
    func undo() {
        canvas?.addAnnotation(annotation, recordCommand: false)
    }
}

// MARK: - Annotation History Manager

/// 标注历史管理器
final class AnnotationHistoryManager {
    private var undoStack: [AnnotationCommand] = []
    private var redoStack: [AnnotationCommand] = []
    
    /// 最大历史记录数
    private let maxHistoryCount: Int = 50
    
    /// 回调：历史状态变化
    var onHistoryChanged: (() -> Void)?
    
    // MARK: - Public API
    
    var canUndo: Bool { !undoStack.isEmpty }
    var canRedo: Bool { !redoStack.isEmpty }
    
    /// 记录命令
    func record(_ command: AnnotationCommand) {
        undoStack.append(command)
        
        // 清空 redo 栈（新操作后不能 redo）
        redoStack.removeAll()
        
        // 限制历史数量
        if undoStack.count > maxHistoryCount {
            undoStack.removeFirst()
        }
        
        onHistoryChanged?()
    }
    
    /// 撤销
    func undo() {
        guard let command = undoStack.popLast() else { return }
        command.undo()
        redoStack.append(command)
        onHistoryChanged?()
    }
    
    /// 重做
    func redo() {
        guard let command = redoStack.popLast() else { return }
        command.execute()
        undoStack.append(command)
        onHistoryChanged?()
    }
    
    /// 清空历史
    func clear() {
        undoStack.removeAll()
        redoStack.removeAll()
        onHistoryChanged?()
    }
}
