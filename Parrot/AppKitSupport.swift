import AppKit

/* TODO: Localization support for NSDateFormatter stuff. */

public extension NSView {
	
	// Snapshots the view as it exists and return an NSImage of it.
	func snapshot() -> NSImage {
		
		// First get the bitmap representation of the view.
		let rep = self.bitmapImageRepForCachingDisplay(in: self.bounds)!
		self.cacheDisplay(in: self.bounds, to: rep)
		
		// Stuff the representation into an NSImage.
		let snapshot = NSImage(size: rep.size)
		snapshot.addRepresentation(rep)
		return snapshot
	}
	
	// Automatically translate a view into a NSDraggingImageComponent
	func draggingComponent(_ key: String) -> NSDraggingImageComponent {
		let component = NSDraggingImageComponent(key: key)
		component.contents = self.snapshot()
		component.frame = self.convert(self.bounds, from: self)
		return component
	}
}

/*
public extension NSPopover {
	public dynamic var anchorEdge: NSRectEdge
}
*/

public extension NSNib {
	public func instantiate(_ owner: AnyObject?) -> [AnyObject] {
		var stuff: NSArray = []
		if self.instantiate(withOwner: nil, topLevelObjects: &stuff) {
			return stuff as [AnyObject]
		}
		return []
	}
}

extension NSWindowController: NSWindowDelegate {
	public func showWindow() {
		DispatchQueue.main.async {
			self.showWindow(nil)
		}
	}
}

/// from @jack205: https://gist.github.com/jacks205/4a77fb1703632eb9ae79
public extension Date {
	public func relativeString(numeric: Bool = false, seconds: Bool = false) -> String {
		
		let date = self, now = Date()
		let calendar = Calendar.current()
		let earliest = (now as NSDate).earlierDate(date) as Date
		let latest = (earliest == now) ? date : now
		let units: Calendar.Unit = [.second, .minute, .hour, .day, .weekOfYear, .month, .year]
		let components = calendar.components(units, from: earliest, to: latest, options: Calendar.Options())
		
		if components.year > 45 {
			return "a while ago"
		} else if (components.year >= 2) {
			return "\(components.year!) years ago"
		} else if (components.year >= 1) {
			return numeric ? "1 year ago" : "last year"
		} else if (components.month >= 2) {
			return "\(components.month!) months ago"
		} else if (components.month >= 1) {
			return numeric ? "1 month ago" : "last month"
		} else if (components.weekOfYear >= 2) {
			return "\(components.weekOfYear!) weeks ago"
		} else if (components.weekOfYear >= 1) {
			return numeric ? "1 week ago" : "last week"
		} else if (components.day >= 2) {
			return "\(components.day!) days ago"
		} else if (components.day >= 1) {
			return numeric ? "1 day ago" : "a day ago"
		} else if (components.hour >= 2) {
			return "\(components.hour!) hours ago"
		} else if (components.hour >= 1){
			return numeric ? "1 hour ago" : "an hour ago"
		} else if (components.minute >= 2) {
			return "\(components.minute!) minutes ago"
		} else if (components.minute >= 1) {
			return numeric ? "1 minute ago" : "a minute ago"
		} else if (components.second >= 3 && seconds) {
			return "\(components.second!) seconds ago"
		} else {
			return "just now"
		}
	}
	
	private static var formatter: DateFormatter = {
		let formatter = DateFormatter()
		formatter.dateStyle = .fullStyle
		formatter.timeStyle = .longStyle
		return formatter
	}()
	
	public func fullString() -> String {
		return Date.formatter.string(from: self)
	}
	
	public func nearestMinute() -> Date {
		let c = Calendar.current()
		let next = c.component(.minute, from: self) + 1
		return c.nextDate(after: self, matching: .minute, value: next, options: .matchStrictly) ?? self
	}
}

public extension NSWindowOcclusionState {
	public static let invisible = NSWindowOcclusionState(rawValue: 0)
}

public extension NSView {
	
	/* TODO: Finish this stuff here. */
	public var occlusionState: NSWindowOcclusionState {
		let selfRect = self.window!.frame
		let windows = CGWindowListCopyWindowInfo(.optionOnScreenAboveWindow, CGWindowID(self.window!.windowNumber))!
		for dict in (windows as [AnyObject]) {
			guard let window = dict as? NSDictionary else { return .visible }
			guard let detail = window[kCGWindowBounds as String] as? NSDictionary else { return .visible }
			let rect = NSRect(x: detail["X"] as? Int ?? 0, y: detail["Y"] as? Int ?? 0,
			                  width: detail["Width"] as? Int ?? 0, height: detail["Height"] as? Int ?? 0)
			//guard rect.contains(selfRect) else { continue }
			let intersected = self.window!.convertFromScreen(rect.intersection(selfRect))
			log.info("intersect => \(intersected)")
			
			//log.info("alpha: \(window[kCGWindowAlpha as String])")
		}
		return .visible
	}
}

public extension Date {
	public static let origin = Date(timeIntervalSince1970: 0)
}

public extension NSFont {
	
	/// Load an NSFont from a provided URL.
	public static func from(_ fontURL: URL, size: CGFloat) -> NSFont? {
		let desc = CTFontManagerCreateFontDescriptorsFromURL(fontURL)
		guard let item = (desc as? NSArray)?[0] else { return nil }
		return CTFontCreateWithFontDescriptor(item as! CTFontDescriptor, size, nil)
	}
}

/// A "typealias" for the traditional NSApplication delegation.
public class NSApplicationController: NSObject, NSApplicationDelegate {}

/// Can hold any (including non-object) type as an object type.
public class Wrapper<T> {
	public let element: T
	public init(_ value: T) {
		self.element = value
	}
}
