//
//  BucketListParser.swift
//  Data Collector
//
//  Created by Nicholas Bourdakos on 10/28/18.
//

import Foundation

public class BucketListParser: NSObject {
    var currentParsingElement = String()
    var names = [String]()
    var pendingName = String()
    let parser: XMLParser
    
    public init(data: Data) {
        parser = XMLParser(data: data)
    }
    
    public func parse(completion: @escaping ([String]) -> Void) {
        parser.delegate = self
        parser.parse()
        completion(names)
    }
    

}

// MARK: - XMLParserDelegate

extension BucketListParser: XMLParserDelegate {
    open func parser(_ parser: XMLParser, didStartElement elementName: String, namespaceURI: String?, qualifiedName qName: String?, attributes attributeDict: [String : String] = [:]) {
        currentParsingElement = elementName
    }

    open func parser(_ parser: XMLParser, foundCharacters string: String) {
        let foundChar = string.trimmingCharacters(in: NSCharacterSet.whitespacesAndNewlines)

        if (!foundChar.isEmpty) {
            if currentParsingElement == "Name" {
                pendingName += foundChar
            }
        }
    }

    open func parser(_ parser: XMLParser, didEndElement elementName: String, namespaceURI: String?, qualifiedName qName: String?) {
        if elementName == "Name" {
            names.append(pendingName)
            pendingName = ""
        }
    }

    open func parser(_ parser: XMLParser, parseErrorOccurred parseError: Error) {
        print("parseErrorOccurred: \(parseError)")
    }
}
