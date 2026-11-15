import App
import Logging
import Vapor

@main
enum Entrypoint {
    static func main() async throws {
        var env = try Environment.detect()
        try LoggingSystem.bootstrap(from: &env)

        let app = try await Application.make(env)

        do {
            try await configure(app)
            try await app.execute()
        } catch {
            app.logger.report(error: error)
            // The original error is what matters here; a failure while shutting down must not hide it.
            try? await app.asyncShutdown()
            throw error
        }

        try await app.asyncShutdown()
    }
}
