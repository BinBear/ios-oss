import Foundation
import KsApi
import ReactiveSwift

public protocol MessageCellViewModelInputs {
  func configureWith(message: Message)

  /// Call when the cell header is tapped
  func cellHeaderTapped()
}

public protocol MessageCellViewModelOutputs {
  var avatarURL: Signal<URL?, Never> { get }
  var name: Signal<String, Never> { get }
  var timestamp: Signal<String, Never> { get }
  var timestampAccessibilityLabel: Signal<String, Never> { get }
  var body: Signal<String, Never> { get }

  /// Emits the message's `Sender` of the tapped message.
  var messageSender: Signal<User, Never> { get }
}

public protocol MessageCellViewModelType {
  var inputs: MessageCellViewModelInputs { get }
  var outputs: MessageCellViewModelOutputs { get }
}

public final class MessageCellViewModel: MessageCellViewModelType, MessageCellViewModelInputs,
  MessageCellViewModelOutputs {
  public init() {
    let message = self.messageProperty.signal.skipNil()

    self.avatarURL = message.map { URL.init(string: $0.sender.avatar.large ?? $0.sender.avatar.medium) }

    self.name = message.map { $0.sender.name }

    self.timestamp = message.map {
      Format.date(secondsInUTC: $0.createdAt, dateStyle: .short, timeStyle: .short)
    }

    self.timestampAccessibilityLabel = message.map {
      Format.date(secondsInUTC: $0.createdAt, dateStyle: .long, timeStyle: .short)
    }

    self.body = message.map { $0.body }

    self.messageSender = message
      .takeWhen(self.cellHeaderTappedProperty.signal)
      .map(\.sender)
  }

  fileprivate let messageProperty = MutableProperty<Message?>(nil)
  public func configureWith(message: Message) {
    self.messageProperty.value = message
  }

  fileprivate let cellHeaderTappedProperty = MutableProperty(())
  public func cellHeaderTapped() {
    self.cellHeaderTappedProperty.value = ()
  }

  public let avatarURL: Signal<URL?, Never>
  public let name: Signal<String, Never>
  public let timestamp: Signal<String, Never>
  public var timestampAccessibilityLabel: Signal<String, Never>
  public let body: Signal<String, Never>
  public let messageSender: Signal<User, Never>

  public var inputs: MessageCellViewModelInputs { return self }
  public var outputs: MessageCellViewModelOutputs { return self }
}
