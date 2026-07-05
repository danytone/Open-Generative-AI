import Foundation

enum UPnPDeviceParser {
    static func parseDeviceDescription(data: Data, locationURL: URL) throws -> UPnPMediaServer? {
        let parser = DeviceDescriptionXMLParser(data: data, locationURL: locationURL)
        return try parser.parse()
    }

    static func resolveURL(_ path: String, base: URL) -> URL? {
        if path.hasPrefix("http://") || path.hasPrefix("https://") {
            return URL(string: path)
        }
        if path.hasPrefix("/") {
            var components = URLComponents()
            components.scheme = base.scheme
            components.host = base.host
            components.port = base.port
            components.path = path
            return components.url
        }
        return URL(string: path, relativeTo: base)?.absoluteURL
    }
}

private final class DeviceDescriptionXMLParser: NSObject, XMLParserDelegate {
    private let data: Data
    private let locationURL: URL

    private var friendlyName: String?
    private var manufacturer: String?
    private var modelName: String?
    private var udn: String?

    private var inService = false
    private var currentServiceType: String?
    private var currentControlURL: String?
    private var currentEventSubURL: String?
    private var currentSCPDURL: String?

    private var contentDirectoryControlURL: URL?
    private var contentDirectoryEventSubURL: URL?
    private var contentDirectorySCPDURL: URL?

    private var currentElement = ""
    private var currentText = ""

    init(data: Data, locationURL: URL) {
        self.data = data
        self.locationURL = locationURL
    }

    func parse() throws -> UPnPMediaServer? {
        let parser = XMLParser(data: data)
        parser.delegate = self
        guard parser.parse() else {
            throw UPnPError.invalidResponse
        }

        guard let friendlyName, let udn else { return nil }
        guard contentDirectoryControlURL != nil else { return nil }

        return UPnPMediaServer(
            id: udn,
            friendlyName: friendlyName,
            manufacturer: manufacturer,
            modelName: modelName,
            locationURL: locationURL,
            controlURL: contentDirectoryControlURL,
            eventSubURL: contentDirectoryEventSubURL,
            scpdURL: contentDirectorySCPDURL
        )
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

        if elementName == "service" {
            inService = true
            currentServiceType = nil
            currentControlURL = nil
            currentEventSubURL = nil
            currentSCPDURL = nil
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
        guard !value.isEmpty else {
            if elementName == "service" { finalizeService() }
            return
        }

        switch elementName {
        case "friendlyName":
            friendlyName = value
        case "manufacturer":
            manufacturer = value
        case "modelName":
            modelName = value
        case "UDN":
            udn = value
        case "serviceType" where inService:
            currentServiceType = value
        case "controlURL" where inService:
            currentControlURL = value
        case "eventSubURL" where inService:
            currentEventSubURL = value
        case "SCPDURL" where inService:
            currentSCPDURL = value
        case "service":
            finalizeService()
        default:
            break
        }

        currentText = ""
    }

    private func finalizeService() {
        defer {
            inService = false
            currentServiceType = nil
            currentControlURL = nil
            currentEventSubURL = nil
            currentSCPDURL = nil
        }

        guard currentServiceType == "urn:schemas-upnp-org:service:ContentDirectory:1" else { return }
        if let control = currentControlURL {
            contentDirectoryControlURL = UPnPDeviceParser.resolveURL(control, base: locationURL)
        }
        if let event = currentEventSubURL {
            contentDirectoryEventSubURL = UPnPDeviceParser.resolveURL(event, base: locationURL)
        }
        if let scpd = currentSCPDURL {
            contentDirectorySCPDURL = UPnPDeviceParser.resolveURL(scpd, base: locationURL)
        }
    }
}
