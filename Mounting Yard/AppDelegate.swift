//
//  AppDelegate.swift
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

@NSApplicationMain
class AppDelegate: NSObject, NSApplicationDelegate
{
	@IBOutlet var window: NSWindow!

	lazy var mountingYard: DSFMountingYardController =
	{
		let yard = DSFMountingYardController()
		yard.load()
		return yard
	}()

	lazy var statusManager: DSFMountingYardStatusMenu =
	{
		let manager = DSFMountingYardStatusMenu()
		manager.configure(controller: self.mountingYard)
		return manager
	}()

	lazy var settingsWindow: DSFMountingYardSettingsWindowController =
	{
		let wc = DSFMountingYardSettingsWindowController(windowNibName: NSNib.Name(rawValue: "DSFMountingYardSettingsWindowController"))
		wc.mountingYard = mountingYard
		return wc
	}()

	private func initialize()
	{
		// Kinda dumb, simple tho!
		_ = self.statusManager
	}

	func application(_: NSApplication, openFile filename: String) -> Bool
	{
		self.initialize()
		return self.mountingYard.openFile(filename: filename)
	}

	func applicationDidFinishLaunching(_: Notification)
	{
		self.initialize()

		// If there's no entries, display the settings window by default
		if self.mountingYard.items.count == 0
		{
			self.showSettings()
		}
	}

	func applicationWillTerminate(_: Notification)
	{
		// Sync any changes
		_ = self.mountingYard.save()
	}

	func showSettings()
	{
		NSApp.activate(ignoringOtherApps: true)
		self.settingsWindow.window?.makeKeyAndOrderFront(self)
	}
}
