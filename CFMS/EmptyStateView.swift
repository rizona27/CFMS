import SwiftUI

struct EmptyStateView: View {
    let icon: String
    let title: String
    let description: String
    let action: (() -> Void)?
    
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: icon)
                .font(.system(size: 48))
                .foregroundColor(.secondary)
            
            Text(title)
                .font(.headline)
                .foregroundColor(.primary)
            
            Text(description)
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            
            if let action = action {
                Button("导入数据", action: action)
                    .buttonStyle(.borderedProminent)
            }
        }
        .padding()
    }
}

struct EmptyStateView_Previews: PreviewProvider {
    static var previews: some View {
        EmptyStateView(
            icon: "chart.bar.doc.horizontal",
            title: "暂无数据",
            description: "当前没有持仓数据，请导入数据开始使用",
            action: { }
        )
    }
}
