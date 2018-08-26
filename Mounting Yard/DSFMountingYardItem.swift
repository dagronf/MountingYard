//
//  DSFMountingYardItem.swift
//  Mounting Yard
//
//  Created by Darren Ford on 31/7/18.
//  Copyright © 2018 Darren Ford. All rights reserved.
//

//  MIT License
//
//  Copyright (c) 2018 Darren Ford
//
//  Permission is hereby granted, free of charge, to any person obtaining a copy
//  of this software and associated documentation files (the "Software"), to deal
//  in the Software without restriction, including without limitation the rights
//  to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
//  copies of the Software, and to permit persons to whom the Software is
//  furnished to do so, subject to the following conditions:
//
//  The above copyright notice and this permission notice shall be included in all
//  copies or substantial portions of the Software.
//
//  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
//  IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
//  FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
//  AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
//  LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
//  OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
//  SOFTWARE.

import Cocoa

@objc(DSFMountingYardItem)
public class DSFMountingYardItem: NSObject
{
	var url: URL?
	var modified: Bool = false

	static var detector: NSDataDetector = {
		let types: NSTextCheckingResult.CheckingType = [.link]
		let detector = try? NSDataDetector(types: types.rawValue)
		return detector!
	}()

	@objc dynamic var urlValid: Bool
	{
		if DSFMountingYardItem.detector.numberOfMatches(
			in: self.address,
			options: NSRegularExpression.MatchingOptions(rawValue: 0),
			range: NSMakeRange(0, self.address.count)
		) > 0
		{
			return true
		}
		return false
	}

	@objc dynamic var name: String = ""
	{
		didSet
		{
			// File url is now out of sync.  Clear it
			self.url = nil
			self.modified = true
		}
	}

	@objc dynamic var icon: NSImage = DSFImageManager.unknownImage()

	@objc dynamic var address: String = ""
	{
		didSet
		{
			self.willChangeValue(forKey: "urlValid")
			self.modified = true
			self.didChangeValue(forKey: "urlValid")

			self.syncIcon()
		}
	}

	@objc dynamic var username: String = ""
	{
		didSet
		{
			self.modified = true
		}
	}

	@objc dynamic var guest: Bool = false
	{
		didSet
		{
			self.modified = true
		}
	}

	@objc dynamic var mountedPoint: URL?
	{
		didSet
		{
			self.modified = true
		}
	}

	var connecting: Bool = false

	func validatedMountPoint() -> URL?
	{
		var b: ObjCBool = false
		if let mountPoint = self.mountedPoint
		{
			if FileManager.default.fileExists(atPath: mountPoint.path, isDirectory: &b)
			{
				return mountPoint
			}
			else
			{
				// The mount point doesn't exist anymore -- the user might have ejected it!
				self.mountedPoint = nil
			}
		}
		return nil
	}

	public override init()
	{
		super.init()

		// Dummy values for new object
		self.name = "new server"
		self.address = "scheme://localhost"
		self.syncIcon()
	}

	public init(url: URL, address: String, username: String, guest: Bool = false)
	{
		super.init()

		self.url = url
		self.name = (url.lastPathComponent as NSString).deletingPathExtension
		self.address = address
		self.username = username
		self.guest = guest

		self.syncIcon()
	}

	func syncIcon()
	{
		self.willChangeValue(forKey: "icon")
		self.modified = true

		let url = URL(string: address)
		switch url?.scheme
		{
		case "afp":
			self.icon = DSFImageManager.afpImage()
		case "ftp":
			self.icon = DSFImageManager.ftpImage()
		case "smb":
			self.icon = DSFImageManager.smbImage()
		case "vnc":
			self.icon = DSFImageManager.vncImage()
		default:
			self.icon = DSFImageManager.unknownImage()
		}

		self.didChangeValue(forKey: "icon")
	}

	func toDictionary() -> [String: Any]
	{
		var dict = ["address": self.address, "username": self.username]
		if self.guest
		{
			dict["guest"] = "yes"
		}
		return dict
	}

	static func fromDictionary(fileURL: URL, json: [String: Any]) -> DSFMountingYardItem?
	{
		let item = DSFMountingYardItem(
			url: fileURL,
			address: json["address"] as! String,
			username: json["username"] as! String,
			guest: json["guest"] != nil
		)
		return item
	}

	static func fromDictionary(json: [String: Any]) -> DSFMountingYardItem?
	{
		let item = DSFMountingYardItem()
		item.address = json["address"] as! String
		item.username = json["username"] as! String
		item.guest = json["guest"] != nil
		return item
	}
}
