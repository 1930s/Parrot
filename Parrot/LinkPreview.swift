import Foundation

/* TODO: Use NSLinguisticTagger to identify nouns and search them and provide data. */

public enum LinkPreviewError: ErrorProtocol {
	case invalidUrl(String)
	case unsafeUrl(URL)
	case invalidHeaders(URL, Int)
	case documentTooLarge(URL, Double)
	case unhandleableUrl(URL, String)
	case invalidDocument(URL)
}

public struct LinkMeta {
	/// og:title, twitter:title, <title />
	let title: [String]
	/// `favicon.ico`
	let icon: [String]
	/// og:image, twitter:image
	let image: [String]
	/// og:description, twitter:description, <meta name="description" ... />
	let description: [String]
	/// og:type, twitter:card
	let type: [String]
	/// og:site (!), twitter:creator
	let source: [String]
	/// og:audio
	let audio: [String]
	/// og:video, twitter:player
	let video: [String]
}

public enum LinkPreviewType {
	/// MIME: audio/*
	case audio
	/// MIME: video/*
	case video
	/// MIME: image/*
	case image(Data)
	/// MIME: text/plain
	case snippet(String)
	/// URL: youtu.be or youtube.com
	case youtube(String)
	/// MIME: text/html
	case link(LinkMeta)
}

public struct LinkPreviewParser {
	private static let SBKEY = "AIzaSyCE0A8INTc8KQLIaotaHiWvqUkit5-_sTE"
	private static let SBURL = "https://sb-ssl.google.com/safebrowsing/api/lookup?client=parrot&key=\(SBKEY)&appver=1.0.0&pver=3.1&url="
	
	private static let TITLE_REGEX = "(?<=<title>)(?:[\\s\\S]*?)(?=<\\/title>)"
	private static let META_REGEX = "(?:\\<meta)([\\s\\S]*?)(?:>)"
	private static let LINK_REGEX = "(?:\\<link)([\\s\\S]*?)(?:>)"
	
	private static let _validIcons = ["icon", "apple-touch-icon", "apple-touch-icon-precomposed"]
	private static let _YTDomains = ["youtu.be", "www.youtube.com", "youtube.com"]
	
	private init() { }
	
	private static func _tag(_ str: String) -> String {
		return "(?<=\(str)=\\\")[\\s\\S]+?(?=\\\")"
	}
	
	private static func _get(_ url: URL, method: String = "GET") -> (Data?, URLResponse?, NSError?) {
		var data: Data?, response: URLResponse?, error: NSError?
		let semaphore = DispatchSemaphore(value: 0)
		
		let request = NSMutableURLRequest(url: url)
		request.httpMethod = method
		URLSession.shared().dataTask(with: request) {
			data = $0; response = $1; error = $2
			dispatch_semaphore_signal(semaphore!)
			}.resume()
		
		semaphore.wait(timeout: DispatchTime.distantFuture)
		return (data, response, error)
	}
	
	private static func _extractTitle(from str: String) -> String {
		let o = str.findAllOccurrences(matching: TITLE_REGEX, all: true)
		let q = CFXMLCreateStringByUnescapingEntities(nil, (o.first ?? ""), nil) as String
		return q.trimmingCharacters(in: .whitespacesAndNewlines())
	}
	
	private static func _extractMetadata(from str: String) -> [String: String] {
		var tags: [String: String] = [:]
		for s in str.findAllOccurrences(matching: META_REGEX, all: true) {
			var keys =	s.findAllOccurrences(matching: _tag("name"), all: true) +
				s.findAllOccurrences(matching: _tag("property"), all: true)
			var vals =	s.findAllOccurrences(matching: _tag("content"), all: true)
			keys = keys.flatMap { $0.components(separatedBy: " ") }
			vals = vals.map { $0.trimmingCharacters(in: .whitespacesAndNewlines()) }
			vals = vals.map { CFXMLCreateStringByUnescapingEntities(nil, $0, nil) as String }
			keys.forEach { tags[$0] = (vals.first ?? "") }
		}
		return tags
	}
	
	private static func _extractIcon(from str: String) -> [String] {
		var icons: [String] = []
		for s in str.findAllOccurrences(matching: LINK_REGEX, all: true) {
			var keys = s.findAllOccurrences(matching: _tag("rel"), all: true)
			let vals = s.findAllOccurrences(matching: _tag("href"), all: true)
			keys = keys.flatMap { $0.components(separatedBy: " ") }
			//vals = vals.map { $0.trimmingCharacters(in: .whitespacesAndNewlines()) }
			//vals = vals.map { CFXMLCreateStringByUnescapingEntities(nil, $0, nil) as String }
			if keys.contains("icon") || keys.contains("apple-touch-icon") || keys.contains("apple-touch-icon-precomposed") {
				icons.append(vals.first! ?? "")
			}
		}
		return icons
	}
	
