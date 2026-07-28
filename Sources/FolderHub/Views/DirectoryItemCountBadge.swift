import SwiftUI

struct DirectoryItemCountBadge: View {
  let count: Int

  var body: some View {
    Text(count.formatted())
      .font(.system(size: 8.5, weight: .semibold, design: .rounded))
      .monospacedDigit()
      .foregroundStyle(Color.primary.opacity(0.46))
      .padding(.horizontal, 4)
      .frame(minWidth: 14, minHeight: 13)
      .background(
        Capsule()
          .fill(Color.primary.opacity(0.055))
      )
      .accessibilityHidden(true)
  }
}
