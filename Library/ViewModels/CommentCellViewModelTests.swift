@testable import KsApi
@testable import Library
import Prelude
import ReactiveExtensions_TestHelpers
import ReactiveSwift
import XCTest

private enum Constants {
  static let communityLink = "https://www.kickstarter.com/help/community"
}

internal final class CommentCellViewModelTests: TestCase {
  let vm: CommentCellViewModelType = CommentCellViewModel()

  private let authorBadge = TestObserver<Comment.AuthorBadge, Never>()
  private let authorImageURL = TestObserver<URL?, Never>()
  private let authorName = TestObserver<String, Never>()
  private let body = TestObserver<String, Never>()
  private let bottomRowStackViewIsHidden = TestObserver<Bool, Never>()
  private let cellAuthor = TestObserver<Comment.Author, Never>()
  private let commentStatus = TestObserver<Comment.Status, Never>()
  private let flagButtonIsHidden = TestObserver<Bool, Never>()
  private let notifyDelegateLinkTappedWithURL = TestObserver<URL, Never>()
  private let postTime = TestObserver<String, Never>()
  private let postedButtonIsHidden = TestObserver<Bool, Never>()
  private let replyButtonIsHidden = TestObserver<Bool, Never>()
  private let replyCommentTapped = TestObserver<Comment, Never>()
  private let shouldIndentContent = TestObserver<Bool, Never>()
  private let viewCommentReplies = TestObserver<Comment, Never>()
  private let viewRepliesStackViewIsHidden = TestObserver<Bool, Never>()

  override func setUp() {
    super.setUp()
    self.vm.outputs.authorBadge.observe(self.authorBadge.observer)
    self.vm.outputs.authorImageURL.observe(self.authorImageURL.observer)
    self.vm.outputs.authorName.observe(self.authorName.observer)
    self.vm.outputs.body.observe(self.body.observer)
    self.vm.outputs.bottomRowStackViewIsHidden.observe(self.bottomRowStackViewIsHidden.observer)
    self.vm.outputs.cellAuthor.observe(self.cellAuthor.observer)
    self.vm.outputs.commentStatus.observe(self.commentStatus.observer)
    self.vm.outputs.flagButtonIsHidden.observe(self.flagButtonIsHidden.observer)
    self.vm.outputs.notifyDelegateLinkTappedWithURL.observe(self.notifyDelegateLinkTappedWithURL.observer)
    self.vm.outputs.postTime.observe(self.postTime.observer)
    self.vm.outputs.postedButtonIsHidden.observe(self.postedButtonIsHidden.observer)
    self.vm.outputs.replyButtonIsHidden.observe(self.replyButtonIsHidden.observer)
    self.vm.outputs.replyCommentTapped.observe(self.replyCommentTapped.observer)
    self.vm.outputs.shouldIndentContent.observe(self.shouldIndentContent.observer)
    self.vm.outputs.viewCommentReplies.observe(self.viewCommentReplies.observer)
    self.vm.outputs.viewRepliesViewHidden.observe(self.viewRepliesStackViewIsHidden.observer)
  }

  func testOutputs() {
    let author = Comment.Author.template
      |> \.imageUrl .~ "http://www.kickstarter.com/small.jpg"

    let comment = Comment.template
      |> \.author .~ author

    let project = Project.template
      |> \.personalization.isBacking .~ true

    self.vm.inputs.configureWith(comment: comment, project: project)

    self.authorBadge.assertValues([.creator], "The author's badge is emitted.")
    self.authorImageURL.assertValues([URL(string: "http://www.kickstarter.com/small.jpg")!])
    self.authorName.assertValues([comment.author.name], "The author's name is emitted.")
    self.body.assertValues([comment.body], "The comment body is emitted.")
    self.commentStatus.assertValues([.success], "The comment status is emmited.")
    self.postTime.assertValueCount(1, "The relative time of the comment is emitted.")
  }

  func testOutput_ReplyComment() {
    let comment = Comment.template
    withEnvironment(currentUser: .template) {
      self.vm.inputs.configureWith(comment: comment, project: .template)
      self.replyCommentTapped.assertDidNotEmitValue()

      self.vm.inputs.replyButtonTapped()

      self.replyCommentTapped
        .assertValue(comment, "The that should be replied to was emmited")
    }
  }

