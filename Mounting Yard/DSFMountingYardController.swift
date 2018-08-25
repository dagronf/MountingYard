//
//  DSFMountingYardController.swift
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
import NetFS

@objc public class DSFMountingYardController: NSObject, NSUserNotificationCenterDelegate
{
	lazy var filesLocation: URL = {
		var appSupport = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first
		appSupport!.appendPathComponent("Mounting Yard")
		try? FileManager.default.createDirectory(at: appSupport!, withIntermediateDirectories: false, attributes: nil)
		return appSupport!
	}()

	lazy var mountLocation: URL = {
		var userLoc = filesLocation
		userLoc.appendPathComponent("mounts")
		try? FileManager.default.createDirectory(at: userLoc, withIntermediateDirectories: false, attributes: nil)
		return userLoc
	}()

	let knownSchemes = Set(["smb", "afp", "cifs", "ftp"])

	// The urls which we successfully loaded from
	var managedUrls: [URL] = []

	@objc public dynamic var items: [DSFMountingYardItem] = []
}

// MARK: Loading and saving

extension DSFMountingYardController
{
	func load()
	{
		NSUserNotificationCenter.default.delegate = self
		do
		{
			if let fileURLs = try? FileManager.default.contentsOfDirectory(
				at: self.filesLocation,
				includingPropertiesForKeys: nil,
				options: [.skipsHiddenFiles, .skipsSubdirectoryDescendants]
			)
			{
				let filtered = fileURLs.filter { $0.pathExtension == "mountingYard" }
				for url in filtered
				{
					if let data = try? Data(contentsOf: url)
					{
						if let rawData = try? JSONSerialization.jsonObject(with: data, options: []),
							let json = rawData as? [String: Any]
						{
							if let item = DSFMountingYardItem.fromDictionary(fileURL: url, json: json)
							{
								self.managedUrls.append(url)
								self.items.append(item)
							}
						}
					}
				}
			}
		}
	}

	func openFile(filename: String) -> Bool
	{
		let url = URL(fileURLWithPath: filename)

		let items = self.items.filter { $0.url == url }
		if items.count == 1
		{
			self.mount(item: items.first!)
			return true
		}
		return false
	}

	func save() -> Bool
	{
		// Make sure that the urls are synced
		for item in self.items
		{
			if item.url == nil
			{
				item.url = self.filesLocation.appendingPathComponent(item.name).appendingPathExtension("mountingYard")
				item.modified = true
			}
		}

		// Loop through the 'managed' urls (ie. the ones we loaded from)
		// and check to see if there's an item with the same url.
		// If there's not a matching url, then it has been deleted or renamed
		// We can remove it
		do
		{
			for url in self.managedUrls
			{
				let matching = self.items.filter { $0.url == url }
				if matching.count == 0
				{
					// This has been deleted or renamed.  Remove the file
					try FileManager.default.removeItem(at: url)
				}
			}
		}
		catch
		{
			//
		}

		// Only sync the ones marked as modified
		let modifiedItems = self.items.filter { $0.modified == true }
		for item in modifiedItems
		{
			let dict = item.toDictionary()
			do
			{
				let data = try JSONSerialization.data(withJSONObject: dict, options: [.prettyPrinted])
				try data.write(to: item.url!)
				try FileManager.default.setAttributes(
					[FileAttributeKey.extensionHidden: NSNumber(value: true)],
					ofItemAtPath: item.url!.path
				)
			}
			catch
			{
				return false
			}

			item.modified = false
		}
		self.managedUrls = self.items.map { $0.url! }

		return true
	}
}

// MARK: Mounting items

extension DSFMountingYardController
{
	func mount(item: DSFMountingYardItem)
	{
		if let mountPoint = item.validatedMountPoint()
		{
			// Already mounted!  Just show it
			NSWorkspace.shared.activateFileViewerSelecting([mountPoint])
			return
		}

		if let url = URL(string: item.address)
		{
			let serverPath = url as CFURL
			var requestID: AsyncRequestID?
			let queue = DispatchQueue.main

			guard let scheme = url.scheme,
				!scheme.isEmpty else
			{
				return
			}

			if !self.knownSchemes.contains(scheme)
			{
				// If we don't know what the scheme is, just let the finder handle it
				self.mountUsingFinder(item: item)
				return
			}

			var options: [String: Any]?
			if item.guest
			{
				options = [:]
				options![kNetFSUseGuestKey] = true
			}

			item.connecting = true

			let result = NetFSMountURLAsync(
				serverPath,
				self.mountLocation as CFURL,
				nil,
				nil,
				(options != nil) ? (options as! CFMutableDictionary) : nil,
				nil,
				&requestID,
				queue
			)
			{ [weak item, weak self] (stat: Int32, _: AsyncRequestID?, mountpoints: CFArray?) in
				// Done!
				print("msg: \(stat) mountpoint: \(String(describing: mountpoints))")

				if self != nil, item != nil, stat == 0
				{
					item!.connecting = false
					let pos = mountpoints as! [String]
					let urls = pos.map { URL(fileURLWithPath: $0) }

					item!.mountedPoint = urls.first!

					self?.showConnectionNotification(for: item!)

					NSWorkspace.shared.activateFileViewerSelecting(urls)
				}
			}
			if result != 0
			{
				print("result: \(result)")
			}
		}
	}

	func mountUsingFinder(item: DSFMountingYardItem)
	{
		if let url = URL(string: item.address)
		{
			var updatedURL = url

			// Put the name in the default 'user' location
			if !item.username.isEmpty, !item.guest,
				var urlComponents = URLComponents(url: url, resolvingAgainstBaseURL: false)
			{
				urlComponents.user = item.username
				if let updated = urlComponents.url
				{
					updatedURL = updated
				}
			}

			NSWorkspace.shared.open(updatedURL)
		}
	}
}

	// MARK: Notification handling

extension DSFMountingYardController
{
	func showConnectionNotification(for item: DSFMountingYardItem)
	{
		let notification = NSUserNotification()
		notification.title = NSLocalizedString("Remote server is connected", comment: "Notification message when server is successfully connected")
		notification.actionButtonTitle = "Show me"
		notification.hasActionButton = true
		notification.userInfo = ["mountPoint": item.mountedPoint!.path]

		let msg = String.localizedStringWithFormat(
			NSLocalizedString("The server ‘%@’ is now available", comment: "Descriptive message when server connects"),
			item.name
		)
		notification.informativeText = msg
		notification.soundName = NSUserNotificationDefaultSoundName
		NSUserNotificationCenter.default.deliver(notification)
	}

	public func userNotificationCenter(_: NSUserNotificationCenter, shouldPresent _: NSUserNotification) -> Bool
	{
		return true
	}

	public func userNotificationCenter(_: NSUserNotificationCenter, didActivate notification: NSUserNotification)
	{
		if let urlPath = notification.userInfo?["mountPoint"] as? String
		{
			let url = URL(fileURLWithPath: urlPath)
			NSWorkspace.shared.activateFileViewerSelecting([url])
		}
	}
}
