import SwiftUI

struct DirectorySortMenu: View {
  let order: DirectorySortOrder
  let onChange: (DirectorySortOrder) -> Void

  @State private var isHovered = false

  var body: some View {
    Menu {
      Section("Sort By") {
        ForEach(DirectorySortCriterion.allCases) { criterion in
          Button {
            onChange(.defaultOrder(for: criterion))
          } label: {
            Label(
              criterion.title,
              systemImage: order.criterion == criterion
                ? "checkmark"
                : criterion.systemImage
            )
          }
        }
      }

      Section("Direction") {
        Button {
          onChange(
            DirectorySortOrder(
              criterion: order.criterion,
              direction: .ascending
            )
          )
        } label: {
          Label(
            order.criterion.ascendingTitle,
            systemImage: order.direction == .ascending
              ? "checkmark"
              : "arrow.up"
          )
        }

        Button {
          onChange(
            DirectorySortOrder(
              criterion: order.criterion,
              direction: .descending
            )
          )
        } label: {
          Label(
            order.criterion.descendingTitle,
            systemImage: order.direction == .descending
              ? "checkmark"
              : "arrow.down"
          )
        }
      }
    } label: {
      Image(systemName: "arrow.up.arrow.down")
        .font(.system(size: 8.5, weight: .bold))
        .foregroundStyle(Color.primary.opacity(0.42))
        .frame(
          width: HubWindowControls.childHitDiameter,
          height: HubWindowControls.childHitDiameter
        )
        .contentShape(Circle())
    }
    .menuStyle(.borderlessButton)
    .menuIndicator(.hidden)
    .buttonStyle(.plain)
    .background(
      Circle()
        .fill(Color.primary.opacity(isHovered ? 0.07 : 0.035))
    )
    .frame(
      width: HubWindowControls.childHitDiameter,
      height: HubWindowControls.childHitDiameter
    )
    .contentShape(Circle())
    .onHover { isHovered = $0 }
    .allowsHitTesting(true)
    .allowsWindowActivationEvents(true)
    .help("Sort by \(order.criterion.title)")
    .accessibilityLabel("Sort folder contents")
    .accessibilityValue(
      "\(order.criterion.title), \(directionAccessibilityValue)"
    )
  }

  private var directionAccessibilityValue: String {
    switch order.direction {
    case .ascending:
      order.criterion.ascendingTitle
    case .descending:
      order.criterion.descendingTitle
    }
  }
}
