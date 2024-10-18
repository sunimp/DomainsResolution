//
//  LinuxMain.swift
//  Tests
//
//  Created by Sun on 2024/8/21.
//

import XCTest

import ResolutionTests

var tests = [XCTestCaseEntry]()
tests += ResolutionTests.allTests()
tests += EthereumABITests.allTests()
tests += TokenUriMetadataTests.allTests()
tests += ABICoderTests.allTests()
tests += UnsLayerL2Tests.allTests()
XCTMain(tests)