	private static func _verifyLink(_ url: URL) -> (safe: Bool, error: Bool) {
		let url2 = URL(string: SBURL + url.absoluteString!)!
		let out = _get(url 2, method: "HEAD")
		let resp = (out.1 as? HTTPURLResponse)?.statusCode ?? 0
		return (safe: (resp == 204), error: !(resp == 200 || resp == 204))
	}
	
	private static func _parseMeta(from str: String) -> LinkPreviewType {
		let m = _extractMetadata(from: str)
		
		var title: [String] = []
		if let x = m["og:title"] { title.append(x) }
		if let x = m["twitter:title"] { title.append(x) }
		title.append(_extractTitle(from: str))
		var icon: [String] = []
		icon.append(contentsOf: _extractIcon(from: str))
		var image: [String] = []
		if let x = m["og:image"] { image.append(x) }
		if let x = m["twitter:image"] { image.append(x) }
		var description: [String] = []
		if let x = m["og:description"] { description.append(x) }
		if let x = m["twitter:description"] { description.append(x) }
		if let x = m["description"] { description.append(x) }
		var type: [String] = []
		if let x = m["og:type"] { type.append(x) }
		if let x = m["twitter:card"] { type.append(x) }
		var source: [String] = []
		if let x = m["og:site"] { source.append(x) }
		if let x = m["twitter:creator"] { source.append(x) }
		var audio: [String] = []
		if let x = m["og:audio"] { audio.append(x) }
		var video: [String] = []
		if let x = m["og:video"] { video.append(x) }
		if let x = m["twitter:player"] { video.append(x) }
		
		return .link(LinkMeta(title: title, icon: icon, image: image, description: description,
		                      type: type, source: source, audio: audio, video: video))
	}
	
	public static func parse(_ link: String) throws -> LinkPreviewType {
		
		let start = mach_absolute_time()
		
		// Step 1: Verify valid URL
		guard let url = URL(string: link) else {
			throw LinkPreviewError.invalidUrl(link)
		}
		
		// Step 2: Verify safe URL
		let browse = _verifyLink(url)
		guard browse.safe && !browse.error else {
			throw LinkPreviewError.unsafeUrl(url)
		}
		
		// Step 3: Verify URL headers
		let _headers = _get(url, method: "HEAD")
		guard let headers = _headers.1 as? HTTPURLResponse else {
			throw LinkPreviewError.invalidHeaders(url, 0)
		}
		guard headers.statusCode == 200 else {
			throw LinkPreviewError.invalidHeaders(url, headers.statusCode)
		}
		
		let final = mach_absolute_time() - start
		Swift.print("took \(final / 1000000)ms to parse url.")
		
		// Step 4: Verify URL content type
		let type = headers.mimeType ?? ""
		if _YTDomains.contains(url.host ?? "") {
			var id = ""
			if let loc = url.absoluteString?.range(of: "youtu.be/") {
				id = (url.absoluteString?.substring(from: loc.upperBound))!
			} else if let loc = url.absoluteString?.range(of: "youtube.com/watch?v=") {
				id = (url.absoluteString?.substring(from: loc.upperBound))!
			} else { throw LinkPreviewError.unhandleableUrl(url, id) }
			
			// domain-specialized case (not MIME type)
			return .youtube(id)
		} else if type.hasPrefix("image/") {
			let size = Double(headers.expectedContentLength) / (1024.0 * 1024.0)
			guard size < 4 else {
				throw LinkPreviewError.documentTooLarge(url, size)
			}
			guard let dl = _get(url).0 else {
				throw LinkPreviewError.invalidDocument(url)
			}
			
			return .image(dl)
		} else if type.hasPrefix("audio/") {
			return .audio
		} else if type.hasPrefix("video/") {
			return .video
		} else if type.hasPrefix("text/html") {
			guard	let dl = _get(url).0,
				let content = NSString(data: dl, encoding: String.Encoding.utf8.rawValue) else {
					throw LinkPreviewError.invalidDocument(url)
			}
			
			// higher priority than text/*
			return _parseMeta(from: content as String)
		} else if type.hasPrefix("text/") {
			guard	let _sz = headers.allHeaderFields["Content-Length"] as? String,
				let _dz = Double(_sz) else {
					throw LinkPreviewError.documentTooLarge(url, -1)
			}
			let size = _dz / (1024.0 * 1024.0)
			guard size < 4 else {
				throw LinkPreviewError.documentTooLarge(url, size)
			}
			guard	let dl = _get(url).0,
				let content = NSString(data: dl, encoding: String.Encoding.utf8.rawValue) else {
					throw LinkPreviewError.invalidDocument(url)
			}
			
			// only use the first 1024 characters.
			return .snippet(content.substring(to: 512))
		}
		
		// If we've reached here, none of our code paths can handle the URL.
		throw LinkPreviewError.unhandleableUrl(url, type)
	}
}
