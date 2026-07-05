import Foundation

final class ContentDirectoryService {
    private let server: UPnPMediaServer
    private let session: URLSession

    init(server: UPnPMediaServer, session: URLSession = .shared) {
        self.server = server
        self.session = session
    }

    func browse(objectID: String = "0", startingIndex: Int = 0, requestedCount: Int = 200) async throws -> BrowseResult {
        guard let controlURL = server.controlURL else {
            throw UPnPError.serviceNotFound
        }

        let envelope = """
        <?xml version="1.0" encoding="utf-8"?>
        <s:Envelope xmlns:s="http://schemas.xmlsoap.org/soap/envelope/" s:encodingStyle="http://schemas.xmlsoap.org/soap/encoding/">
          <s:Body>
            <u:Browse xmlns:u="urn:schemas-upnp-org:service:ContentDirectory:1">
              <ObjectID>\(escapeXML(objectID))</ObjectID>
              <BrowseFlag>BrowseDirectChildren</BrowseFlag>
              <Filter>*</Filter>
              <StartingIndex>\(startingIndex)</StartingIndex>
              <RequestedCount>\(requestedCount)</RequestedCount>
              <SortCriteria></SortCriteria>
            </u:Browse>
          </s:Body>
        </s:Envelope>
        """

        var request = URLRequest(url: controlURL)
        request.httpMethod = "POST"
        request.setValue("text/xml; charset=\"utf-8\"", forHTTPHeaderField: "Content-Type")
        request.setValue(
            "\"urn:schemas-upnp-org:service:ContentDirectory:1#Browse\"",
            forHTTPHeaderField: "SOAPAction"
        )
        request.httpBody = envelope.data(using: .utf8)

        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
            throw UPnPError.browseFailed("HTTP \((response as? HTTPURLResponse)?.statusCode ?? 0)")
        }

        return try parseBrowseResponse(data: data, parentID: objectID)
    }

    private func parseBrowseResponse(data: Data, parentID: String) throws -> BrowseResult {
        let parser = BrowseResponseXMLParser(data: data, parentID: parentID)
        return try parser.parse()
    }

    private func escapeXML(_ value: String) -> String {
        value
            .replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
            .replacingOccurrences(of: "\"", with: "&quot;")
    }
}

// MARK: - SOAP Response Parser

private final class BrowseResponseXMLParser: NSObject, XMLParserDelegate {
    private let data: Data
    private let parentID: String

    private var resultXML = ""
    private var totalMatches = 0
    private var captureElement: String?
    private var currentText = ""

    init(data: Data, parentID: String) {
        self.data = data
        self.parentID = parentID
    }

    func parse() throws -> BrowseResult {
        let parser = XMLParser(data: data)
        parser.delegate = self
        guard parser.parse() else {
            throw UPnPError.browseFailed("Impossibile analizzare la risposta SOAP")
        }

        guard let didlData = resultXML.data(using: .utf8) else {
            return BrowseResult(items: [], totalMatches: totalMatches)
        }

        let didlParser = DIDLLiteParser(data: didlData, parentID: parentID)
        let items = try didlParser.parse()
        return BrowseResult(items: items, totalMatches: max(totalMatches, items.count))
    }

    func parser(
        _ parser: XMLParser,
        didStartElement elementName: String,
        namespaceURI: String?,
        qualifiedName qName: String?,
        attributes attributeDict: [String: String] = [:]
    ) {
        currentText = ""
        if elementName == "Result" || elementName == "TotalMatches" {
            captureElement = elementName
        }
    }

    func parser(_ parser: XMLParser, foundCharacters string: String) {
        currentText += string
    }

    func parser(
        _ parser: XMLParser,
        didEndElement elementName: String,
        namespaceURI: String?,
        qualifiedName qName: String?
    ) {
        let value = currentText.trimmingCharacters(in: .whitespacesAndNewlines)
        if elementName == "Result", captureElement == "Result" {
            resultXML = decodeXMLEntities(value)
        } else if elementName == "TotalMatches", captureElement == "TotalMatches" {
            totalMatches = Int(value) ?? 0
        }
        if elementName == captureElement {
            captureElement = nil
        }
        currentText = ""
    }

    private func decodeXMLEntities(_ value: String) -> String {
        value
            .replacingOccurrences(of: "&lt;", with: "<")
            .replacingOccurrences(of: "&gt;", with: ">")
            .replacingOccurrences(of: "&quot;", with: "\"")
            .replacingOccurrences(of: "&apos;", with: "'")
            .replacingOccurrences(of: "&amp;", with: "&")
    }
}

