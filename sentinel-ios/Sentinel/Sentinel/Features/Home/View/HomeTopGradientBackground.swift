import SentinelUI
import SentinelCore
import SwiftUI

struct HomeTopGradientBackground: View {
    var body: some View {
        ZStack(alignment: .top) {
            AppPlatformColor.systemGroupedBackground

            LinearGradient(
                colors: [
                    Color(red: 0.78, green: 0.90, blue: 1.0),
                    Color(red: 0.90, green: 0.88, blue: 1.0),
                    Color(red: 0.93, green: 0.97, blue: 1.0),
                    AppPlatformColor.systemGroupedBackground
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .frame(height: 420)
            .mask {
                LinearGradient(colors: [.white, .white, .clear], startPoint: .top, endPoint: .bottom)
            }

            Circle()
                .fill(Color.cyan.opacity(0.18))
                .frame(width: 280, height: 280)
                .blur(radius: 34)
                .offset(x: -110, y: -40)

            Circle()
                .fill(Color.pink.opacity(0.14))
                .frame(width: 300, height: 300)
                .blur(radius: 42)
                .offset(x: 120, y: -30)
        }
    }
}
