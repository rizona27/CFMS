import SwiftUI

struct LoadingOverlay: View {
    let message: String
    let progress: (current: Int, total: Int)?
    
    var body: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.3)
                .progressViewStyle(CircularProgressViewStyle(tint: .blue))
            
            VStack(spacing: 8) {
                Text(message)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(.primary)
                
                if let progress = progress {
                    Text("\(progress.current)/\(progress.total)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding(24)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.systemBackground))
                .shadow(color: Color.black.opacity(0.2), radius: 12, x: 0, y: 6)
        )
    }
}

struct LoadingOverlay_Previews: PreviewProvider {
    static var previews: some View {
        LoadingOverlay(message: "更新中...", progress: (3, 10))
    }
}
