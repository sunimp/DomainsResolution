//
//  DnsRecordsError.swift
//  DomainsResolution
//
//  Created by Sun on 2020/12/19.
//

import Foundation

public enum DnsRecordsError: Error {
    case dnsRecordCorrupted(recordType: DnsType)
    case inconsistentTtl(recordType: DnsType)
}
