import AppKit
import SwiftUI

extension AnswerPanelView {
    // MARK: - Input Area
    
    var inputArea: some View {
        inputAreaContent
            .padding(14)
            .background(Color.white.opacity(0.08))
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(Color.white.opacity(0.08), lineWidth: 1)
            )
            .overlay {
                AttachmentDropOverlay(cornerRadius: 14, isVisible: isDragOver)
            }
            .onDrop(of: [.image, .fileURL], isTargeted: $isDragOver) { providers in
                handleDropProviders(providers)
                return true
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 16)
            .padding(.top, 8)
    }
    
    var inputAreaContent: some View {
        VStack(alignment: .leading, spacing: 8) {
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
            HStack(spacing: 8) {
                ForEach(pendingAttachments) { attachment in
                    AttachmentThumbnailView(
                        attachment: attachment,
                        onRemove: { removeAttachment(attachment.id) },
                        size: 60
                    )
                }
            }
            .padding(.horizontal, 4)
            .padding(.top, 4)
        }
    }
    
    var textEditorView: some View {
        HStack(alignment: .top, spacing: 8) {
            if let workflow = workflowState.selectedWorkflow {
                WorkflowTagView(keyword: workflow.keyword) {
                    workflowState.reset()
                }
            }
            
            AnswerPanelTextEditor(
                text: $followUpInput,
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
                }
            )
            .frame(minHeight: 20, maxHeight: 60)
        }
    }
    
    var inputToolbar: some View {
        HStack(spacing: 12) {
            AttachmentPickerMenu(onAdd: { attachment in
                withAnimation { pendingAttachments.append(attachment) }
            })
            
            Spacer()
            
            if !isRecording {
                Button(action: { toggleRecording() }, label: {
                    Image(systemName: "mic")
                        .font(.system(size: 16))
                        .foregroundStyle(.white.opacity(0.4))
                })
                .buttonStyle(.plain)
            }
            
            sendButton
        }
        .padding(.top, 4)
    }
    
    var sendButton: some View {
        Button(action: { sendMessage() }, label: {
            Image(systemName: "arrow.up.circle.fill")
                .font(.system(size: 28))
                .foregroundStyle(canSend ? Color.accentColor : Color.white.opacity(0.2))
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
        AttachmentManager.shared.addImage(image, source: .paste) { attachment in
            withAnimation { pendingAttachments.append(attachment) }
        }
    }
    
    func handleDropProviders(_ providers: [NSItemProvider]) {
        AttachmentManager.shared.handleDrop(providers: providers) { attachment in
            withAnimation { pendingAttachments.append(attachment) }
        }
    }
}
