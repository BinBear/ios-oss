@testable import Kickstarter_Framework
@testable import KsApi
import Library
import Prelude
import SnapshotTesting
import UIKit

final class SettingsNotificationsViewControllerTests: TestCase {
  override func setUp() {
    super.setUp()
    UIView.setAnimationsEnabled(false)
  }

  override func tearDown() {
    UIView.setAnimationsEnabled(true)
    super.tearDown()
  }

  func testSettingsNotificationsViewController() {
    let currentUser = .template
      |> UserAttribute.notification(.friendActivity).keyPath .~ true
      |> UserAttribute.notification(.mobileFollower).keyPath .~ true
      |> \.stats.backedProjectsCount .~ 1_234
      |> \.stats.memberProjectsCount .~ 2

    let mockService = MockService(fetchUserSelfResponse: currentUser)

    combos(Language.allLanguages, [Device.phone4_7inch, Device.phone5_8inch, Device.pad]).forEach {
      language, device in

      withEnvironment(
        apiService: mockService,
        currentUser: currentUser,
        language: language
      ) {
        let controller = Storyboard.SettingsNotifications.instantiate(
          SettingsNotificationsViewController.self
        )
        let (parent, _) = traitControllers(device: device, orientation: .portrait, child: controller)

        self.scheduler.run()

        assertSnapshot(matching: parent.view, as: .image, named: "lang_\(language)_device_\(device)")
      }
    }
  }

  func testSettingsNotificationsViewController_isCreator() {
    let currentUser = .template
      |> UserAttribute.notification(.pledgeActivity).keyPath .~ true
      |> UserAttribute.notification(.creatorTips).keyPath .~ true
      |> \.stats.backedProjectsCount .~ 5
      |> \.stats.memberProjectsCount .~ 2
      |> \.stats.createdProjectsCount .~ 4

    let mockService = MockService(fetchUserSelfResponse: currentUser)

    combos(Language.allLanguages, [Device.phone4_7inch, Device.phone5_8inch, Device.pad]).forEach {
      language, device in

      withEnvironment(
        apiService: mockService,
        currentUser: currentUser,
        language: language
      ) {
        let controller = Storyboard.SettingsNotifications.instantiate(
          SettingsNotificationsViewController.self
        )
        let (parent, _) = traitControllers(device: device, orientation: .portrait, child: controller)

        self.scheduler.run()

        assertSnapshot(matching: parent.view, as: .image, named: "lang_\(language)_device_\(device)")
      }
    }
  }
}
