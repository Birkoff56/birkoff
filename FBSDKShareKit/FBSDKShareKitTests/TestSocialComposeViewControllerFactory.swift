/*
 * Copyright (c) Meta Platforms, Inc. and affiliates.
 * All rights reserved.
 *
 * This source code is licensed under the license found in the
 * LICENSE file in the root directory of this source tree.
 */

@testable import FBSDKShareKit
import Foundation
import UIKit

@objcMembers
final class TestSocialComposeViewControllerFactory: NSObject, SocialComposeViewControllerFactoryProtocol {
  var stubbedSocialComposeViewController: (UIViewController & _SocialComposeViewControllerProtocol)?

  func makeSocialComposeViewController() -> _SocialComposeViewControllerProtocol? {
    stubbedSocialComposeViewController
  }
}

@objcMembers
final class TestSocialComposeViewController: UIViewController, _SocialComposeViewControllerProtocol {
  var completionHandler: _FBSDKSocialComposeViewControllerCompletionHandler = { _ in }
  var stubbedSetInitialText = false
  var capturedInitialText: String?

  func setInitialText(_ text: String) -> Bool {
    capturedInitialText = text
    return stubbedSetInitialText
  }

  func add(_ image: UIImage) -> Bool {
    false
  }

  func add(_ url: URL) -> Bool {
    false
  }
}
