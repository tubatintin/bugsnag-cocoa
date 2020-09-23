//
//  ViewController.swift
//  iOSTestApp
//
//  Created by Delisa on 2/23/18.
//  Copyright © 2018 Bugsnag. All rights reserved.
//

import UIKit
import os

class ViewController: UIViewController {

    @IBOutlet var scenarioNameField : UITextField!
    @IBOutlet var scenarioMetaDataField : UITextField!
    @IBOutlet var apiKeyField: UITextField!
    
    var scenario : Scenario?

    override func viewDidLoad() {
        super.viewDidLoad()
        self.view.addGestureRecognizer(UITapGestureRecognizer(target: self.view, action: #selector(UIView.endEditing(_:))))
        NotificationCenter.default.addObserver(self, selector: #selector(didEnterBackgroundNotification), name: UIApplication.didEnterBackgroundNotification, object: nil)
        apiKeyField.text = UserDefaults.standard.string(forKey: "apiKey")
    }

    @IBAction func startBugsnag() {

        scenario = prepareScenario()
        NSLog("Starting Bugsnag for scenario: %@", String(describing: scenario))
        scenario?.startBugsnag()
    }

    @IBAction func runOnce() {
        NSLog("Run once")
        NSLog("Running scenario: %@", String(describing: scenario))
        scenario?.run()
    }
    
    @IBAction func run100Times(_ sender: Any) {
        NSLog("Run 100 times")
    }
    
    internal func prepareScenario() -> Scenario {
        let eventType : String! = scenarioNameField.text
        let eventMode : String! = scenarioMetaDataField.text

        let config: BugsnagConfiguration
        config = BugsnagConfiguration("12312312312312312312312312312312")
        config.endpoints = BugsnagEndpointConfiguration(notify: "http://192.168.1.5:9339", sessions: "http://192.168.1.5:9339")
        config.autoTrackSessions = false;
        
        let allowedErrorTypes = BugsnagErrorTypes()
        allowedErrorTypes.ooms = false
        config.enabledErrorTypes = allowedErrorTypes
        
        let scenario = Scenario.createScenarioNamed(eventType, withConfig: config)
        scenario.eventMode = eventMode
        return scenario
    }
    
    
    @objc func didEnterBackgroundNotification() {
        scenario?.didEnterBackgroundNotification()
    }
}

