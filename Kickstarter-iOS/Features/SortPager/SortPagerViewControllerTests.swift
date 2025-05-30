@testable import Kickstarter_Framework
@testable import KsApi
@testable import Library
import Prelude
import SnapshotTesting
import XCTest

internal final class SortPagerViewControllerTests: TestCase {
  fileprivate let sorts: [DiscoveryParams.Sort] = [.magic, .popular, .newest, .endingSoon]

  override func setUp() {
    super.setUp()
    UIView.setAnimationsEnabled(false)
  }

  override func tearDown() {
    UIView.setAnimationsEnabled(true)
    super.tearDown()
  }

  func testSortView() {
    Language.allLanguages.forEach { language in
      withEnvironment(language: language) {
        let controller = SortPagerViewController.instantiate()
        controller.configureWith(sorts: self.sorts)

        let (parent, _) = traitControllers(device: .phone4_7inch, orientation: .portrait, child: controller)
        parent.view.frame.size.height = 50

        self.scheduler.advance(by: .milliseconds(100))

        assertSnapshot(matching: parent.view, as: .image, named: "lang_\(language)")
      }
    }
  }

  func testSortView_iPad() {
    Language.allLanguages.forEach { language in
      withEnvironment(language: language) {
        let controller = SortPagerViewController.instantiate()
        controller.configureWith(sorts: self.sorts)

        let (parent, _) = traitControllers(device: .pad, orientation: .portrait, child: controller)
        parent.view.frame.size.height = 50

        self.scheduler.advance(by: .milliseconds(100))

        assertSnapshot(matching: parent.view, as: .image, named: "lang_\(language)")
      }
    }
  }

  func testSortView_iPad_Landscape() {
    Language.allLanguages.forEach { language in
      withEnvironment(language: language) {
        let controller = SortPagerViewController.instantiate()
        controller.configureWith(sorts: self.sorts)

        let (parent, _) = traitControllers(device: .pad, orientation: .landscape, child: controller)
        parent.view.frame.size.height = 50

        self.scheduler.advance(by: .milliseconds(100))

        assertSnapshot(matching: parent.view, as: .image, named: "lang_\(language)")
      }
    }
  }
}