  func testOutput_CellHeaderTapped_EmitsCellAuthor() {
    let comment = Comment.template
    withEnvironment(currentUser: .template) {
      self.vm.inputs.configureWith(comment: comment, project: .template)
      self.cellAuthor.assertDidNotEmitValue()

      self.vm.inputs.cellHeaderTapped()

      self.cellAuthor
        .assertValue(comment.author)
    }
  }

  func testOutputs_bottomRowStackViewIsHidden_LoggedIn() {
    let user = User.template |> \.id .~ 12_345

    withEnvironment(currentUser: user) {
      self.vm.inputs.configureWith(comment: .template, project: .template)

      self.bottomRowStackViewIsHidden
        .assertValue(
          true,
          "The feature flags are false, therefore the stack view is hidden."
        )
    }
  }

  func testOutputs_bottomRowStackViewIsHidden_IsBacking() {
    let project = Project.template
      |> \.personalization.isBacking .~ true

    self.vm.inputs.configureWith(comment: .template, project: project)

    self.bottomRowStackViewIsHidden
      .assertValue(
        true,
        "The feature flags are false, therefore the stack view is hidden."
      )
  }

  func testOutput_bottomRowStackViewIsHidden_IsReply() {
    self.vm.inputs.configureWith(comment: .replyTemplate, project: .template)

    self.bottomRowStackViewIsHidden
      .assertValue(
        true,
        "The bottom row stack view should be hidden if comment is a reply."
      )
  }

  func testOutput_bottomRowStackViewIsHidden_LoggedOut_IsReplyTrue() {
    withEnvironment(currentUser: nil) {
      self.vm.inputs.configureWith(comment: .replyTemplate, project: .template)

      self.bottomRowStackViewIsHidden
        .assertValue(
          true,
          "The bottom row stack view should be hidden if comment is a reply."
        )
    }
  }

  func testOutput_shouldIndentContent_True() {
    self.vm.inputs.configureWith(comment: .replyTemplate, project: .template)
    self.vm.inputs.bindStyles()
    self.shouldIndentContent.assertValue(true)
  }

  func testOutput_shouldIndentContent_False() {
    self.vm.inputs.configureWith(comment: .template, project: .template)
    self.vm.inputs.bindStyles()
    self.shouldIndentContent.assertValue(false)
  }

  func testOutputs_flagButtonIsHidden() {
    self.vm.inputs.configureWith(comment: .template, project: .template)

    self.flagButtonIsHidden
      .assertValue(true, "The feature flag is not enabled, therefore the flag button is hidden.")
  }

  func testOutput_notifyDelegateLinkTappedWithURL() {
    guard let expectedURL = HelpType.community
      .url(withBaseUrl: AppEnvironment.current.apiService.serverConfig.webBaseUrl) else {
      XCTFail()
      return
    }

    self.vm.inputs.configureWith(comment: .template, project: nil)

    self.scheduler.advance()

    self.vm.inputs.linkTapped(url: expectedURL)

    self.notifyDelegateLinkTappedWithURL
      .assertValue(expectedURL, "The URL directs to Kickstarters Community Guidelines.")
  }

  func testOutputs_replyButtonIsHidden_IsBacker_False_IsLoggedOut() {
    withEnvironment(currentUser: nil) {
      self.vm.inputs.configureWith(comment: .template, project: .template)

      self.replyButtonIsHidden
        .assertValue(true, "The replyButton is hidden because the user is not a backer AND not logged in.")
    }
  }

  func testOutputs_replyButtonIsHidden_IsBacker_False_IsLoggedIn() {
    let user = User.template |> \.id .~ 12_345

    withEnvironment(currentUser: user) {
      self.vm.inputs.configureWith(comment: .template, project: .template)

      self.replyButtonIsHidden
        .assertValue(true, "The replyButton is hidden because the user is logged in but not a backer.")
    }
  }

  func testOutputs_replyButtonIsHidden_IsNotBacker_IsNotCreatorOrCollaborator_False() {
    let user = User.template |> \.id .~ 12_345

    let project = Project.template
      |> \.memberData.permissions .~ [.post, .comment]

    withEnvironment(currentUser: user) {
      self.vm.inputs.configureWith(comment: .template, project: project)

      self.replyButtonIsHidden
        .assertValue(false, "The replyButton is not hidden because the user is a creator collaborator.")
    }
  }

