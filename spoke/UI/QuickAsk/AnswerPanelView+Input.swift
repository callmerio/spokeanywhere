import AppKit
import SwiftUI

private typealias DS = DesignTokens

extension AnswerPanelView {
    // MARK: - Input Area
    
    var inputArea: some View {
        inputAreaContent
            .padding(DS.Spacing.lg)
            .background(DS.Colors.chipBackground)
            .clipShape(RoundedRectangle(cornerRadius: DS.CornerRadius.lg))
            .overlay(
                RoundedRectangle(cornerRadius: DS.CornerRadius.lg)
                    .stroke(DS.Colors.borderPrimary, lineWidth: DS.BorderWidth.thin)
            )
            .overlay {
                AttachmentDropOverlay(cornerRadius: DS.CornerRadius.lg, isVisible: isDragOver)
            }
            .onDrop(of: [.image, .fileURL], isTargeted: isDragOverBinding) { providers in
                handleDropProviders(providers)
                return true
            }
            .padding(.horizontal, DS.Spacing.xl)
            .padding(.bottom, DS.Spacing.xl)
            .padding(.top, DS.Spacing.md)
    }
    
    var inputAreaContent: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.md) {
            if !pendingAttachments.isEmpty {
                pendingAttachmentsView
            }
            
            if !isRecording {
                textEditorView
            } else {
                recordingWaveform
            }
            
            inputToolbar
        }
    }
    
    var pendingAttachmentsView: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: DS.Spacing.md) {
                ForEach(pendingAttachments) { attachment in
                    AttachmentThumbnailView(
                        attachment: attachment,
                        onRemove: { removeAttachment(attachment.id) },
                        size: 60
                    )
                }
            }
            .padding(.horizontal, DS.Spacing.xs)
            .padding(.top, DS.Spacing.xs)
        }
    }
    
    var textEditorView: some View {
        HStack(alignment: .top, spacing: DS.Spacing.md) {
            if let workflow = workflowState.selectedWorkflow {
                WorkflowTagView(keyword: workflow.keyword) {
                    workflowState.reset()
                }
            }
            
            AnswerPanelTextEditor(
                text: followUpInputBinding,
                placeholder: workflowState.selectedWorkflow != nil ? "输入内容..." : "继续追问...",
                onSend: { sendMessage() },
                onPasteImage: { image in handlePasteImage(image) },
                onDragEntered: { isDragOver = true },
                onDragExited: { isDragOver = false },
                onDrop: { providers in handleDropProviders(providers) },
                onTextChange: { text, hasMarkedText in
                    _ = workflowState.detectSlashPrefix(
                        text: text,
                        hasMarkedText: hasMarkedText
                    )
                },
                onWorkflowKeyEvent: { workflowState.handleKeyEvent($0) },
                isWorkflowPickerVisible: { workflowState.isPickerVisible }
            )
            .frame(minHeight: 20, maxHeight: 60)
        }
    }
    
    var inputToolbar: some View {
        HStack(spacing: DS.Spacing.lg) {
            AttachmentPickerMenu(onAdd: { attachment in
                withAnimation { pendingAttachments.append(attachment) }
            })
            
            Spacer()
            
            if !isRecording {
                Button(action: { toggleRecording() }, label: {
                    Image(systemName: "mic")
                        .font(.system(size: DS.Layout.iconSizeMedium))
                        .foregroundStyle(DS.Colors.textPlaceholder)
                })
                .buttonStyle(.plain)
            }
            
            sendButton
        }
        .padding(.top, DS.Spacing.xs)
    }
    
    var sendButton: some View {
        Button(action: { sendMessage() }, label: {
            Image(systemName: "arrow.up.circle.fill")
                .font(.system(size: DS.Layout.iconSizeXLarge))
                .foregroundStyle(canSend ? DS.Colors.accentPrimary : DS.Colors.textPlaceholder)
        })
        .buttonStyle(.plain)
        .disabled(!canSend && !isRecording)
    }
    
    var canSend: Bool {
        !followUpInput.isEmpty || !pendingAttachments.isEmpty
    }
    
    func sendMessage() {
        guard canSend else { return }
        
        var message = followUpInput
        if let workflow = workflowState.selectedWorkflow {
            message = "/\(workflow.keyword) \(followUpInput)"
                .trimmingCharacters(in: .whitespaces)
        }
        
        onFollowUp?(message, pendingAttachments)
        followUpInput = ""
        pendingAttachments = []
        workflowState.reset()
    }
    
    func removeAttachment(_ id: UUID) {
        withAnimation(.easeInOut(duration: 0.2)) {
            pendingAttachments.removeAll { $0.id == id }
        }
    }
    
    func handlePasteImage(_ image: NSImage) {
        dependencies.inputDependencies.addImage(image) { attachment in
            withAnimation { pendingAttachments.append(attachment) }
        }
    }
    
    func handleDropProviders(_ providers: [NSItemProvider]) {
        dependencies.inputDependencies.handleDrop(providers) { attachment in
            withAnimation { pendingAttachments.append(attachment) }
        }
    }
}
