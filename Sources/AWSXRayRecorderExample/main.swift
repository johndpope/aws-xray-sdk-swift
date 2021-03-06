import AWSXRayRecorder
import NIO

func env(_ name: String) -> String? {
    guard let value = getenv(name) else { return nil }
    return String(cString: value)
}

let xrayEndpoint = env("XRAY_ENDPOINT") ?? "http://127.0.0.1:2000"

assert(env("AWS_ACCESS_KEY_ID") != nil, "AWS_ACCESS_KEY_ID not set")
assert(env("AWS_SECRET_ACCESS_KEY") != nil, "AWS_SECRET_ACCESS_KEY not set")

enum ExampleError: Error {
    case test
}

let group = MultiThreadedEventLoopGroup(numberOfThreads: 1)
let emmiter = XRayEmmiter(eventLoop: group.next(), endpoint: xrayEndpoint)

let recorder = XRayRecorder()

// begin and end (sub)segments explicitly
let segment = recorder.beginSegment(name: "Segment 1")
segment.setAnnotation("zip_code", value: 98101)
segment.setMetadata(["debug": ["test": "Metadata string"]])
usleep(100_000)
segment.end()

// use closures for convenience
recorder.segment(name: "Segment 2") { segment in
    try? segment.subsegment(name: "Subsegment 2.1") { segment in
        _ = segment.subsegment(name: "Subsegment 2.1.1 with Result") { _ -> String in
            usleep(100_000)
            return "Result"
        }
        try segment.subsegment(name: "Subsegment 2.1.1 with Error") { _ in
            usleep(200_000)
            throw ExampleError.test
        }
    }
}

try emmiter.send(segments: recorder.removeReady()).wait()

try group.syncShutdownGracefully()
exit(0)