  func testOutputs_replyButtonIsHidden_IsNotBacker_IsNotCreatorOrCollaborator_True() {
    let user = User.template |> \.id .~ 12_345

    withEnvironment(currentUser: user) {
      self.vm.inputs.configureWith(comment: .template, project: .template)

      self.replyButtonIsHidden
        .assertValue(
          true,
          "The replyButton is hidden because the user is not backing, and not a creator or collaborator."
        )
    }
  }

  func testOutputs_replyButtonIsHidden_viewRepliesStackViewIsHidden_IsBacker_True_IsLoggedIn() {
    let project = Project.template
      |> \.personalization.isBacking .~ true

    let user = User.template |> \.id .~ 12_345

    withEnvironment(currentUser: user) {
      self.vm.inputs.configureWith(comment: .template, project: project)

      self.replyButtonIsHidden
        .assertValue(false, "The replyButton is not hidden.")
    }
    self.viewRepliesStackViewIsHidden
      .assertValue(false, "The stack view is not hidden.")
  }

  func testOutputs_replyButtonIsHidden_viewRepliesStackViewIsHidden_IsBacker_False_IsLoggedIn() {
    let user = User.template |> \.id .~ 12_345

    withEnvironment(currentUser: user) {
      self.vm.inputs.configureWith(comment: .template, project: .template)

      self.replyButtonIsHidden
        .assertValue(true, "The replyButton is hidden because the user is not a backer.")
    }
    self.viewRepliesStackViewIsHidden
      .assertValue(
        false,
        "The stack view is not hidden when there are replies on the comment."
      )
  }

  func testOutputs_UserIs_LoggedOut() {
    let author = Comment.Author.template
      |> \.imageUrl .~ "http://www.kickstarter.com/small.jpg"

    let comment = Comment.template
      |> \.author .~ author

    self.vm.inputs.configureWith(comment: comment, project: .template)

    self.authorBadge.assertValues([.creator], "The author's badge is emitted.")
    self.authorImageURL.assertValues([URL(string: "http://www.kickstarter.com/small.jpg")!])
    self.authorName.assertValues([comment.author.name], "The author's name is emitted.")
    self.body.assertValues([comment.body], "The comment body is emitted.")
    self.postTime.assertValueCount(1, "The relative time of the comment is emitted.")
    self.replyButtonIsHidden.assertValue(true, "User is not logged in.")
  }

  func testOutput_ViewCommentReplies() {
    let comment = Comment.template
    withEnvironment(currentUser: .template) {
      self.vm.inputs.configureWith(comment: comment, project: .template)
      self.viewCommentReplies.assertDidNotEmitValue()

      self.vm.inputs.viewRepliesButtonTapped()

      self.viewCommentReplies
        .assertValue(comment, "A Comment was emitted after the view replies button was tapped.")
    }
  }

  func testOutputs_When_Flag_RemovedPerGuidelines() {
    let comment = Comment.template
      |> \.removedPerGuidelines .~ true

    self.vm.inputs.configureWith(comment: comment, project: .template)

    // FIXME: MBL-2428 - Use `Strings.This_comment_has_been_removed_for_violating_kickstarters_community_guidelines` when it's added to the strings file.
    self.body
      .assertLastValue(
        "This comment has been removed for violating <a href=\"https://www.kickstarter.com/help/community\">Kickstarter’s Community Guidelines.</a>"
      )
  }

  func testOutputs_When_Flag_IsDeleted() {
    let comment = Comment.template
      |> \.isDeleted .~ true

    self.vm.inputs.configureWith(comment: comment, project: .template)

    let body = Strings.This_comment_has_been_removed_by_Kickstarter() + " " + Strings
      .Learn_more_about_comment_guidelines(community_link: Constants.communityLink)
    self.body.assertLastValue(body)
  }

  func testOutputs_When_Flag_HasFlagging() {
    let comment = Comment.template
      |> \.hasFlaggings .~ true
      |> \.sustained .~ false

    self.vm.inputs.configureWith(comment: comment, project: .template)

    let body = Strings
      .This_comment_is_under_review_for_potentially_violating_kickstarters_community_guidelines(
        community_guidelines: Constants.communityLink
      )

    self.body.assertLastValue(body)
  }

  func testOutputs_When_Flag_HasFlagging_And_Sustained() {
    let comment = Comment.template
      |> \.hasFlaggings .~ true
      |> \.sustained .~ true

    self.vm.inputs.configureWith(comment: comment, project: .template)

    self.body.assertLastValue(comment.body)
  }

