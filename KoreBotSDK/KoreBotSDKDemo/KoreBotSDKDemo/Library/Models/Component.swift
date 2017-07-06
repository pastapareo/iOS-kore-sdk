//
//  Component.swift
//  KoreBotSDKDemo
//
//  Created by developer@kore.com on 09/05/16.
//  Copyright © 2016 Kore Inc. All rights reserved.
//

import Foundation
import UIKit

enum ComponentType : Int {
    case unknown = 1, text = 2, image = 3, options = 4, quickReply = 5, list = 6
}

class Component : NSObject {
    var componentType: ComponentType = .unknown
    var message: Message!
    var cInfo: NSString!
    override init() {
        super.init()
    }
}

class TextComponent : Component {
    var text: NSString!
    override init() {
        super.init()
        componentType = .text
    }
}

class ImageComponent : Component {
    var imageFile: String!
    override init() {
        super.init()
        componentType = .image
    }
}

class OptionsComponent : Component {
    var payload: NSString!
    override init() {
        super.init()
        componentType = .options
    }
}

class QuickRepliesComponent : Component {
    var payload: NSString!
    override init() {
        super.init()
        componentType = .quickReply
    }
}

class ListComponent : Component {
    var payload: NSString!
    override init() {
        super.init()
        componentType = .list
    }
}

