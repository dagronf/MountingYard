//
//  DSFMountingYardSettingsWindowController.swift
//  Mounting Yard
//
//  Created by Darren Ford on 3/8/18.
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

class DSFMountingYardSettingsWindowController: NSWindowController, NSWindowDelegate, NSTextFieldDelegate
{
	@objc var mountingYard: DSFMountingYardController?

	@IBOutlet var nameField: NSTextField!
	@IBOutlet var addressField: NSTextField!

	@IBOutlet var itemsArrayController: NSArrayController!

	override func windowDidLoad()
	{
		super.windowDidLoad()

		self.window!.isMovableByWindowBackground = true

		// Implement this method to handle any initialization after your window controller's window has been loaded from its nib file.
	}

	@objc func yardController() -> DSFMountingYardController
	{
		return self.mountingYard!
	}

	func windowDidResignKey(_: Notification)
	{
		// If the settings window disappears, sync the updates to disk
		self.window?.makeFirstResponder(nil)
		_ = self.yardController().save()
	}

	@IBAction func addItem(_ sender: Any)
	{
		self.itemsArrayController.add(sender)

		if self.itemsArrayController.selectedObjects.first != nil
		{
			self.nameField.selectText(nil)
		}
	}

	override func controlTextDidChange(_ obj: Notification)
	{
		if let control = obj.object as? NSTextField,
			control === self.addressField
		{
			// For the address field, validate every keypress
			if let item = self.itemsArrayController.selectedObjects.first as? DSFMountingYardItem
			{
				item.address = control.stringValue
			}
		}
	}

	private func updateNameIfDuplicateFound(_ item: DSFMountingYardItem, updatedName: String)
	{
		for otherItem in self.itemsArrayController.arrangedObjects as! [DSFMountingYardItem]
		{
			if otherItem !== item,
				otherItem.name == updatedName
			{
				var newName = updatedName
				newName.append(" ")
				newName.append(NSLocalizedString("Copy", comment: "The string that gets appended to the name if its a duplicate"))
				if let item = self.itemsArrayController.selectedObjects.first as? DSFMountingYardItem
				{
					item.name = newName
				}
				break
			}
		}
	}

	override func controlTextDidEndEditing(_ obj: Notification)
	{
		// If the name field completes, update it to make it unique

		// This appears to get called AFTER the array controller has updated the content.

		if let control = obj.object as? NSTextField,
			let item = self.itemsArrayController.selectedObjects.first as? DSFMountingYardItem,
			control === self.nameField
		{
			if item.name.count == 0
			{
				item.name = "empty"
			}
			self.updateNameIfDuplicateFound(item, updatedName: control.stringValue)
		}
	}

	@IBAction func testConnection(_: Any)
	{
		if let item = itemsArrayController.selectedObjects.first as? DSFMountingYardItem
		{
			_ = self.yardController().mount(item: item)
		}
	}

	@IBAction func actionButton(_ sender: NSButton)
	{
		NSMenu.popUpContextMenu(sender.menu!,
								with: NSApp.currentEvent!,
								for: sender)
	}

	@IBAction func share(_: Any)
	{
		_ = self.yardController().shareItems()
	}

	@IBAction func importData(_: Any)
	{
		_ = self.yardController().importItems()
	}
}