  func testPersonalizedLabels_UserIs_Creator_Author() {
    let comment = Comment.template

    self.vm.inputs.configureWith(comment: comment, project: .template)
    self.authorBadge.assertValues([.creator], "The author's badge is emitted.")
  }

  func testPersonalizedLabels_User_Is_You_Author() {
    let author = Comment.Author.template
      |> \.id .~ "12345"

    let comment = Comment.template
      |> \.author .~ author
      |> \.authorBadges .~ [.superbacker]

    let user = User.template |> \.id .~ 12_345

    withEnvironment(currentUser: user) {
      self.vm.inputs.configureWith(comment: comment, project: .template)
      self.authorBadge.assertValues([.you], "The author's badge is emitted.")
    }
  }

  func testPersonalizedLabels_UserIs_Superbacker_Author() {
    let comment = Comment.superbackerTemplate

    self.vm.inputs.configureWith(comment: comment, project: .template)
    self.authorBadge.assertValues([.superbacker], "The author's badge is emitted.")
  }

  func testPersonalizedLabels_UserIs_Backer_Author() {
    let comment = Comment.backerTemplate

    self.vm.inputs.configureWith(comment: comment, project: .template)
    self.authorBadge.assertValues([.backer], "The author's badge is emitted.")
  }

  func testBlockedAuthor() {
    let comment = Comment.blockedTemplate

    self.vm.inputs.configureWith(comment: comment, project: .template)
    self.authorBadge.assertValues([.backer], "The default badge is emitted.")
    self.authorName.assertValue(Strings.Blocked_user(), "The author's name is hidden.")
    self.authorImageURL.assertValue(nil, "The author's avatar is hidden.")
    self.body.assertValue(Strings.This_user_has_been_blocked(), "The comment text is hidden.")
  }

  func testBindStylesEmitsAuthorBadge() {
    self.authorBadge.assertDidNotEmitValue()

    self.vm.inputs.configureWith(comment: .template, project: .template)

    self.authorBadge.assertValues([.creator], "The author's badge is emitted.")

    self.vm.inputs.bindStyles()

    self.authorBadge.assertValues([.creator, .creator], "The author's badge is emitted.")
  }

  func testBindStylesEmitsCommentStatus() {
    self.commentStatus.assertDidNotEmitValue()

    let comment = Comment.template
      |> \.status .~ .retrying

    self.vm.inputs.configureWith(comment: comment, project: .template)

    self.commentStatus.assertValues([.retrying], "The comment status is emitted.")
    self.postedButtonIsHidden.assertValues([true], "The posted button hiddent state is emitted.")

    self.vm.inputs.bindStyles()

    self.commentStatus.assertValues([.retrying, .retrying], "The comment status is emitted.")
    self.postedButtonIsHidden.assertValues([true, true], "The posted button hiddent state is emitted.")
  }

  func testPostedButtonIsHidden_NotHiddenWhenCommentStatus_IsRetrySuccess() {
    let comment = Comment.template
      |> \.status .~ .retrySuccess

    self.vm.inputs.configureWith(comment: comment, project: .template)

    self.commentStatus.assertValues([.retrySuccess], "The comment status is emitted.")
    self.postedButtonIsHidden.assertValues([false], "The posted button hiddent state is emitted.")

    self.vm.inputs.bindStyles()

    self.commentStatus.assertValues([.retrySuccess, .retrySuccess], "The comment status is emitted.")
    self.postedButtonIsHidden.assertValues([false, false], "The posted button hiddent state is emitted.")
  }

  func testViewRepliesContainerHidden_IsHiddenWhenNoReplies() {
    self.viewRepliesStackViewIsHidden.assertDidNotEmitValue()

    let comment = Comment.template
      |> \.replyCount .~ 0

    self.vm.inputs.configureWith(comment: comment, project: .template)

    self.viewRepliesStackViewIsHidden.assertValues([true])
  }

  func testViewRepliesContainerHidden_IsHiddenWhenCommentHasReplies_False() {
    let comment = Comment.template
      |> \.replyCount .~ 1

    self.viewRepliesStackViewIsHidden.assertDidNotEmitValue()

    self.vm.inputs.configureWith(comment: comment, project: .template)

    self.viewRepliesStackViewIsHidden
      .assertValue(false, "The stack view is not hidden because there are replies.")
  }
}