// MARK: - DIDL-Lite Parser

private final class DIDLLiteParser: NSObject, XMLParserDelegate {
    private let data: Data
    private let parentID: String

    private var items: [MediaItem] = []
    private var currentItem: DIDLItemBuilder?
    private var currentElement = ""
    private var currentText = ""
    private var currentAttributes: [String: String] = [:]

    init(data: Data, parentID: String) {
        self.data = data
        self.parentID = parentID
    }

    func parse() throws -> [MediaItem] {
        let parser = XMLParser(data: data)
        parser.delegate = self
        guard parser.parse() else {
            throw UPnPError.browseFailed("Impossibile analizzare DIDL-Lite")
        }
        return items
    }

    func parser(
        _ parser: XMLParser,
        didStartElement elementName: String,
        namespaceURI: String?,
        qualifiedName qName: String?,
        attributes attributeDict: [String: String] = [:]
    ) {
        currentElement = elementName
        currentText = ""
        currentAttributes = attributeDict

        if elementName == "container" || elementName == "item" {
            currentItem = DIDLItemBuilder(
                id: attributeDict["id"] ?? UUID().uuidString,
                parentID: attributeDict["parentID"] ?? parentID,
                isContainer: elementName == "container"
            )
        } else if elementName == "res", var builder = currentItem {
            builder.pendingResourceURL = attributeDict["protocolInfo"]
            builder.pendingMimeType = extractMimeType(from: attributeDict["protocolInfo"])
            builder.pendingSize = Int64(attributeDict["size"] ?? "")
            builder.pendingDuration = parseDuration(attributeDict["duration"])
            currentItem = builder
        }
    }

    func parser(_ parser: XMLParser, foundCharacters string: String) {
        currentText += string
    }

    func parser(
        _ parser: XMLParser,
        didEndElement elementName: String,
        namespaceURI: String?,
        qualifiedName qName: String?
    ) {
        let value = currentText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard var builder = currentItem else { return }

        switch elementName {
        case "dc:title", "title":
            if !value.isEmpty { builder.title = value }
        case "upnp:class":
            builder.mediaClass = value
        case "res":
            if !value.isEmpty, let url = URL(string: value) {
                builder.streamURL = url
                if builder.mimeType == nil {
                    builder.mimeType = mimeTypeFromURL(url)
                }
            }
        case "container", "item":
            items.append(builder.build())
            currentItem = nil
            return
        default:
            break
        }

        currentItem = builder
        currentText = ""
    }

    private func extractMimeType(from protocolInfo: String?) -> String? {
        guard let protocolInfo else { return nil }
        let parts = protocolInfo.split(separator: ":")
        guard parts.count >= 3 else { return nil }
        let mime = String(parts[2])
        return mime == "*" ? nil : mime
    }

    private func mimeTypeFromURL(_ url: URL) -> String? {
        switch url.pathExtension.lowercased() {
        case "mp4", "m4v": return "video/mp4"
        case "mkv": return "video/x-matroska"
        case "avi": return "video/x-msvideo"
        case "mov": return "video/quicktime"
        case "webm": return "video/webm"
        case "ts": return "video/mp2t"
        case "m3u8": return "application/vnd.apple.mpegurl"
        default: return nil
        }
    }

    private func parseDuration(_ value: String?) -> TimeInterval? {
        guard let value, !value.isEmpty else { return nil }
        // HH:MM:SS or H:MM:SS.fraction
        let parts = value.split(separator: ":").map(String.init)
        guard parts.count == 3,
              let hours = Double(parts[0]),
              let minutes = Double(parts[1]),
              let seconds = Double(parts[2]) else { return nil }
        return hours * 3600 + minutes * 60 + seconds
    }
}

private struct DIDLItemBuilder {
    let id: String
    let parentID: String
    let isContainer: Bool
    var title: String = "Senza titolo"
    var mediaClass: String?
    var streamURL: URL?
    var mimeType: String?
    var duration: TimeInterval?
    var size: Int64?
    var thumbnailURL: URL?
    var pendingResourceURL: String?
    var pendingMimeType: String?
    var pendingSize: Int64?
    var pendingDuration: TimeInterval?

    func build() -> MediaItem {
        MediaItem(
            id: id,
            title: title,
            isContainer: isContainer,
            parentID: parentID,
            mediaClass: mediaClass,
            streamURL: streamURL,
            mimeType: mimeType ?? pendingMimeType,
            duration: duration ?? pendingDuration,
            size: size ?? pendingSize,
            thumbnailURL: thumbnailURL
        )
    }
}
