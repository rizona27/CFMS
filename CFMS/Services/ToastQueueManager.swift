import SwiftUI

class ToastQueueManager: ObservableObject {
    @Published var toasts: [ToastItem] = []
    private var activeToastIds: Set<String> = []
    
    struct ToastItem: Identifiable {
        let id = UUID()
        let message: String
        let type: ToastType
        var showTime: Double
    }
    
    enum ToastType {
        case copy, report, refresh, outdated
    }
    
    func addToast(_ message: String, type: ToastType, showTime: Double = 1.5) {
        let toastId = "\(message)-\(type)"
        guard !activeToastIds.contains(toastId) else { return }
        
        let toast = ToastItem(message: message, type: type, showTime: showTime)
        
        withAnimation(.easeInOut(duration: 0.3)) {
            toasts.append(toast)
        }
        activeToastIds.insert(toastId)
        
        DispatchQueue.main.asyncAfter(deadline: .now() + showTime) { [weak self] in
            self?.removeToast(toast.id)
            self?.activeToastIds.remove(toastId)
        }
    }
    
    func removeToast(_ id: UUID) {
        withAnimation(.easeInOut(duration: 0.3)) {
            toasts.removeAll { $0.id == id }
        }
    }
    
    func removeAll() {
        withAnimation(.easeInOut(duration: 0.3)) {
            toasts.removeAll()
        }
        activeToastIds.removeAll()
    }
}
