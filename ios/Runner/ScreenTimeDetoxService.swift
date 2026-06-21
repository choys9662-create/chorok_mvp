import FamilyControls
import Flutter
import ManagedSettings
import SwiftUI
import UIKit

@available(iOS 16.0, *)
final class ScreenTimeDetoxService {
  static let shared = ScreenTimeDetoxService()

  private let store = ManagedSettingsStore(
    named: ManagedSettingsStore.Name("liveForest")
  )
  private let selectionKey = "live_forest_detox_selection"

  private init() {}

  var isCapabilityEnabled: Bool {
    let value = Bundle.main.object(forInfoDictionaryKey: "ChorokFamilyControlsEnabled")
      as? String
    return value?.uppercased() == "YES"
  }

  var isEnabled: Bool {
    guard isCapabilityEnabled else { return false }
    let status = AuthorizationCenter.shared.authorizationStatus
    return status != .denied
      && status != .notDetermined
      && UserDefaults.standard.bool(forKey: "live_forest_detox_enabled")
  }

  func start(from presenter: UIViewController, completion: @escaping (Result<String, Error>) -> Void) {
    guard isCapabilityEnabled else {
      completion(.success("unsupported"))
      return
    }
    Task {
      do {
        try await AuthorizationCenter.shared.requestAuthorization(for: .individual)
        let status = AuthorizationCenter.shared.authorizationStatus
        guard status != .denied && status != .notDetermined else {
          await MainActor.run { completion(.success("denied")) }
          return
        }

        if let selection = loadSelection(), !selection.isEmpty {
          apply(selection)
          await MainActor.run { completion(.success("enabled")) }
          return
        }

        await MainActor.run {
          self.presentPicker(from: presenter, completion: completion)
        }
      } catch {
        await MainActor.run { completion(.failure(error)) }
      }
    }
  }

  func stop() {
    guard isCapabilityEnabled else { return }
    store.clearAllSettings()
    UserDefaults.standard.set(false, forKey: "live_forest_detox_enabled")
  }

  private func apply(_ selection: FamilyActivitySelection) {
    store.shield.applications = selection.applicationTokens.isEmpty
      ? nil
      : selection.applicationTokens
    store.shield.applicationCategories = selection.categoryTokens.isEmpty
      ? nil
      : .specific(selection.categoryTokens)
    store.shield.webDomains = selection.webDomainTokens.isEmpty
      ? nil
      : selection.webDomainTokens
    UserDefaults.standard.set(true, forKey: "live_forest_detox_enabled")
  }

  private func presentPicker(
    from presenter: UIViewController,
    completion: @escaping (Result<String, Error>) -> Void
  ) {
    let picker = DetoxPickerView(initialSelection: loadSelection() ?? FamilyActivitySelection()) {
      [weak presenter] selection in
      presenter?.dismiss(animated: true) {
        guard let selection else {
          completion(.success("cancelled"))
          return
        }
        guard !selection.isEmpty else {
          completion(.success("emptySelection"))
          return
        }
        do {
          try self.saveSelection(selection)
          self.apply(selection)
          completion(.success("enabled"))
        } catch {
          completion(.failure(error))
        }
      }
    }
    let controller = UIHostingController(rootView: picker)
    controller.modalPresentationStyle = .formSheet
    presenter.present(controller, animated: true)
  }

  private func loadSelection() -> FamilyActivitySelection? {
    guard let data = UserDefaults.standard.data(forKey: selectionKey) else {
      return nil
    }
    return try? JSONDecoder().decode(FamilyActivitySelection.self, from: data)
  }

  private func saveSelection(_ selection: FamilyActivitySelection) throws {
    let data = try JSONEncoder().encode(selection)
    UserDefaults.standard.set(data, forKey: selectionKey)
  }
}

@available(iOS 16.0, *)
private extension FamilyActivitySelection {
  var isEmpty: Bool {
    applicationTokens.isEmpty && categoryTokens.isEmpty && webDomainTokens.isEmpty
  }
}

@available(iOS 16.0, *)
private struct DetoxPickerView: View {
  @State private var selection: FamilyActivitySelection
  let onComplete: (FamilyActivitySelection?) -> Void

  init(
    initialSelection: FamilyActivitySelection,
    onComplete: @escaping (FamilyActivitySelection?) -> Void
  ) {
    _selection = State(initialValue: initialSelection)
    self.onComplete = onComplete
  }

  var body: some View {
    NavigationStack {
      FamilyActivityPicker(
        headerText: "독서 중 열지 않을 앱과 웹사이트를 선택하세요.",
        footerText: "라이브 포레스트를 정상 종료하면 제한이 자동으로 해제됩니다.",
        selection: $selection
      )
      .navigationTitle("디톡스 앱 선택")
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .cancellationAction) {
          Button("취소") { onComplete(nil) }
        }
        ToolbarItem(placement: .confirmationAction) {
          Button("완료") { onComplete(selection) }
            .disabled(selection.isEmpty)
        }
      }
    }
  }
}

extension UIViewController {
  func chorokTopViewController() -> UIViewController {
    if let presentedViewController {
      return presentedViewController.chorokTopViewController()
    }
    if let navigationController = self as? UINavigationController {
      return navigationController.visibleViewController?.chorokTopViewController()
        ?? navigationController
    }
    if let tabBarController = self as? UITabBarController {
      return tabBarController.selectedViewController?.chorokTopViewController()
        ?? tabBarController
    }
    return self
  }
}
