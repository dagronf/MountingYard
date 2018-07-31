//
//  DSFMountingYardStatusMenu.swift
//  Mounting Point
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

class DSFMountingYardStatusMenu: NSObject, NSMenuDelegate
{
	let statusBar = NSStatusBar.system.statusItem(withLength: 30)
	let statusMenu = NSMenu()

	var controller: DSFMountingYardController?

	private lazy var settingsMenu: NSMenuItem =
		{
		let settingsMenu = NSMenuItem(
			title: NSLocalizedString("Settings…", comment: "Settings menu entry"),
			action: #selector(self.showSettings(_:)),
			keyEquivalent: ""
		)
		settingsMenu.target = self
		settingsMenu.isEnabled = true
		return settingsMenu
	}()

	private lazy var aboutMenu: NSMenuItem =
		{
		let aboutMenu = NSMenuItem(
			title: NSLocalizedString("About Mounting Yard…", comment: "About menu entry"),
			action: #selector(self.showAbout(_:)),
			keyEquivalent: ""
		)
		aboutMenu.target = self
		aboutMenu.isEnabled = true
		return aboutMenu
	}()

	private lazy var quitMenu: NSMenuItem =
		{
		let quitMenu = NSMenuItem(
			title: NSLocalizedString("Quit", comment: "Quit menu entry"),
			action: #selector(NSApplication.terminate(_:)),
			keyEquivalent: ""
		)
		quitMenu.target = NSApplication.shared
		quitMenu.isEnabled = true
		return quitMenu
	}()

	func configure(controller: DSFMountingYardController)
	{
		self.controller = controller

		let menuIcon = NSImage(named: NSImage.Name(rawValue: "MenuIcon"))
		menuIcon!.isTemplate = true
		statusBar.image = menuIcon
		statusBar.menu = statusMenu
		statusMenu.delegate = self
	}

	func menuWillOpen(_ menu: NSMenu)
	{
		menu.removeAllItems()
		self.configureMenu()
	}

	private func resize(image: NSImage, w: Int, h: Int) -> NSImage
	{
		let destSize = NSMakeSize(CGFloat(w), CGFloat(h))
		let newImage = NSImage(size: destSize)
		newImage.lockFocus()
		image.draw(
			in: NSMakeRect(0, 0, destSize.width, destSize.height),
			from: NSMakeRect(0, 0, image.size.width, image.size.height),
			operation: .sourceOver,
			fraction: CGFloat(1)
		)
		newImage.unlockFocus()
		newImage.size = destSize
		return NSImage(data: newImage.tiffRepresentation!)!
	}

	private func configureMenu()
	{
		// Sort the items in the correct order
		var items = controller!.items
		items.sort { $0.name.lowercased() < $1.name.lowercased() }

		for item in items
		{
			let itemMenu = NSMenuItem(
				title: item.name,
				action: #selector(self.openItem(_:)),
				keyEquivalent: ""
			)
			itemMenu.representedObject = item
			itemMenu.target = self
			itemMenu.isEnabled = true
			itemMenu.image = item.icon

			self.statusMenu.addItem(itemMenu)
		}

		self.statusMenu.addItem(NSMenuItem.separator())
		self.statusMenu.addItem(self.settingsMenu)
		self.statusMenu.addItem(self.aboutMenu)
		self.statusMenu.addItem(NSMenuItem.separator())
		self.statusMenu.addItem(self.quitMenu)
	}

	@objc func openItem(_ sender: NSMenuItem)
	{
		self.controller!.mount(item: sender.representedObject as! DSFMountingYardItem)
	}

	@objc func showAbout(_: NSMenuItem)
	{
		NSApp.orderFrontStandardAboutPanel(self)
	}

	@objc func showSettings(_: NSMenuItem)
	{
		if let delegate = NSApp.delegate as? AppDelegate
		{
			delegate.showSettings()
		}
	}
}
