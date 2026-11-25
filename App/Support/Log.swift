import os

enum Log {
    static let app = Logger(subsystem: "com.euraphhh.cove", category: "app")
    static let media = Logger(subsystem: "com.euraphhh.cove", category: "media")
}
