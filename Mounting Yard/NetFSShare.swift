//
//  NetFSShare.swift
//  Mounting Yard
//
//  Created by Darren Ford on 31/7/18.
//  Copyright © 2018 Darren Ford. All rights reserved.
//
//  https://gist.github.com/mosen/2ddf85824fbb5564aef527b60beb4669
//

import Foundation
import NetFS

enum ShareMountError: Error {
	case InvalidURL
	case MountpointInaccessible
	case InvalidMountOptions
}

enum MountOption {
	case NoBrowse
	case ReadOnly
	case AllowSubMounts
	case SoftMount
	case MountAtMountDirectory

	case Guest
	case AllowLoopback
	case NoAuthDialog
	case AllowAuthDialog
	case ForceAuthDialog
}

typealias NetFSMountCallback = (Int32, UnsafeMutableRawPointer?, CFArray?) -> Void
typealias MountCallbackHandler = (Int32, URL?, [String]?) -> Void;

protocol ShareDelegate {
	func shareWillMount(url: URL) -> Void
	func shareDidMount(url: URL, at paths: [String]?) -> Void
	func shareMountingDidFail(for url: URL, withError: Int32) -> Void
}

fileprivate func processOptionsForNetFS(options: [MountOption]) throws -> (NSMutableDictionary, NSMutableDictionary) {
	let openOptions: NSMutableDictionary = NSMutableDictionary()
	let mountOptions: NSMutableDictionary = NSMutableDictionary()

	for opt in options {
		switch opt {

		// mount_options
		case .NoBrowse:
			if let existingValue = mountOptions.value(forKey: kNetFSMountFlagsKey) {
				mountOptions[kNetFSMountFlagsKey] = existingValue as! Int32 | MNT_DONTBROWSE
			} else {
				mountOptions[kNetFSMountFlagsKey] = MNT_DONTBROWSE
			}
		case .ReadOnly:
			if let existingValue = mountOptions.value(forKey: kNetFSMountFlagsKey) {
				mountOptions[kNetFSMountFlagsKey] = existingValue as! Int32 | MNT_RDONLY
			} else {
				mountOptions[kNetFSMountFlagsKey] = MNT_RDONLY
			}
		case .AllowSubMounts:
			mountOptions[kNetFSAllowSubMountsKey] = true
		case .SoftMount:
			mountOptions[kNetFSSoftMountKey] = true
		case .MountAtMountDirectory:
			mountOptions[kNetFSMountAtMountDirKey] = true

		// open_options
		case .Guest:
			openOptions[kNetFSUseGuestKey] = true
		case .AllowLoopback:
			openOptions[kNetFSAllowLoopbackKey] = true
		case .NoAuthDialog:
			openOptions[kNAUIOptionKey] = kNAUIOptionNoUI
		case .AllowAuthDialog:
			openOptions[kNAUIOptionKey] = kNAUIOptionAllowUI
		case .ForceAuthDialog:
			openOptions[kNAUIOptionKey] = kNAUIOptionForceUI
		}
	}

	return (openOptions, mountOptions)
}


class Share {
	let url: URL
	var mountPoint: String = "/Volumes"
	var username: String?
	var password: String?
	fileprivate var asyncRequestId: AsyncRequestID?
	public var delegate: ShareDelegate?

	init(_ url: URL) {
		self.url = url
	}

	init(_ urlString: String) throws {
		guard let url = URL(string: urlString) else {
			throw ShareMountError.InvalidURL
		}

		self.url = url
	}

	public func cancelMounting() {
		NetFSMountURLCancel(self.asyncRequestId)
	}

	static func cancelMounting(id requestId: AsyncRequestID) {
		NetFSMountURLCancel(requestId)
	}

	public func mount() throws {
		let mountDirectoryURL = URL(fileURLWithPath: self.mountPoint)
		let operationQueue = OperationQueue.main

		let mountReportBlock: NetFSMountCallback = {
			status, asyncRequestId, mountedDirs in

			let mountedDirectories = mountedDirs as! [String]? ?? nil

			if (status != 0) {
				self.delegate?.shareMountingDidFail(for: self.url, withError: status)
			} else {
				self.delegate?.shareDidMount(url: self.url, at: mountedDirectories)
			}
		}

		NetFSMountURLAsync(url as CFURL,
						   mountDirectoryURL as CFURL,
						   username as CFString?,
						   password as CFString?,
						   nil,
						   nil,
						   &self.asyncRequestId,
						   operationQueue.underlyingQueue,
						   mountReportBlock)
		self.delegate?.shareWillMount(url: url)
	}

	public func mount(options: [MountOption]?, callbackHandler: @escaping MountCallbackHandler) throws -> AsyncRequestID? {
		let mountDirectoryURL = URL(fileURLWithPath: self.mountPoint)
		let operationQueue = OperationQueue.main

		let mountReportBlock: NetFSMountCallback = {
			(status, asyncRequestId, mountedDirs) in
			callbackHandler(status, self.url, mountedDirs as? [String])
		}

		var openOptions: NSMutableDictionary
		var mountOptions: NSMutableDictionary

		if options != nil {
			(openOptions, mountOptions) = try processOptionsForNetFS(options: options!)
		} else {
			openOptions = NSMutableDictionary()
			mountOptions = NSMutableDictionary()
		}

		NetFSMountURLAsync(url as CFURL,
						   mountDirectoryURL as CFURL,
						   username as CFString?,
						   password as CFString?,
						   openOptions as CFMutableDictionary,
						   mountOptions as CFMutableDictionary,
						   &self.asyncRequestId,
						   operationQueue.underlyingQueue,
						   mountReportBlock)
		self.delegate?.shareWillMount(url: url)
		return self.asyncRequestId
	}
}
