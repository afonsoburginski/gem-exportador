package server.routes

import io.ktor.server.application.*
import io.ktor.server.response.*
import io.ktor.server.routing.*
import server.queue.ProcessingQueue

fun Route.apiQueue(queue: ProcessingQueue) {
    get("/api/queue") {
        call.respond(queue.getStatus())
    }
}
