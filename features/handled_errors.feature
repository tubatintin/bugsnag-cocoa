Feature: Handled Errors and Exceptions

  Background:
    Given I clear all UserDefaults data

  Scenario: Reporting handled errors concurrently
    When I run "ManyConcurrentNotifyScenario"
    And I wait to receive 20 requests
    And the received requests match:
        | exceptions.0.errorClass | exceptions.0.message |
        | FooError                | Err 0   |
        | FooError                | Err 1   |
        | FooError                | Err 2   |
        | FooError                | Err 3   |
    Then the request is valid for the error reporting API version "4.0" for the "iOS Bugsnag Notifier" notifier
    And I discard the oldest request
    Then the request is valid for the error reporting API version "4.0" for the "iOS Bugsnag Notifier" notifier
    And I discard the oldest request
    Then the request is valid for the error reporting API version "4.0" for the "iOS Bugsnag Notifier" notifier
    And I discard the oldest request
    Then the request is valid for the error reporting API version "4.0" for the "iOS Bugsnag Notifier" notifier
    And I discard the oldest request
    Then the request is valid for the error reporting API version "4.0" for the "iOS Bugsnag Notifier" notifier
    And I discard the oldest request
    Then the request is valid for the error reporting API version "4.0" for the "iOS Bugsnag Notifier" notifier
    And I discard the oldest request
    Then the request is valid for the error reporting API version "4.0" for the "iOS Bugsnag Notifier" notifier
    And I discard the oldest request
    Then the request is valid for the error reporting API version "4.0" for the "iOS Bugsnag Notifier" notifier
