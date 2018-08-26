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

	var activeRequests: [AsyncRequestID: DSFMountingYardItem] = [:]

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
		if url.pathExtension == "mountingYard"
		{
			let items = self.items.filter { $0.url == url }
			if items.count == 1
			{
				return self.mount(item: items.first!)
			}
		}
		else if url.pathExtension == "mountingYardExportFile"
		{
			// Merge in the content
			_ = self.importItems(from: url)
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

	func shareItems() -> Bool
	{
		let mySave = NSSavePanel()
		mySave.allowedFileTypes = ["mountingYardExportFile"]

		mySave.begin { (result) -> Void in
			if result == NSApplication.ModalResponse.OK
			{
				_ = self.shareItems(to: mySave.url!)
			}
		}
		return true
	}

	private func shareItems(to url: URL) -> Bool
	{
		var exportData: [String: Any] = [:]
		for item in self.items
		{
			exportData[item.name] = item.toDictionary()
		}
		let data = try? JSONSerialization.data(withJSONObject: exportData, options: [.prettyPrinted])
		guard let outputJson = data else
		{
			return false
		}

		do
		{
			try outputJson.write(to: url)

			try FileManager.default.setAttributes(
				[FileAttributeKey.extensionHidden: NSNumber(value: true)],
				ofItemAtPath: url.path)

			return true
		}
		catch
		{
			return false
		}
	}

	func importItems() -> Bool
	{
		let myOpen = NSOpenPanel()
		myOpen.allowedFileTypes = ["mountingYardExportFile"]

		myOpen.begin { (result) -> Void in
			if result == NSApplication.ModalResponse.OK
			{
				_ = self.importItems(from: myOpen.url!)
			}
		}
		return true
	}

	private func importItems(from url: URL) -> Bool
	{
		if let fileData = try? Data(contentsOf: url),
			let jsonData = try? JSONSerialization.jsonObject(with: fileData, options: []) as? [String: Any]
		{
			for readItem in jsonData!
			{
				if let itemData = readItem.value as? [String: Any],
					let item = DSFMountingYardItem.fromDictionary(json: itemData)
				{
					let itemName = readItem.key
					let matchingItems = self.items.filter { $0.name == itemName }
					if matchingItems.count == 0
					{
						item.name = itemName
						item.modified = true
						self.items.append(item)
					}
				}
			}
		}
		return true
	}
}

// MARK: Mounting items

extension DSFMountingYardController
{
	func mount(item: DSFMountingYardItem) -> Bool
	{
		if let mountPoint = item.validatedMountPoint()
		{
			// Already mounted!  Just show it
			NSWorkspace.shared.activateFileViewerSelecting([mountPoint])
			return true
		}

		if self.activeRequests.filter( { $0.value == item }).count != 0
		{
			// Already in the process of making the connection
			return true
		}

		guard let url = URL(string: item.address),
			let scheme = url.scheme,
			!scheme.isEmpty else
		{
			// If we cant parse the URL, or the scheme is missing
			return false
		}

		if !self.knownSchemes.contains(scheme)
		{
			// If we don't know what the scheme is, just let the finder handle it
			return self.performMountUsingFinder(item: item)
		}

		return self.performMount(item: item, serverPath: url)
	}

	private func performMount(item: DSFMountingYardItem, serverPath: URL) -> Bool
	{
		var requestID: AsyncRequestID?
		let queue = DispatchQueue.main

		item.connecting = true

		var options: [String: Any]?
		if item.guest
		{
			options = [:]
			options![kNetFSUseGuestKey] = true
		}

		let result = NetFSMountURLAsync(
			serverPath as CFURL, self.mountLocation as CFURL,
			nil, nil,
			(options != nil) ? (options as! CFMutableDictionary) : nil,
			nil,
			&requestID,
			queue,
			self.performMountAsyncCallback())

		if result != 0
		{
			print("result: \(result)")
			return false
		}
		else
		{
			self.activeRequests[requestID!] = item
		}
		return true
	}

	private func performMountAsyncCallback() -> NetFSMountURLBlock
	{
		return { [weak self] (stat, requestId, mountpoints) in

			print("msg: \(stat) mountpoint: \(String(describing: mountpoints))")

			guard let blockSelf = self else
			{
				return
			}

			guard let item = blockSelf.activeRequests[requestId!] else
			{
				return
			}
			blockSelf.activeRequests.removeValue(forKey: requestId!)

			if (stat == 0)
			{
				item.connecting = false
				let pos = mountpoints as! [String]
				let urls = pos.map { URL(fileURLWithPath: $0) }

				item.mountedPoint = urls.first!
				blockSelf.showConnectionNotification(for: item)

				NSWorkspace.shared.activateFileViewerSelecting(urls)
			}
		}
	}

	private func performMountUsingFinder(item: DSFMountingYardItem) -> Bool
	{
		guard let url = URL(string: item.address) else
		{
			return false
		}

		var updatedURL = url

		// Put the name in the default 'user' location if they've specified one
		if !item.username.isEmpty, !item.guest,
			var urlComponents = URLComponents(url: url, resolvingAgainstBaseURL: false)
		{
			urlComponents.user = item.username
			if let updated = urlComponents.url
			{
				updatedURL = updated
			}
		}

		return NSWorkspace.shared.open(updatedURL)
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
